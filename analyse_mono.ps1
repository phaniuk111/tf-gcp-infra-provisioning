# ─────────────────────────────────────────────────────────────────────
# scan-http-clients.ps1
# Scans a Java/Spring Boot monorepo to find which HTTP client patterns
# are used across all services/modules.
#
# Usage (PowerShell):
#   .\scan-http-clients.ps1 -RepoRoot "C:\path\to\your\monorepo"
#
# Or just run from inside the monorepo folder:
#   .\scan-http-clients.ps1
# ─────────────────────────────────────────────────────────────────────

param(
    [string]$RepoRoot = "."
)

$RepoRoot = Resolve-Path $RepoRoot -ErrorAction Stop

# ── Exclude folders ───────────────────────────────────────────────────
$ExcludeDirs = @("build", "target", ".gradle", "bin", "out", "node_modules", ".idea")

function Get-JavaFiles {
    param([string]$Path)
    Get-ChildItem -Path $Path -Recurse -Include "*.java","*.kt" -File -ErrorAction SilentlyContinue |
        Where-Object {
            $fullPath = $_.FullName
            -not ($ExcludeDirs | Where-Object { $fullPath -match "[\\/]$_[\\/]" })
        }
}

function Get-BuildFiles {
    param([string]$Path)
    Get-ChildItem -Path $Path -Recurse -Include "*.gradle","*.gradle.kts","pom.xml" -File -ErrorAction SilentlyContinue |
        Where-Object {
            $fullPath = $_.FullName
            -not ($ExcludeDirs | Where-Object { $fullPath -match "[\\/]$_[\\/]" })
        }
}

function Count-Matches {
    param([string]$Pattern, [System.IO.FileInfo[]]$Files)
    $count = 0
    $matchedFiles = @()
    foreach ($file in $Files) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if ($content -and $content -match [regex]::Escape($Pattern)) {
            $count++
            $matchedFiles += $file.FullName
        }
    }
    return @{ Count = $count; Files = $matchedFiles }
}

function Count-BuildDeps {
    param([string]$Pattern, [System.IO.FileInfo[]]$Files)
    $count = 0
    foreach ($file in $Files) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if ($content -and $content -match [regex]::Escape($Pattern)) {
            $count++
        }
    }
    return $count
}

# ── Start ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "==============================================================" -ForegroundColor White
Write-Host "  HTTP Client Usage Scanner - Spring Boot Monorepo" -ForegroundColor White
Write-Host "==============================================================" -ForegroundColor White
Write-Host "  Scanning: $RepoRoot" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Finding all Java/Kotlin files (this may take a moment)..." -ForegroundColor Gray

$javaFiles = @(Get-JavaFiles -Path $RepoRoot)
$buildFiles = @(Get-BuildFiles -Path $RepoRoot)

Write-Host "  Found $($javaFiles.Count) source files and $($buildFiles.Count) build files." -ForegroundColor Gray
Write-Host ""

# ── 1. RESTTEMPLATE ───────────────────────────────────────────────────
Write-Host "[1/7] Scanning for RestTemplate..." -ForegroundColor White
$rtRef      = Count-Matches -Pattern "RestTemplate" -Files $javaFiles
$rtNew      = Count-Matches -Pattern "new RestTemplate()" -Files $javaFiles
$rtImport   = Count-Matches -Pattern "import org.springframework.web.client.RestTemplate" -Files $javaFiles
$rtBuilder  = Count-Matches -Pattern "RestTemplateBuilder" -Files $javaFiles
$rtDep      = Count-BuildDeps -Pattern "spring-boot-starter-web" -Files $buildFiles

Write-Host "  RestTemplate references: $($rtRef.Count) files" -ForegroundColor Green
Write-Host "    - import RestTemplate:     $($rtImport.Count) files"
Write-Host "    - new RestTemplate():      $($rtNew.Count) files (! inline, not a bean)" -ForegroundColor $(if($rtNew.Count -gt 0){"Yellow"}else{"Gray"})
Write-Host "    - RestTemplateBuilder:     $($rtBuilder.Count) files"
Write-Host "    - starter-web in build:    $rtDep files"

# ── 2. WEBCLIENT ──────────────────────────────────────────────────────
Write-Host ""
Write-Host "[2/7] Scanning for WebClient (reactive)..." -ForegroundColor White
$wcRef     = Count-Matches -Pattern "WebClient" -Files $javaFiles
$wcImport  = Count-Matches -Pattern "import org.springframework.web.reactive.function.client.WebClient" -Files $javaFiles
$wcBuilder = Count-Matches -Pattern "WebClient.builder()" -Files $javaFiles
$wcDep     = Count-BuildDeps -Pattern "spring-boot-starter-webflux" -Files $buildFiles

