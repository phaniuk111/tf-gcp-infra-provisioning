 ─────────────────────────────────────────────────────────────────────
# scan-http-clients.ps1  (v2 — with per-module breakdown)
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

$RepoRoot = (Resolve-Path $RepoRoot -ErrorAction Stop).Path

# ── Exclude folders ───────────────────────────────────────────────────
$ExcludeDirs = @("build", "target", ".gradle", "bin", "out", "node_modules", ".idea", ".git")

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

# ── Helper: Extract module name from file path ───────────────────────
function Get-ModuleName {
    param([string]$FilePath)
    $relative = $FilePath.Replace($RepoRoot, "").TrimStart("\", "/")
    $parts = $relative -split "[\\/]"
    # The first folder under repo root is usually the module name
    # e.g. order-service/src/main/java/... → order-service
    if ($parts.Count -gt 1) {
        # Check if first part contains "src" — if so, it's root-level code
        if ($parts[0] -eq "src") {
            return "(root project)"
        }
        return $parts[0]
    }
    return "(root)"
}

# ── Helper: Group files by module ─────────────────────────────────────
function Group-ByModule {
    param([string[]]$FilePaths)
    $grouped = @{}
    foreach ($fp in $FilePaths) {
        $module = Get-ModuleName -FilePath $fp
        if (-not $grouped.ContainsKey($module)) {
            $grouped[$module] = @()
        }
        $grouped[$module] += $fp
    }
    return $grouped
}

# ── Helper: Print module breakdown ────────────────────────────────────
function Show-ModuleBreakdown {
    param([string]$Label, [hashtable]$Grouped, [string]$Color)
    if ($Grouped.Count -eq 0) { return }
    foreach ($module in ($Grouped.Keys | Sort-Object)) {
        $files = $Grouped[$module]
        Write-Host "      $module : $($files.Count) file(s)" -ForegroundColor $Color
        foreach ($f in $files) {
            $relative = $f.Replace($RepoRoot, "").TrimStart("\", "/")
            Write-Host "        - $relative" -ForegroundColor DarkGray
        }
    }
}

# ── Start ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "==============================================================" -ForegroundColor White
Write-Host "  HTTP Client Usage Scanner v2 - Spring Boot Monorepo" -ForegroundColor White
Write-Host "  (with per-module breakdown)" -ForegroundColor Gray
Write-Host "==============================================================" -ForegroundColor White
Write-Host "  Scanning: $RepoRoot" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Finding all Java/Kotlin files (this may take a moment)..." -ForegroundColor Gray

$javaFiles = @(Get-JavaFiles -Path $RepoRoot)
$buildFiles = @(Get-BuildFiles -Path $RepoRoot)

Write-Host "  Found $($javaFiles.Count) source files and $($buildFiles.Count) build files." -ForegroundColor Gray
Write-Host ""

# ── Detect modules ────────────────────────────────────────────────────
$allModules = @{}
foreach ($f in $javaFiles) {
    $mod = Get-ModuleName -FilePath $f.FullName
    if (-not $allModules.ContainsKey($mod)) { $allModules[$mod] = 0 }
    $allModules[$mod]++
}
Write-Host "  Detected $($allModules.Count) module(s): $( ($allModules.Keys | Sort-Object) -join ', ' )" -ForegroundColor Gray
Write-Host ""

# ── Track per-module results for final matrix ─────────────────────────
$moduleMatrix = @{}
foreach ($mod in $allModules.Keys) {
    $moduleMatrix[$mod] = @{
        RestTemplate = 0
        KerberosRestTemplate = 0
        WebClient = 0
        Feign = 0
        HttpClient = 0
        OkHttp = 0
        RestClient = 0
        Retrofit = 0
    }
}

# ── 1. RESTTEMPLATE ───────────────────────────────────────────────────
Write-Host "[1/8] Scanning for RestTemplate..." -ForegroundColor White
$rtRef      = Count-Matches -Pattern "RestTemplate" -Files $javaFiles
$rtNew      = Count-Matches -Pattern "new RestTemplate()" -Files $javaFiles
$rtImport   = Count-Matches -Pattern "import org.springframework.web.client.RestTemplate" -Files $javaFiles
$rtBuilder  = Count-Matches -Pattern "RestTemplateBuilder" -Files $javaFiles
$rtDep      = Count-BuildDeps -Pattern "spring-boot-starter-web" -Files $buildFiles

Write-Host "  RestTemplate references: $($rtRef.Count) files" -ForegroundColor Green
Write-Host "    - import RestTemplate:     $($rtImport.Count) files"
Write-Host "    - new RestTemplate():      $($rtNew.Count) files" -ForegroundColor $(if($rtNew.Count -gt 0){"Yellow"}else{"Gray"})
Write-Host "    - RestTemplateBuilder:     $($rtBuilder.Count) files"
Write-Host "    - starter-web in build:    $rtDep files"

$rtGrouped = Group-ByModule -FilePaths $rtImport.Files
Write-Host "    Per module:" -ForegroundColor Cyan
Show-ModuleBreakdown -Grouped $rtGrouped -Color "Green"
foreach ($mod in $rtGrouped.Keys) {
    if ($moduleMatrix.ContainsKey($mod)) { $moduleMatrix[$mod].RestTemplate = $rtGrouped[$mod].Count }
}

# ── 1b. KERBEROS RESTTEMPLATE ─────────────────────────────────────────
Write-Host ""
Write-Host "[1b] Scanning for KerberosRestTemplate..." -ForegroundColor White
$krbRef    = Count-Matches -Pattern "KerberosRestTemplate" -Files $javaFiles
$krbImport = Count-Matches -Pattern "import org.springframework.security.kerberos" -Files $javaFiles

Write-Host "  KerberosRestTemplate references: $($krbRef.Count) files" -ForegroundColor Green
Write-Host "    (extends RestTemplate - starter compatible)" -ForegroundColor Green

if ($krbRef.Count -gt 0) {
    $krbGrouped = Group-ByModule -FilePaths $krbRef.Files
    Write-Host "    Per module:" -ForegroundColor Cyan
    Show-ModuleBreakdown -Grouped $krbGrouped -Color "Green"
    foreach ($mod in $krbGrouped.Keys) {
        if ($moduleMatrix.ContainsKey($mod)) { $moduleMatrix[$mod].KerberosRestTemplate = $krbGrouped[$mod].Count }
    }
}

# ── 2. WEBCLIENT ──────────────────────────────────────────────────────
Write-Host ""
Write-Host "[2/8] Scanning for WebClient (reactive)..." -ForegroundColor White
$wcRef     = Count-Matches -Pattern "WebClient" -Files $javaFiles
$wcImport  = Count-Matches -Pattern "import org.springframework.web.reactive.function.client.WebClient" -Files $javaFiles
$wcBuilder = Count-Matches -Pattern "WebClient.builder()" -Files $javaFiles
$wcDep     = Count-BuildDeps -Pattern "spring-boot-starter-webflux" -Files $buildFiles

Write-Host "  WebClient references: $($wcImport.Count) files" -ForegroundColor Yellow
Write-Host "    - import WebClient:        $($wcImport.Count) files"
Write-Host "    - WebClient.builder():     $($wcBuilder.Count) files"
Write-Host "    - starter-webflux in build:$wcDep files"

if ($wcImport.Count -gt 0) {
    $wcGrouped = Group-ByModule -FilePaths $wcImport.Files
    Write-Host "    Per module:" -ForegroundColor Cyan
    Show-ModuleBreakdown -Grouped $wcGrouped -Color "Yellow"
    foreach ($mod in $wcGrouped.Keys) {
        if ($moduleMatrix.ContainsKey($mod)) { $moduleMatrix[$mod].WebClient = $wcGrouped[$mod].Count }
    }
}

# ── 3. FEIGN ──────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[3/8] Scanning for OpenFeign..." -ForegroundColor White
$fgRef    = Count-Matches -Pattern "@FeignClient" -Files $javaFiles
$fgImport = Count-Matches -Pattern "import org.springframework.cloud.openfeign" -Files $javaFiles
$fgEnable = Count-Matches -Pattern "@EnableFeignClients" -Files $javaFiles
$fgDep    = Count-BuildDeps -Pattern "openfeign" -Files $buildFiles

Write-Host "  Feign references: $($fgRef.Count) files" -ForegroundColor Yellow
Write-Host "    - @FeignClient:            $($fgRef.Count) files"
Write-Host "    - @EnableFeignClients:     $($fgEnable.Count) files"
Write-Host "    - openfeign in build:      $fgDep files"

if ($fgRef.Count -gt 0) {
    $fgGrouped = Group-ByModule -FilePaths $fgRef.Files
    Write-Host "    Per module:" -ForegroundColor Cyan
    Show-ModuleBreakdown -Grouped $fgGrouped -Color "Yellow"
    foreach ($mod in $fgGrouped.Keys) {
        if ($moduleMatrix.ContainsKey($mod)) { $moduleMatrix[$mod].Feign = $fgGrouped[$mod].Count }
    }
}

# ── 4. JAVA HTTPCLIENT ───────────────────────────────────────────────
Write-Host ""
Write-Host "[4/8] Scanning for Java HttpClient (java.net.http)..." -ForegroundColor White
$hcRef    = Count-Matches -Pattern "java.net.http.HttpClient" -Files $javaFiles
$hcImport = Count-Matches -Pattern "import java.net.http.HttpClient" -Files $javaFiles
$hcReq    = Count-Matches -Pattern "import java.net.http.HttpRequest" -Files $javaFiles

Write-Host "  Java HttpClient references: $($hcImport.Count) files" -ForegroundColor Yellow
Write-Host "    - import HttpClient:       $($hcImport.Count) files"
Write-Host "    - import HttpRequest:      $($hcReq.Count) files"

if ($hcImport.Count -gt 0) {
    $hcGrouped = Group-ByModule -FilePaths $hcImport.Files
    Write-Host "    Per module:" -ForegroundColor Cyan
    Show-ModuleBreakdown -Grouped $hcGrouped -Color "Yellow"
    foreach ($mod in $hcGrouped.Keys) {
        if ($moduleMatrix.ContainsKey($mod)) { $moduleMatrix[$mod].HttpClient = $hcGrouped[$mod].Count }
    }
}

# ── 5. OKHTTP ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[5/8] Scanning for OkHttp..." -ForegroundColor White
$okRef    = Count-Matches -Pattern "OkHttpClient" -Files $javaFiles
$okImport = Count-Matches -Pattern "import okhttp3" -Files $javaFiles
$okDep    = Count-BuildDeps -Pattern "okhttp" -Files $buildFiles

Write-Host "  OkHttp references: $($okRef.Count) files" -ForegroundColor Yellow
Write-Host "    - OkHttpClient:            $($okRef.Count) files"
Write-Host "    - import okhttp3:          $($okImport.Count) files"
Write-Host "    - okhttp in build:         $okDep files"

if ($okImport.Count -gt 0) {
    $okGrouped = Group-ByModule -FilePaths $okImport.Files
    Write-Host "    Per module:" -ForegroundColor Cyan
    Show-ModuleBreakdown -Grouped $okGrouped -Color "Yellow"
    foreach ($mod in $okGrouped.Keys) {
        if ($moduleMatrix.ContainsKey($mod)) { $moduleMatrix[$mod].OkHttp = $okGrouped[$mod].Count }
    }
}

# ── 6. SPRING RestClient (6.1+) ──────────────────────────────────────
Write-Host ""
Write-Host "[6/8] Scanning for Spring RestClient (Spring 6.1+)..." -ForegroundColor White
$rcImport  = Count-Matches -Pattern "import org.springframework.web.client.RestClient" -Files $javaFiles
$rcBuilder = Count-Matches -Pattern "RestClient.builder()" -Files $javaFiles

Write-Host "  RestClient references: $($rcImport.Count) files" -ForegroundColor Yellow
Write-Host "    - import RestClient:       $($rcImport.Count) files"
Write-Host "    - RestClient.builder():    $($rcBuilder.Count) files"

if ($rcImport.Count -gt 0) {
    $rcGrouped = Group-ByModule -FilePaths $rcImport.Files
    Write-Host "    Per module:" -ForegroundColor Cyan
    Show-ModuleBreakdown -Grouped $rcGrouped -Color "Yellow"
    foreach ($mod in $rcGrouped.Keys) {
        if ($moduleMatrix.ContainsKey($mod)) { $moduleMatrix[$mod].RestClient = $rcGrouped[$mod].Count }
    }
}

# ── 7. RETROFIT ───────────────────────────────────────────────────────
Write-Host ""
Write-Host "[7/8] Scanning for Retrofit..." -ForegroundColor White
$rfRef = Count-Matches -Pattern "import retrofit2" -Files $javaFiles
$rfDep = Count-BuildDeps -Pattern "retrofit" -Files $buildFiles

Write-Host "  Retrofit references: $($rfRef.Count) files" -ForegroundColor Yellow
Write-Host "    - import retrofit2:        $($rfRef.Count) files"
Write-Host "    - retrofit in build:       $rfDep files"

if ($rfRef.Count -gt 0) {
    $rfGrouped = Group-ByModule -FilePaths $rfRef.Files
    Write-Host "    Per module:" -ForegroundColor Cyan
    Show-ModuleBreakdown -Grouped $rfGrouped -Color "Yellow"
    foreach ($mod in $rfGrouped.Keys) {
        if ($moduleMatrix.ContainsKey($mod)) { $moduleMatrix[$mod].Retrofit = $rfGrouped[$mod].Count }
    }
}

# ── 8. SPRING VERSION CHECK ──────────────────────────────────────────
Write-Host ""
Write-Host "[8/8] Checking Spring Boot version..." -ForegroundColor White

$versionFiles = @()
$versionFiles += Get-ChildItem -Path $RepoRoot -Recurse -Include "*.gradle","*.gradle.kts","pom.xml","gradle.properties" -File -ErrorAction SilentlyContinue |
    Where-Object {
        $fullPath = $_.FullName
        -not ($ExcludeDirs | Where-Object { $fullPath -match "[\\/]$_[\\/]" })
    }

$springBootVersion = "unknown"
foreach ($vf in $versionFiles) {
    $content = Get-Content $vf.FullName -Raw -ErrorAction SilentlyContinue
    if ($content) {
        # Match patterns like: spring-boot version "3.2.5" or springBootVersion = "3.2.5"
        if ($content -match "org\.springframework\.boot[^0-9]*(\d+\.\d+\.\d+)") {
            $springBootVersion = $Matches[1]
            break
        }
        if ($content -match "springBootVersion\s*[=:]\s*[`"'](\d+\.\d+\.\d+)") {
            $springBootVersion = $Matches[1]
            break
        }
    }
}

$javaVersion = "unknown"
foreach ($vf in $versionFiles) {
    $content = Get-Content $vf.FullName -Raw -ErrorAction SilentlyContinue
    if ($content) {
        if ($content -match "sourceCompatibility\s*=\s*JavaVersion\.VERSION_(\d+)") {
            $javaVersion = $Matches[1]
            break
        }
        if ($content -match "sourceCompatibility\s*=\s*[`"']?(\d+)") {
            $javaVersion = $Matches[1]
            break
        }
        if ($content -match "<java\.version>(\d+)</java\.version>") {
            $javaVersion = $Matches[1]
            break
        }
    }
}

Write-Host "  Spring Boot version: $springBootVersion" -ForegroundColor $(if($springBootVersion -match "^3\."){"Green"}elseif($springBootVersion -eq "unknown"){"Yellow"}else{"Red"})
Write-Host "  Java version:        $javaVersion" -ForegroundColor $(if([int]$javaVersion -ge 17){"Green"}elseif($javaVersion -eq "unknown"){"Yellow"}else{"Red"})

if ($springBootVersion -match "^2\.") {
    Write-Host "  WARNING: Spring Boot 2.x detected. The starter requires Spring Boot 3.x!" -ForegroundColor Red
}
if ($javaVersion -ne "unknown" -and [int]$javaVersion -lt 17) {
    Write-Host "  WARNING: Java $javaVersion detected. The starter requires Java 17+!" -ForegroundColor Red
}

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
            $context = ""
            for ($j = [Math]::Max(0, $i - 3); $j -lt $i; $j++) {
                $context += $lines[$j]
            }
            $relativePath = $file.Replace($RepoRoot, "").TrimStart("\", "/")
            $module = ($relativePath -split "[\\/]")[0]
            if ($context -match "@Bean") {
                $beanCount++
                Write-Host "  [BEAN]   $module > $relativePath : line $($i + 1)" -ForegroundColor Green
            } else {
                if ($relativePath -notmatch "[Tt]est") {
                    $inlineCount++
                    Write-Host "  [INLINE] $module > $relativePath : line $($i + 1)" -ForegroundColor Red
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
    Write-Host "  Fix: Move these to @Bean methods in a @Configuration class." -ForegroundColor Yellow
}

# ══════════════════════════════════════════════════════════════════════
# MODULE MATRIX — the key per-module view
# ══════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "==============================================================" -ForegroundColor White
Write-Host "  MODULE MATRIX — HTTP Client Usage Per Module" -ForegroundColor White
Write-Host "==============================================================" -ForegroundColor White
Write-Host ""

# Header
$header = "{0,-30} {1,6} {2,6} {3,6} {4,6} {5,6} {6,6} {7,6} {8,10}" -f "MODULE", "RestT", "Kerb", "WebCl", "Feign", "HttpC", "OkHtp", "RstCl", "COVERAGE"
Write-Host "  $header" -ForegroundColor Gray
Write-Host "  $("-" * 94)" -ForegroundColor DarkGray

foreach ($mod in ($moduleMatrix.Keys | Sort-Object)) {
    $m = $moduleMatrix[$mod]
    $compatible = $m.RestTemplate + $m.KerberosRestTemplate
    $incompatible = $m.WebClient + $m.Feign + $m.HttpClient + $m.OkHttp + $m.RestClient + $m.Retrofit
    $total = $compatible + $incompatible

    if ($total -eq 0) {
        $coverage = "N/A"
        $coverageColor = "DarkGray"
    } elseif ($incompatible -eq 0) {
        $coverage = "FULL"
        $coverageColor = "Green"
    } else {
        $pct = [math]::Round(($compatible / $total) * 100)
        $coverage = "$pct%"
        $coverageColor = if ($pct -ge 80) { "Yellow" } else { "Red" }
    }

    $row = "{0,-30} {1,6} {2,6} {3,6} {4,6} {5,6} {6,6} {7,6}" -f $mod,
        $(if($m.RestTemplate -gt 0){$m.RestTemplate}else{"-"}),
        $(if($m.KerberosRestTemplate -gt 0){$m.KerberosRestTemplate}else{"-"}),
        $(if($m.WebClient -gt 0){$m.WebClient}else{"-"}),
        $(if($m.Feign -gt 0){$m.Feign}else{"-"}),
        $(if($m.HttpClient -gt 0){$m.HttpClient}else{"-"}),
        $(if($m.OkHttp -gt 0){$m.OkHttp}else{"-"}),
        $(if($m.RestClient -gt 0){$m.RestClient}else{"-"})

    Write-Host "  $row" -NoNewline
    Write-Host (" {0,10}" -f $coverage) -ForegroundColor $coverageColor
}

Write-Host ""
Write-Host "  Legend: RestT=RestTemplate  Kerb=KerberosRestTemplate  WebCl=WebClient" -ForegroundColor DarkGray
Write-Host "          Feign=OpenFeign  HttpC=Java HttpClient  OkHtp=OkHttp  RstCl=RestClient" -ForegroundColor DarkGray
Write-Host "          COVERAGE = % of HTTP calls covered by the downstream-health-starter" -ForegroundColor DarkGray

# ── SUMMARY ───────────────────────────────────────────────────────────
Write-Host ""
Write-Host "==============================================================" -ForegroundColor White
Write-Host "  SUMMARY" -ForegroundColor White
Write-Host "==============================================================" -ForegroundColor White
Write-Host ""

$results = @(
    @{ Name = "RestTemplate";             Count = $rtRef.Count;     Compat = $true  },
    @{ Name = "KerberosRestTemplate";     Count = $krbRef.Count;    Compat = $true  },
    @{ Name = "WebClient (reactive)";     Count = $wcImport.Count;  Compat = $false },
    @{ Name = "OpenFeign";                Count = $fgRef.Count;     Compat = $false },
    @{ Name = "Java HttpClient";          Count = $hcImport.Count;  Compat = $false },
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
$compatTotal = $rtRef.Count + $krbRef.Count
$nonRt = $wcImport.Count + $fgRef.Count + $hcImport.Count + $okRef.Count + $rcImport.Count + $rfRef.Count

if ($compatTotal -gt 0 -and $nonRt -eq 0) {
    Write-Host "  VERDICT: Your monorepo uses only RestTemplate (including Kerberos)." -ForegroundColor Green
    Write-Host "  The downstream-health-starter will cover ALL outbound HTTP calls." -ForegroundColor Green
} elseif ($compatTotal -gt 0 -and $nonRt -gt 0) {
    $coveragePct = [math]::Round(($compatTotal / ($compatTotal + $nonRt)) * 100)
    Write-Host "  VERDICT: Mixed HTTP clients detected." -ForegroundColor Yellow
    Write-Host "  Starter covers $compatTotal files ($coveragePct%) — RestTemplate + KerberosRestTemplate." -ForegroundColor Yellow
    Write-Host "  Not covered: $nonRt files using other HTTP clients." -ForegroundColor Yellow
    Write-Host ""
    if ($wcImport.Count -gt 0) {
        Write-Host "  ACTION NEEDED for WebClient ($($wcImport.Count) files):" -ForegroundColor Cyan
        Write-Host "    Add an ExchangeFilterFunction interceptor to the starter." -ForegroundColor Gray
    }
    if ($rcImport.Count -gt 0) {
        Write-Host "  ACTION NEEDED for RestClient ($($rcImport.Count) files):" -ForegroundColor Cyan
        Write-Host "    RestClient supports ClientHttpRequestInterceptor — same as RestTemplate." -ForegroundColor Gray
        Write-Host "    Extend the BeanPostProcessor to also detect RestClient beans." -ForegroundColor Gray
    }
} elseif ($compatTotal -eq 0 -and $nonRt -gt 0) {
    Write-Host "  VERDICT: No RestTemplate usage found." -ForegroundColor Red
    Write-Host "  The downstream-health-starter won't intercept anything." -ForegroundColor Red
} else {
    Write-Host "  VERDICT: No HTTP client usage found in source files." -ForegroundColor Cyan
}

# ── Prerequisites check ──────────────────────────────────────────────
Write-Host ""
Write-Host "==============================================================" -ForegroundColor White
Write-Host "  PREREQUISITES CHECK" -ForegroundColor White
Write-Host "==============================================================" -ForegroundColor White
Write-Host ""

$prereqOk = $true

# Java version
if ($javaVersion -ne "unknown" -and [int]$javaVersion -ge 17) {
    Write-Host "  [PASS] Java $javaVersion detected (requires 17+)" -ForegroundColor Green
} elseif ($javaVersion -eq "unknown") {
    Write-Host "  [????] Could not detect Java version — verify manually (requires 17+)" -ForegroundColor Yellow
} else {
    Write-Host "  [FAIL] Java $javaVersion detected — requires Java 17+" -ForegroundColor Red
    $prereqOk = $false
}

# Spring Boot version
if ($springBootVersion -match "^3\.") {
    Write-Host "  [PASS] Spring Boot $springBootVersion detected (requires 3.x)" -ForegroundColor Green
} elseif ($springBootVersion -eq "unknown") {
    Write-Host "  [????] Could not detect Spring Boot version — verify manually (requires 3.x)" -ForegroundColor Yellow
} else {
    Write-Host "  [FAIL] Spring Boot $springBootVersion detected — requires 3.x" -ForegroundColor Red
    $prereqOk = $false
}

# RestTemplate as beans
if ($inlineCount -eq 0) {
    Write-Host "  [PASS] All RestTemplates are declared as @Bean" -ForegroundColor Green
} else {
    Write-Host "  [WARN] $inlineCount inline RestTemplate(s) — these won't be intercepted" -ForegroundColor Yellow
}

# Actuator
$actuatorDep = Count-BuildDeps -Pattern "spring-boot-starter-actuator" -Files $buildFiles
if ($actuatorDep -gt 0) {
    Write-Host "  [PASS] spring-boot-starter-actuator found in $actuatorDep build file(s)" -ForegroundColor Green
} else {
    Write-Host "  [WARN] spring-boot-starter-actuator not found — add it to services that need monitoring" -ForegroundColor Yellow
}

# AOP
$aopDep = Count-BuildDeps -Pattern "spring-boot-starter-aop" -Files $buildFiles
if ($aopDep -gt 0) {
    Write-Host "  [PASS] spring-boot-starter-aop found in $aopDep build file(s)" -ForegroundColor Green
} else {
    Write-Host "  [WARN] spring-boot-starter-aop not found — required by Resilience4j" -ForegroundColor Yellow
}

Write-Host ""
if ($prereqOk) {
    Write-Host "  Ready to integrate the downstream-health-starter!" -ForegroundColor Green
} else {
    Write-Host "  Fix the FAIL items above before integrating the starter." -ForegroundColor Red
}

Write-Host ""
Write-Host "--------------------------------------------------------------" -ForegroundColor White
Write-Host "  Scan complete." -ForegroundColor Gray
Write-Host "--------------------------------------------------------------" -ForegroundColor White
Write-Host ""
