# TLS Handshake Troubleshooting — Hadoop → GKE Istio

> **Context:** Hadoop JVM client failing TLS handshake to GKE Istio Ingress Gateway in PRD.  
> UAT works. PRD fails. Firewall is confirmed open.

---

## Table of Contents

1. [How TLS Handshake Works](#1-how-tls-handshake-works)
2. [Two Types of Handshake Failure](#2-two-types-of-handshake-failure)
3. [Why Postman Works but Hadoop Fails](#3-why-postman-works-but-hadoop-fails)
4. [Why UAT Works but PRD Fails](#4-why-uat-works-but-prd-fails)
5. [Where CA Validation Happens](#5-where-ca-validation-happens)
6. [Where to Find Logs](#6-where-to-find-logs)
7. [Root Cause Scenarios](#7-root-cause-scenarios)
8. [Decision Tree — How to Diagnose](#8-decision-tree--how-to-diagnose)
9. [Troubleshooting Commands](#9-troubleshooting-commands)
10. [Fix Commands](#10-fix-commands)
11. [Error Code Reference](#11-error-code-reference)

---

## 1. How TLS Handshake Works

### Layer 0 — TCP (Firewall)

Before TLS even starts, a TCP connection must be established. The firewall must allow this.

```
Hadoop JVM                    Istio Ingress Gateway
    |                               |
    |---- TCP SYN ----------------> |   <- Port 443 must be open
    |<--- TCP SYN-ACK ------------- |
    |---- TCP ACK ----------------> |
    |                               |
    |   TCP established             |
    |   TLS handshake starts now    |
```

> - Firewall **blocked** -> `Connection refused` or `Connection timed out` — TLS never starts
> - Firewall **open** but TLS fails -> problem is inside TLS layer, not network

---

### UAT — Full Success Flow

```
Hadoop JVM               Istio Ingress Gateway      GKE Pod
    |                           |                       |
    |-- 1. ClientHello -------> |                       |
    |   TLS versions supported  |                       |
    |   Cipher suites list      |                       |
    |   SNI hostname            |                       |
    |   Client random           |                       |
    |                           |                       |
    |<- 2. ServerHello -------- |                       |
    |   Chosen TLS version      |                       |
    |   Chosen cipher suite     |                       |
    |   Server random           |                       |
    |                           |                       |
    |<- 3. Certificate -------- |                       |
    |   Leaf cert               |                       |
    |   Intermediate CA         |                       |
    |   Root CA  [3 certs] OK   |                       |
    |                           |                       |
    |<- 4. ServerHelloDone ---- |                       |
    |                           |                       |
    |   5. [Validation-local]   |                       |
    |   RootCA found in cacerts |                       |
    |   Signature verified      |                       |
    |   Hostname matches SAN    |                       |
    |                           |                       |
    |-- 6. ClientKeyExchange -> |                       |
    |   Pre-master secret       |                       |
    |   encrypted with server   |                       |
    |   public key              |                       |
    |                           |                       |
    |-- 7. ChangeCipherSpec --> |                       |
    |<- 7. ChangeCipherSpec --- |                       |
    |   Both sides switch to    |                       |
    |   symmetric session keys  |                       |
    |                           |                       |
    |-- 8. Finished ----------> |                       |
    |<- 8. Finished ----------- |                       |
    |   Handshake complete      |                       |
    |   TLS tunnel open         |                       |
    |                           |                       |
    |-- 9. HTTP Request ------> |---- Forward --------> |
    |                           |                  Log written
```

**Result:** `Verify return code: 0` — Request reaches GKE pod

---

## 2. Two Types of Handshake Failure

There are **two completely different errors** that both appear as handshake failure but happen at different stages with different root causes.

---

### Type 1 — fatal handshake_failure (Alert Code 40)

**Fails at Step 1->2. Certificate is NEVER exchanged.**

```
Hadoop JVM               Istio Ingress Gateway      GKE Pod
    |                           |                       |
    |-- 1. ClientHello -------> |                       |
    |   TLS versions: [1.2]     |                       |
    |   Ciphers: [old Java]     |                       |
    |                           |                       |
    |              Istio checks:                        |
    |              Common TLS version? NO               |
    |              Common cipher?      NO               |
    |                           |                       |
    |<- alert: handshake_failure|                       |
    |   (alert code 40)         |                       |
    |                           |                       |
    |   Connection closed       |            X          |
    |   No cert ever sent       |       Never reached   |
```

**Cause:** No common TLS version or cipher suite between Hadoop JVM and Istio.

Common reasons:
- PRD Hadoop is **Java 8 below update 261** — does not support TLS 1.3
- PRD Istio `minProtocolVersion: TLSV1_3` — only accepts TLS 1.3
- Old Java cipher list has no overlap with Istio modern ciphers
- PRD Istio has stricter cipher policy than UAT

---

### Type 2 — PKIX path building failed

**Fails at Step 3->5. Certificate IS exchanged but Hadoop rejects it.**

```
Hadoop JVM               Istio Ingress Gateway      GKE Pod
    |                           |                       |
    |-- 1. ClientHello -------> |                       |
    |                           |                       |
    |<- 2. ServerHello -------- |                       |
    |                           |                       |
    |<- 3. Certificate -------- |                       |
    |   ONLY leaf cert, OR      |                       |
    |   cert from new CA        |                       |
    |                           |                       |
    |<- 4. ServerHelloDone ---- |                       |
    |                           |                       |
    |   5. [Validation-local]   |                       |
    |   Walks cert chain...     |                       |
    |   Looks for CA in cacerts |                       |
    |   CA NOT FOUND            |                       |
    |                           |                       |
    |-- 6. alert_fatal -------> |                       |
    |   certificate_unknown(46) |                       |
    |                           |                       |
    |   Connection closed       |            X          |
    |                           |       Never reached   |
```

**Cause:** Issuing CA is not in Hadoop JDK `cacerts`, OR Istio is not serving full chain.

Common reasons:
- PRD cert signed by a **different CA** than UAT — not imported into `cacerts`
- Istio TLS secret has only the **leaf cert** — intermediate CA missing
- PRD cert **recently renewed** with new CA chain not yet imported
- PRD Istio `PeerAuthentication = STRICT` — requires client cert from Hadoop

---

### Side-by-Side Comparison

| | `fatal handshake_failure` | `PKIX path building failed` |
|---|---|---|
| **Alert code** | 40 | 46 (certificate_unknown) |
| **Fails at step** | Step 1->2, during negotiation | Step 3->5, after cert received |
| **Cert exchanged?** | NO | YES |
| **Root cause** | No common TLS version or cipher | CA not in JDK `cacerts` |
| **Hadoop logs show** | ClientHello sent, alert received, no cert logged | Full cert chain, PKIX error, exact CA name |
| **Istio logs show** | TLS alert, connection closed | TLS alert, connection closed |
| **Fix** | Upgrade Java or relax Istio TLS version | Import CA into `cacerts` or fix Istio chain |

---

## 3. Why Postman Works but Hadoop Fails

```
Postman                Istio Ingress          App Pod
    |                       |                    |
    |-- TLS Handshake -----> |                    |
    |   OS trusts cert       |                    |
    |-- HTTP Request ------> |---- Forward -----> |
    |                        |               Log written

Hadoop JVM             Istio Ingress          App Pod
    |                       |                    |
    |-- TLS Handshake -----> |                    |
    |   JVM rejects cert     |                    |
    |-- alert_fatal -------> |                    X
    |                        |               Never reached
    |                        |               No log entry
```

**Postman** uses the **OS truststore** (Windows/Mac) — automatically updated by the OS.
**Hadoop JVM** uses its own `$JAVA_HOME/lib/security/cacerts` — completely separate, managed manually.

| Component | Truststore | Auto-Updated? |
|-----------|-----------|---------------|
| Postman | OS (Windows / Mac) | Yes |
| Browser | OS | Yes |
| Hadoop JVM | `$JAVA_HOME/lib/security/cacerts` | No — manual |
| curl (Linux) | `/etc/ssl/certs` | Depends on OS |

> **Absence of GKE pod logs is confirmation the failure is at the TLS layer — not the application.**

---

## 4. Why UAT Works but PRD Fails

Both are separate environments — separate Hadoop nodes, separate GKE clusters.

```
UAT:  UAT-Hadoop  -->  UAT-GKE   (works)
PRD:  PRD-Hadoop  -->  PRD-GKE   (fails)
```

Common differences between UAT and PRD that cause this:

| Difference | UAT | PRD | Error |
|-----------|-----|-----|-------|
| Certificate CA | Known CA in cacerts | New/different CA, not imported | PKIX error |
| Cert chain served | Full chain (3 certs) | Leaf cert only | PKIX error |
| Java version | Java 11 / newer | Java 8 pre-u261 | handshake_failure |
| Istio TLS version | `TLS_AUTO` (1.2+) | `TLSV1_3` only | handshake_failure |
| PeerAuthentication | `PERMISSIVE` | `STRICT` (mTLS) | certificate_unknown |
| Cert renewal | Old cert, known CA | Renewed with new CA | PKIX error |

---

## 5. Where CA Validation Happens

**CA validation runs entirely inside Hadoop JVM. Istio is not involved.**

```
Hadoop JVM                      Istio Ingress Gateway
    |                                   |
    |-- ClientHello ------------------> |
    |<- ServerHello + Certificate ------ |
    |                                   |
    |  Certificate received by JVM      |
    |  Step 1: Read cert issuer field   |
    |  Step 2: Search own cacerts file  |
    |  Step 3: Build trust chain        |
    |  Step 4: Verify signatures        |
    |  Step 5: Check hostname vs SAN    |
    |                                   |
    |  All of this is LOCAL in JVM      |
    |  Istio has ZERO visibility here   |
    |                                   |
    |  If FAILS:                        |
    |  SSLHandshakeException thrown     |
    |-- alert_fatal ------------------> |
    |   (just a TCP close signal)       |
    |   Istio does NOT know why         |
```

Istio only receives a connection close. It does not know if the failure was a missing CA, wrong cipher, or expired cert. **Hadoop JVM logs are the only place that has the full reason.**

---

## 6. Where to Find Logs

### Log Locations — Who Sees What

| Location | Hadoop fails | Postman succeeds | Has the reason? |
|----------|-------------|------------------|-----------------|
| **Hadoop JVM logs** | Full detail — cert chain, issuer, exact error | Connection OK | YES — debug here first |
| **Istio Ingress Gateway pod** | Minimal — `DC` flag, TLS error, no reason | Access log, 200 | Confirms failure, not cause |
| **App pod istio-proxy sidecar** | Empty — never reached | Access log entry | Not relevant |
| **App pod container** | Empty — never reached | Request processed | Not relevant |

### Hadoop JVM — Primary Debug Target

```cmd
:: Enable verbose TLS logging
set HADOOP_OPTS=-Djavax.net.debug=ssl:handshake:verbose
```

For `fatal handshake_failure` you will see:
```
*** ClientHello, TLSv1.2
Cipher Suites: [TLS_RSA_WITH_AES_128_CBC_SHA, ...]

*** Alert: fatal, handshake_failure
No cipher suites in common
```

For `PKIX path building failed` you will see:
```
*** ClientHello, TLSv1.2
*** ServerHello, TLSv1.2

*** Certificate chain
chain [0] = [
  Subject: CN=prd-service.domain.com
  Issuer:  CN=PRD-IntermediateCA
]
chain [1] = [
  Subject: CN=PRD-IntermediateCA
  Issuer:  CN=PRD-RootCA        <- JVM searches cacerts for this
]

PKIX path building failed:
unable to find valid certification path to trusted root
                          ^
              CN=PRD-RootCA not found in cacerts
              This is exactly what you need to import

Alert: fatal, description = certificate_unknown
```

### Istio Ingress Gateway — Secondary Confirmation

```bash
# Find ingress gateway pod in your dedicated namespace
kubectl get pods -n <your-istio-ingress-namespace>

# Check logs for TLS errors
kubectl logs -n <your-istio-ingress-namespace> \
  -l app=istio-ingressgateway \
  | grep -i "tls\|ssl\|certificate\|handshake\|alert\|DC"

# Increase log verbosity
istioctl proxy-config log <ingress-gateway-pod> \
  -n <your-istio-ingress-namespace> \
  --level tls:debug,connection:debug

# Reset after debugging
istioctl proxy-config log <ingress-gateway-pod> \
  -n <your-istio-ingress-namespace> \
  --level warning
```

You will see:
```
TLS error: CERTIFICATE_VERIFY_FAILED
response_flags: DC        <- downstream connection terminated
transport failure reason: TLS error
```

> Istio logs confirm the drop but not the reason. Always use Hadoop JVM logs as primary.

---

## 7. Root Cause Scenarios

| # | Error Seen | Scenario | Fix |
|---|-----------|----------|-----|
| A | `PKIX path building failed` | PRD cert signed by different CA not in Hadoop `cacerts` | Import PRD CA into JDK `cacerts` |
| B | `PKIX path building failed` | Istio TLS secret has only leaf cert — intermediate CA missing | Update Istio secret with `fullchain.pem` |
| C | `PKIX path building failed` | PRD cert recently renewed with new CA chain | Import new CA into `cacerts` |
| D | `certificate_unknown` | PRD Istio `PeerAuthentication = STRICT`, Hadoop not sending client cert | Add client cert to Hadoop or set `PERMISSIVE` |
| E | `fatal handshake_failure` | Old Java on PRD Hadoop (pre Java 8 u261), Istio requires TLS 1.3 | Upgrade Java or force TLS 1.2 |
| F | `fatal handshake_failure` | PRD Istio `minProtocolVersion: TLSV1_3`, UAT is `TLS_AUTO` | Set `minProtocolVersion: TLSV1_2` in Gateway |
| G | `fatal handshake_failure` | No cipher suite overlap between old Java and Istio | Add older ciphers to Istio Gateway config |

---

## 8. Decision Tree — How to Diagnose

> Run all commands from the **PRD Hadoop node** (Windows CMD)

```
STEP 1 — Is port 443 reachable?
telnet prd-gke-host 443

        |
   FAIL |  OK
    |   |   |
    v       |
Firewall    |
blocked.    |
Open port   |
443.        |
            v
STEP 2 — Does openssl trust the cert?
openssl s_client -connect prd-gke-host:443
Check: "Verify return code" in output

            |
     19     |   20/21         0
      |      |    |            |
      v           v            |
Self-signed  Chain broken  openssl trusts it
not trusted  or CA missing BUT Java may still
Fix: import  from OS       fail — openssl uses
into cacerts              OS truststore, Java
+ fix Istio               uses its OWN cacerts
                               |
                               v
STEP 3 — How many certs in chain?
openssl s_client -connect prd-gke-host:443
-showcerts 2>nul | find /c "BEGIN CERTIFICATE"

            1                  2 or 3
            |                    |
            v                    |
Istio serving               Chain OK from
leaf cert only.             network side.
Fix: update                 Move to Step 4.
Istio secret                     |
with fullchain.pem               |
                                 v
STEP 4 — Is PRD CA in Java cacerts?
Get issuer: openssl s_client -connect prd-gke-host:443
            2>nul | openssl x509 -noout -issuer

Search:     keytool -list -v
              -keystore "%JAVA_HOME%\lib\security\cacerts"
              -storepass changeit
              | find /i "<issuer-name>"

        FOUND              NOT FOUND
          |                    |
          v                    v
    CA is trusted.      CA missing.
    Go to Step 5.       Fix: keytool -import
                             -alias prd-ca
                             -file prd-ca.crt
                             -storepass changeit

          |
          v
STEP 5 — Enable Hadoop JVM TLS debug
set HADOOP_OPTS=-Djavax.net.debug=ssl:handshake:verbose
Restart Hadoop and check logs.

  "No cipher suites in common"  -> fatal handshake_failure -> Step 6
  "PKIX path building failed"   -> CA still missing        -> re-import
  "certificate_unknown"         -> mTLS STRICT issue       -> Step 7

          |
          v
STEP 6 — Cipher / TLS version issue?
Check Java version:
java -version
(Java 8 below u261 = no TLS 1.3 support)

Test versions:
openssl s_client -connect prd-gke-host:443 -tls1_2
openssl s_client -connect prd-gke-host:443 -tls1_3

  TLS 1.2 works, 1.3 fails -> Java too old, force TLS 1.2
  TLS 1.2 fails, 1.3 works -> PRD Istio rejecting 1.2
  Both fail                 -> cipher mismatch

Check Istio Gateway TLS config:
kubectl get gateway -n <namespace> -o yaml | grep -A5 "tls:"

          |
          v
STEP 7 — Check Istio mTLS policy
kubectl get peerauthentication -A

  PERMISSIVE -> no client cert needed
  STRICT     -> Hadoop must send client cert
  PRD=STRICT and UAT=PERMISSIVE -> this is the difference
```

---

## 9. Troubleshooting Commands

> Windows CMD unless marked `bash`.

### TCP Connectivity

```cmd
telnet prd-gke-host 443
curl -v https://prd-gke-host:443
```

### Certificate Chain

```cmd
:: Full cert chain
openssl s_client -connect prd-gke-host:443 -showcerts

:: Count certs (must be 3)
openssl s_client -connect prd-gke-host:443 -showcerts 2>nul | find /c "BEGIN CERTIFICATE"

:: Verify return code
openssl s_client -connect prd-gke-host:443 2>&1 | find "Verify return"

:: Cert expiry
openssl s_client -connect prd-gke-host:443 2>nul | openssl x509 -noout -dates

:: TLS protocol version
openssl s_client -connect prd-gke-host:443 2>&1 | find "Protocol"

:: Cipher negotiated
openssl s_client -connect prd-gke-host:443 2>&1 | find "Cipher is"

:: Test TLS 1.2 specifically
openssl s_client -connect prd-gke-host:443 -tls1_2

:: Test TLS 1.3 specifically
openssl s_client -connect prd-gke-host:443 -tls1_3
```

### Compare UAT vs PRD — Save as compare.bat

```cmd
@echo off
echo ===== UAT ISSUER =====
openssl s_client -connect uat-gke-host:443 2>nul | openssl x509 -noout -issuer
echo.
echo ===== PRD ISSUER =====
openssl s_client -connect prd-gke-host:443 2>nul | openssl x509 -noout -issuer
echo.
echo ===== UAT CHAIN DEPTH =====
openssl s_client -connect uat-gke-host:443 -showcerts 2>nul | find /c "BEGIN CERTIFICATE"
echo.
echo ===== PRD CHAIN DEPTH =====
openssl s_client -connect prd-gke-host:443 -showcerts 2>nul | find /c "BEGIN CERTIFICATE"
echo.
echo ===== UAT VERIFY CODE =====
openssl s_client -connect uat-gke-host:443 2>&1 | find "Verify return"
echo.
echo ===== PRD VERIFY CODE =====
openssl s_client -connect prd-gke-host:443 2>&1 | find "Verify return"
echo.
echo ===== UAT TLS VERSION =====
openssl s_client -connect uat-gke-host:443 2>&1 | find "Protocol"
echo.
echo ===== PRD TLS VERSION =====
openssl s_client -connect prd-gke-host:443 2>&1 | find "Protocol"
```

### JDK Truststore

```cmd
:: Find JAVA_HOME and version
echo %JAVA_HOME%
java -version

:: List all certs
keytool -list -v -keystore "%JAVA_HOME%\lib\security\cacerts" -storepass changeit

:: Search for specific CA
keytool -list -v -keystore "%JAVA_HOME%\lib\security\cacerts" ^
  -storepass changeit | find /i "YourCAName"

:: Count total certs (compare UAT vs PRD — should be same)
keytool -list -keystore "%JAVA_HOME%\lib\security\cacerts" ^
  -storepass changeit | find /c "trustedCertEntry"
```

### Hadoop JVM TLS Debug

```cmd
:: Handshake steps only
set HADOOP_OPTS=-Djavax.net.debug=ssl:handshake

:: Verbose — includes cert chain detail
set HADOOP_OPTS=-Djavax.net.debug=ssl:handshake:verbose

:: Everything (very noisy)
set HADOOP_OPTS=-Djavax.net.debug=all
```

### Istio Ingress Gateway (bash)

```bash
# Find ingress gateway pod
kubectl get pods -n <your-istio-ingress-namespace>

# Check logs
kubectl logs -n <your-istio-ingress-namespace> \
  -l app=istio-ingressgateway \
  | grep -i "tls\|ssl\|certificate\|handshake\|alert\|DC"

# Increase log verbosity
istioctl proxy-config log <ingress-gateway-pod> \
  -n <your-istio-ingress-namespace> \
  --level tls:debug,connection:debug

# Check Gateway TLS config
kubectl get gateway -n <namespace> -o yaml | grep -A10 "tls:"

# Check PeerAuthentication
kubectl get peerauthentication -A

# Reset log level
istioctl proxy-config log <ingress-gateway-pod> \
  -n <your-istio-ingress-namespace> \
  --level warning
```

---

## 10. Fix Commands

### Fix A — Import Missing CA into Hadoop JDK cacerts

```cmd
:: Step 1: Export CA cert from PRD Istio
openssl s_client -connect prd-gke-host:443 -showcerts 2>nul > chain.txt
:: Open chain.txt, extract ROOT CA (last BEGIN/END CERTIFICATE block)
:: Save it as prd-root-ca.crt

:: Step 2: Import (run as Administrator)
keytool -import -trustcacerts ^
  -alias prd-root-ca ^
  -file prd-root-ca.crt ^
  -keystore "%JAVA_HOME%\lib\security\cacerts" ^
  -storepass changeit

:: Step 3: Verify
keytool -list -v ^
  -keystore "%JAVA_HOME%\lib\security\cacerts" ^
  -storepass changeit | find /i "prd-root-ca"

:: Step 4: Restart Hadoop service
```

### Fix B — Update Istio TLS Secret with Full Chain

```bash
# Concatenate leaf + intermediate into fullchain
cat leaf.crt intermediate.crt > fullchain.pem

# Update Istio TLS secret
kubectl create secret tls prd-tls-secret \
  --cert=fullchain.pem \
  --key=private.key \
  -n istio-system \
  --dry-run=client -o yaml | kubectl apply -f -

# Verify — must return 3
openssl s_client -connect prd-gke-host:443 -showcerts 2>/dev/null \
  | grep -c "BEGIN CERTIFICATE"
```

### Fix C — Force TLS 1.2 on Hadoop JVM

```cmd
set HADOOP_OPTS=-Dhttps.protocols=TLSv1.2 -Djdk.tls.client.protocols=TLSv1.2
```

Or in `hadoop-env.sh`:
```bash
export HADOOP_OPTS="-Dhttps.protocols=TLSv1.2 -Djdk.tls.client.protocols=TLSv1.2"
```

### Fix D — Relax PRD Istio Minimum TLS Version

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: prd-gateway
  namespace: <your-istio-ingress-namespace>
spec:
  servers:
  - port:
      number: 443
      protocol: HTTPS
    tls:
      mode: SIMPLE
      minProtocolVersion: TLSV1_2    # was TLSV1_3
      credentialName: prd-tls-secret
```

### Fix E — Add Older Cipher Suites to Istio Gateway

```yaml
spec:
  servers:
  - tls:
      mode: SIMPLE
      minProtocolVersion: TLSV1_2
      cipherSuites:
        - ECDHE-RSA-AES256-GCM-SHA384
        - ECDHE-RSA-AES128-GCM-SHA256
        - AES256-GCM-SHA384
        - AES128-GCM-SHA256
```

### Fix F — Relax PRD Istio mTLS to Permissive

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: <your-istio-ingress-namespace>
spec:
  mtls:
    mode: PERMISSIVE    # was STRICT
```

---

## 11. Error Code Reference

### TLS Alert Codes

| Error | Alert Code | Cert Exchanged? | Meaning | Fix |
|-------|------------|-----------------|---------|-----|
| `fatal handshake_failure` | 40 | NO — fails before cert | No common TLS version or cipher | Upgrade Java or relax Istio min TLS version |
| `PKIX path building failed` | 46 certificate_unknown | YES — cert received, rejected | CA not in JDK `cacerts` or chain incomplete | Import CA into `cacerts` or fix Istio chain |
| `certificate_unknown` | 46 | YES | mTLS STRICT — Hadoop not sending client cert | Add client cert or set `PERMISSIVE` |
| `certificate has expired` | 45 | YES | PRD cert expired | Renew cert in Istio secret |
| `self-signed certificate` | 18 | YES | Self-signed not in truststore | Import into `cacerts` |
| `Connection refused` | — | Never starts | Firewall blocking port 443 | Open firewall |
| `Connection timed out` | — | Never starts | No route to host | Check network routing |

### Verify Return Code (openssl s_client)

| Code | Meaning | Action |
|------|---------|--------|
| `0` | openssl trusts the cert (OS level) | Still check Java `cacerts` separately — they are independent |
| `10` | Certificate expired | Renew cert in Istio |
| `19` | Self-signed cert | Import into `cacerts` + fix Istio cert |
| `20` | CA not in OS truststore | Check chain depth — Step 3 |
| `21` | Cannot verify first cert — incomplete chain | Fix Istio secret with `fullchain.pem` |

> **Critical:** `Verify return code: 0` from openssl does **NOT** mean Java will succeed.
> openssl uses the OS truststore. Java uses `$JAVA_HOME/lib/security/cacerts`.
> They are completely independent.
> A `Verify return code: 0` with Java still failing means the CA is in the OS store but **not** in JDK `cacerts`.