Write-Host "  WebClient references: $($wcRef.Count) files" -ForegroundColor Yellow
Write-Host "    - import WebClient:        $($wcImport.Count) files"
Write-Host "    - WebClient.builder():     $($wcBuilder.Count) files"
Write-Host "    - starter-webflux in build:$wcDep files"

# ── 3. FEIGN ──────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[3/7] Scanning for OpenFeign..." -ForegroundColor White
$fgRef    = Count-Matches -Pattern "@FeignClient" -Files $javaFiles
$fgImport = Count-Matches -Pattern "import org.springframework.cloud.openfeign" -Files $javaFiles
$fgEnable = Count-Matches -Pattern "@EnableFeignClients" -Files $javaFiles
$fgDep    = Count-BuildDeps -Pattern "openfeign" -Files $buildFiles

Write-Host "  Feign references: $($fgRef.Count) files" -ForegroundColor Yellow
Write-Host "    - @FeignClient:            $($fgRef.Count) files"
Write-Host "    - @EnableFeignClients:     $($fgEnable.Count) files"
Write-Host "    - import openfeign:        $($fgImport.Count) files"
Write-Host "    - openfeign in build:      $fgDep files"

# ── 4. JAVA HTTPCLIENT ───────────────────────────────────────────────
Write-Host ""
Write-Host "[4/7] Scanning for Java HttpClient (java.net.http)..." -ForegroundColor White
$hcRef    = Count-Matches -Pattern "java.net.http.HttpClient" -Files $javaFiles
$hcImport = Count-Matches -Pattern "import java.net.http.HttpClient" -Files $javaFiles
$hcReq    = Count-Matches -Pattern "import java.net.http.HttpRequest" -Files $javaFiles

Write-Host "  Java HttpClient references: $($hcRef.Count) files" -ForegroundColor Yellow
Write-Host "    - import HttpClient:       $($hcImport.Count) files"
Write-Host "    - import HttpRequest:      $($hcReq.Count) files"

# ── 5. OKHTTP ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[5/7] Scanning for OkHttp..." -ForegroundColor White
$okRef    = Count-Matches -Pattern "OkHttpClient" -Files $javaFiles
$okImport = Count-Matches -Pattern "import okhttp3" -Files $javaFiles
$okDep    = Count-BuildDeps -Pattern "okhttp" -Files $buildFiles

Write-Host "  OkHttp references: $($okRef.Count) files" -ForegroundColor Yellow
Write-Host "    - OkHttpClient:            $($okRef.Count) files"
Write-Host "    - import okhttp3:          $($okImport.Count) files"
Write-Host "    - okhttp in build:         $okDep files"

# ── 6. SPRING RestClient (6.1+) ──────────────────────────────────────
Write-Host ""
Write-Host "[6/7] Scanning for Spring RestClient (Spring 6.1+)..." -ForegroundColor White
$rcImport  = Count-Matches -Pattern "import org.springframework.web.client.RestClient" -Files $javaFiles
$rcBuilder = Count-Matches -Pattern "RestClient.builder()" -Files $javaFiles

Write-Host "  RestClient references: $($rcImport.Count) files" -ForegroundColor Yellow
Write-Host "    - import RestClient:       $($rcImport.Count) files"
Write-Host "    - RestClient.builder():    $($rcBuilder.Count) files"

# ── 7. RETROFIT ───────────────────────────────────────────────────────
Write-Host ""
Write-Host "[7/7] Scanning for Retrofit..." -ForegroundColor White
$rfRef = Count-Matches -Pattern "import retrofit2" -Files $javaFiles
$rfDep = Count-BuildDeps -Pattern "retrofit" -Files $buildFiles

Write-Host "  Retrofit references: $($rfRef.Count) files" -ForegroundColor Yellow
Write-Host "    - import retrofit2:        $($rfRef.Count) files"
Write-Host "    - retrofit in build:       $rfDep files"

# ── BONUS: Bean vs Inline ─────────────────────────────────────────────
Write-Host ""
Write-Host "--------------------------------------------------------------" -ForegroundColor White
Write-Host "  BONUS: RestTemplate - Bean vs Inline Check" -ForegroundColor White
Write-Host "--------------------------------------------------------------" -ForegroundColor White
Write-Host ""

$inlineCount = 0
$beanCount = 0

foreach ($file in $rtNew.Files) {
    $lines = Get-Content $file -ErrorAction SilentlyContinue
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "new RestTemplate\(\)") {
            # Check 3 lines above for @Bean
            $context = ""
            for ($j = [Math]::Max(0, $i - 3); $j -lt $i; $j++) {
                $context += $lines[$j]
            }
            $relativePath = $file.Replace($RepoRoot.Path, "").TrimStart("\", "/")
            if ($context -match "@Bean") {
                $beanCount++
                Write-Host "  [BEAN] $relativePath : line $($i + 1)" -ForegroundColor Green
            } else {
                # Skip test files
                if ($relativePath -notmatch "[Tt]est") {
                    $inlineCount++
                    Write-Host "  [INLINE] $relativePath : line $($i + 1)" -ForegroundColor Red
                }
            }
        }
    }
}

if ($inlineCount -eq 0 -and $beanCount -eq 0) {
    Write-Host "  No new RestTemplate() calls found." -ForegroundColor Gray
} elseif ($inlineCount -eq 0) {
    Write-Host ""
    Write-Host "  All $beanCount RestTemplate(s) are declared as @Bean - good!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "  WARNING: $inlineCount inline RestTemplate(s) won't be intercepted!" -ForegroundColor Red
}

# ── SUMMARY ───────────────────────────────────────────────────────────
Write-Host ""
Write-Host "==============================================================" -ForegroundColor White
Write-Host "  SUMMARY" -ForegroundColor White
Write-Host "==============================================================" -ForegroundColor White
Write-Host ""

$results = @(
    @{ Name = "RestTemplate";             Count = $rtRef.Count;     Compat = $true  },
    @{ Name = "WebClient (reactive)";     Count = $wcRef.Count;     Compat = $false },
    @{ Name = "OpenFeign";                Count = $fgRef.Count;     Compat = $false },
    @{ Name = "Java HttpClient";          Count = $hcRef.Count;     Compat = $false },
    @{ Name = "OkHttp";                   Count = $okRef.Count;     Compat = $false },
    @{ Name = "Spring RestClient (6.1+)"; Count = $rcImport.Count;  Compat = $false },
    @{ Name = "Retrofit";                 Count = $rfRef.Count;     Compat = $false }
)

foreach ($r in $results) {
    if ($r.Count -gt 0) {
        if ($r.Compat) {
            Write-Host "  [YES] $($r.Name): $($r.Count) files  (starter compatible)" -ForegroundColor Green
        } else {
            Write-Host "  [NO]  $($r.Name): $($r.Count) files  (needs separate interceptor)" -ForegroundColor Red
        }
    } else {
        Write-Host "  [ . ] $($r.Name): 0 files" -ForegroundColor DarkGray
    }
}

Write-Host ""

# ── Verdict ───────────────────────────────────────────────────────────
$nonRt = $wcRef.Count + $fgRef.Count + $hcRef.Count + $okRef.Count + $rcImport.Count + $rfRef.Count

if ($rtRef.Count -gt 0 -and $nonRt -eq 0) {
    Write-Host "  VERDICT: Your monorepo uses only RestTemplate." -ForegroundColor Green
    Write-Host "  The downstream-health-starter will cover all outbound HTTP calls." -ForegroundColor Green
} elseif ($rtRef.Count -gt 0 -and $nonRt -gt 0) {
    Write-Host "  VERDICT: Mixed HTTP clients detected." -ForegroundColor Yellow
    Write-Host "  The starter will cover RestTemplate calls but NOT the others." -ForegroundColor Yellow
    Write-Host "  You'll need additional interceptors for full coverage." -ForegroundColor Yellow
} elseif ($rtRef.Count -eq 0 -and $nonRt -gt 0) {
    Write-Host "  VERDICT: No RestTemplate usage found." -ForegroundColor Red
    Write-Host "  The downstream-health-starter won't intercept anything." -ForegroundColor Red
    Write-Host "  You need a different interceptor strategy for your HTTP client." -ForegroundColor Red
} else {
    Write-Host "  VERDICT: No HTTP client usage found in source files." -ForegroundColor Cyan
    Write-Host "  Check if your code is in a different language or location." -ForegroundColor Cyan
}

Write-Host ""
Write-Host "--------------------------------------------------------------" -ForegroundColor White
Write-Host "  Scan complete." -ForegroundColor Gray
Write-Host "--------------------------------------------------------------" -ForegroundColor White
Write-Host ""
