# TLS Handshake Troubleshooting — Hadoop → GKE Istio

> **Context:** Hadoop JVM client failing TLS handshake to GKE Istio Ingress Gateway in PRD.  
> UAT works. PRD throws `javax.net.ssl.SSLHandshakeException: PKIX path building failed`.

---

## Table of Contents

- [TLS Handshake Sequence](#tls-handshake-sequence)
  - [UAT — Success Flow](#uat--success-flow)
  - [PRD — Failure Flow](#prd--failure-flow)
- [Why UAT Works but PRD Fails](#why-uat-works-but-prd-fails)
- [Root Cause Scenarios](#root-cause-scenarios)
- [Troubleshooting Commands](#troubleshooting-commands)
  - [Step 1 — Verify TCP Connectivity](#step-1--verify-tcp-connectivity)
  - [Step 2 — Check Certificate Chain](#step-2--check-certificate-chain)
  - [Step 3 — Compare UAT vs PRD](#step-3--compare-uat-vs-prd)
  - [Step 4 — Check JDK Truststore](#step-4--check-jdk-truststore)
  - [Step 5 — Enable Verbose TLS Logs](#step-5--enable-verbose-tls-logs)
  - [Step 6 — Check Istio mTLS Policy](#step-6--check-istio-mtls-policy)
- [Fix Commands](#fix-commands)
- [Error Code Reference](#error-code-reference)
- [Where CA Validation Happens and Where to Find Logs](#where-ca-validation-happens-and-where-to-find-logs)

---

## TLS Handshake Sequence

### Pre-requisite — TCP Handshake (Firewall Layer)

Before TLS begins, a TCP connection must be established. **Firewall must allow port 443** between Hadoop and GKE Ingress IP.

```
Hadoop JVM                    Istio Gateway
    │                               │
    │──── TCP SYN ────────────────► │   ← Firewall must allow this
    │◄─── TCP SYN-ACK ─────────────│
    │──── TCP ACK ────────────────► │
    │                               │
    │   TCP established ✅           │
    │   TLS handshake starts now    │
```

> If firewall is **blocked** → `Connection refused` or `Connection timed out` — never reaches TLS.  
> If firewall is **open** but TLS fails → problem is inside the TLS layer (cert/trust issue).

---

### UAT — Success Flow

```
Hadoop JVM                    Istio Gateway              GKE Pod
    │                               │                       │
    │─── 1. ClientHello ──────────► │                       │
    │    (TLS version, ciphers,     │                       │
    │     cipher suites, SNI)       │                       │
    │                               │                       │
    │◄── 2. ServerHello ────────────│                       │
    │    (chosen cipher, TLS ver,   │                       │
    │     server random)            │                       │
    │                               │                       │
    │◄── 3. Certificate ────────────│                       │
    │    (Leaf + IntermCA + RootCA) │                       │
    │    [3 certs in chain] ✅       │                       │
    │                               │                       │
    │◄── 4. ServerHelloDone ────────│                       │
    │                               │                       │
    │─── 5. [Internal Validation] ──│                       │
    │    RootCA found in cacerts ✅  │                       │
    │    Signature valid ✅          │                       │
    │    Hostname matches SAN ✅     │                       │
    │                               │                       │
    │─── 6. ClientKeyExchange ────► │                       │
    │    (pre-master secret         │                       │
    │     encrypted with server     │                       │
    │     public key)               │                       │
    │                               │                       │
    │─── 7. ChangeCipherSpec ─────► │                       │
    │◄── 7. ChangeCipherSpec ───────│                       │
    │    (both switch to session    │                       │
    │     keys derived from         │                       │
    │     pre-master secret)        │                       │
    │                               │                       │
    │─── 8. Finished ─────────────► │                       │
    │◄── 8. Finished ───────────────│                       │
    │    (handshake verified)       │                       │
    │                               │                       │
    │─── 9. HTTP Request ─────────► │──── Forward ────────► │
    │                               │    (TLS tunnel open)  │
    │                               │                       │
```

**Result:** `Verify return code: 0 (ok)` — Request reaches GKE pod ✅

---

### PRD — Failure Flow

```
Hadoop JVM                    Istio Gateway              GKE Pod
    │                               │                       │
    │─── 1. ClientHello ──────────► │                       │
    │                               │                       │
    │◄── 2. ServerHello ────────────│                       │
    │                               │                       │
    │◄── 3. Certificate ────────────│                       │
    │    ⚠ ONLY leaf cert           │                       │
    │    ⚠ OR cert from new CA      │                       │
    │    [1 cert, chain broken] ❌   │                       │
    │                               │                       │
    │◄── 4. ServerHelloDone ────────│                       │
    │                               │                       │
    │─── 5. [Internal Validation] ──│                       │
    │    Walks cert chain...        │                       │
    │    Looks for issuing CA       │                       │
    │    in JDK cacerts...          │                       │
    │    CA NOT FOUND ❌             │                       │
    │    Verify return code: 20 ❌   │                       │
    │                               │                       │
    │─── 6. alert_fatal ──────────► │                       │
    │    certificate_unknown (46)   │                       │
    │    OR handshake_failure (40)  │                       │
    │                               │                       │
    │   Connection closed ❌         │   Never reached ❌    │
    │                               │                       │
```

**Result:** `javax.net.ssl.SSLHandshakeException: PKIX path building failed` ❌

> GKE pod **never receives the request**. Failure happens entirely at the TLS layer.

---

## Why UAT Works but PRD Fails

Postman and OS tools use the **OS truststore** which is auto-updated.  
Java JVM uses its **own `cacerts` file** — completely separate from OS.

```
Postman  ──► OS truststore (auto-updated by Windows/Mac) ──► ✅ Trusts most CAs
Java JVM ──► JDK cacerts   (manually managed)            ──► ❌ May be missing PRD CA
```

| Component | Truststore Used | Auto-Updated? |
|-----------|----------------|---------------|
| Postman | OS (Windows/Mac) | ✅ Yes |
| Browser | OS | ✅ Yes |
| Java / Hadoop JVM | `$JAVA_HOME/lib/security/cacerts` | ❌ No — manual |
| curl (Linux) | `/etc/ssl/certs` | Depends on OS |

---

## Root Cause Scenarios

| # | Scenario | Symptom | Fix |
|---|----------|---------|-----|
| A | PRD cert signed by different/new CA not in Hadoop `cacerts` | `PKIX path building failed` | Import PRD CA into JDK `cacerts` |
| B | Istio TLS secret has only leaf cert — no intermediate CA | `Verify return: 20`, only 1 cert in chain | Update Istio secret with `fullchain.pem` |
| C | PRD Istio `PeerAuthentication = STRICT` (mTLS), UAT is `PERMISSIVE` | `certificate_unknown` alert | Add client cert to Hadoop OR relax PRD policy |
| D | PRD cert recently renewed with new CA chain | `PKIX` error only after renewal | Import new CA into `cacerts` |
| E | Old Java on PRD Hadoop — cipher/TLS version mismatch | `handshake_failure`, no common cipher | Upgrade Java or force TLS 1.2 |

---

## Troubleshooting Commands

> All commands below are for **Windows Command Prompt**.  
> Run Steps 1–4 from the **PRD Hadoop node**.

---

### Step 1 — Verify TCP Connectivity

```cmd
:: Basic connectivity — if this fails, firewall is not open
curl -v https://prd-gke-host:443

:: Telnet check on port 443
telnet prd-gke-host 443
```

---

### Step 2 — Check Certificate Chain

```cmd
:: See full certificate chain returned by PRD Istio
openssl s_client -connect prd-gke-host:443 -showcerts

:: Count how many certs in chain (should be 3: leaf + intermediate + root)
openssl s_client -connect prd-gke-host:443 -showcerts 2>nul | find /c "BEGIN CERTIFICATE"

:: Check verify return code
:: 0  = OK
:: 20 = unable to get local issuer cert  (CA missing)
:: 21 = unable to verify first cert      (chain incomplete)
:: 19 = self-signed cert
openssl s_client -connect prd-gke-host:443 2>&1 | find "Verify return"

:: Check cert expiry dates
openssl s_client -connect prd-gke-host:443 2>nul | openssl x509 -noout -dates

:: Check TLS protocol version negotiated
openssl s_client -connect prd-gke-host:443 2>&1 | find "Protocol"
```

---

### Step 3 — Compare UAT vs PRD

Run these side by side to find what is different:

```cmd
:: Compare issuer (CA that signed the cert)
openssl s_client -connect uat-gke-host:443 2>nul | openssl x509 -noout -issuer
openssl s_client -connect prd-gke-host:443 2>nul | openssl x509 -noout -issuer

:: Compare subject (the cert identity)
openssl s_client -connect uat-gke-host:443 2>nul | openssl x509 -noout -subject
openssl s_client -connect prd-gke-host:443 2>nul | openssl x509 -noout -subject

:: Compare chain depth
openssl s_client -connect uat-gke-host:443 -showcerts 2>nul | find /c "BEGIN CERTIFICATE"
openssl s_client -connect prd-gke-host:443 -showcerts 2>nul | find /c "BEGIN CERTIFICATE"

:: Compare verify return code
openssl s_client -connect uat-gke-host:443 2>&1 | find "Verify return"
openssl s_client -connect prd-gke-host:443 2>&1 | find "Verify return"

:: Compare TLS version
openssl s_client -connect uat-gke-host:443 2>&1 | find "Protocol"
openssl s_client -connect prd-gke-host:443 2>&1 | find "Protocol"
```

**Run all at once — save as `compare.bat`:**

```cmd
@echo off
echo ===== UAT CERT ISSUER =====
openssl s_client -connect uat-gke-host:443 2>nul | openssl x509 -noout -issuer
echo.
echo ===== PRD CERT ISSUER =====
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

---

### Step 4 — Check JDK Truststore

```cmd
:: Find JAVA_HOME on Hadoop
echo %JAVA_HOME%
java -version

:: List all certs in JDK cacerts
keytool -list -v -keystore "%JAVA_HOME%\lib\security\cacerts" -storepass changeit

:: Search for specific CA by name (replace YourCAName)
keytool -list -v -keystore "%JAVA_HOME%\lib\security\cacerts" -storepass changeit | find /i "YourCAName"

:: Count total trusted certs (compare UAT vs PRD Hadoop — should be same)
keytool -list -keystore "%JAVA_HOME%\lib\security\cacerts" -storepass changeit | find /c "trustedCertEntry"

:: Export PRD cert to file for inspection
openssl s_client -connect prd-gke-host:443 2>nul | openssl x509 -outform PEM -out prd-cert.pem
openssl x509 -in prd-cert.pem -noout -text
```

---

### Step 5 — Enable Verbose TLS Logs

Add to Hadoop JVM startup arguments to see every TLS step in logs:

```cmd
:: Minimal — just handshake steps
set HADOOP_OPTS=-Djavax.net.debug=ssl:handshake

:: Verbose — full TLS detail including cert chain
set HADOOP_OPTS=-Djavax.net.debug=ssl:handshake:verbose

:: Everything — use only for deep debugging (very noisy)
set HADOOP_OPTS=-Djavax.net.debug=all
```

Or add directly to the Java process:

```cmd
java -Djavax.net.debug=ssl:handshake:verbose -jar your-app.jar
```

Key things to look for in output:

```
%% No cached client session        ← new TLS session starting
*** ClientHello                    ← Step 1
*** ServerHello                    ← Step 2
*** Certificate chain              ← Step 3 — check how many certs listed
*** PKIX path building failed      ← Step 5 — CA not found
```

---

### Step 6 — Check Istio mTLS Policy

Run from any machine with `kubectl` access to PRD cluster:

```cmd
:: Check PeerAuthentication mode (PERMISSIVE vs STRICT)
kubectl get peerauthentication -A

:: Detailed view
kubectl describe peerauthentication -A

:: Check what cert Istio is serving from its TLS secret
kubectl get secret -n istio-system
kubectl get secret your-tls-secret -n istio-system -o jsonpath="{.data.tls\.crt}" > encoded.txt
certutil -decode encoded.txt decoded.crt
openssl x509 -in decoded.crt -noout -issuer -subject -dates

:: Check Istio Gateway TLS mode (SIMPLE vs MUTUAL)
kubectl get gateway -A -o yaml | findstr /i "mode tls"
```

---

## Fix Commands

### Fix A — Import Missing CA into Hadoop JDK cacerts

```cmd
:: Get the CA cert from PRD Istio
openssl s_client -connect prd-gke-host:443 -showcerts 2>nul > chain.txt
:: Manually extract the ROOT CA cert (last BEGIN/END CERTIFICATE block) into prd-root-ca.crt

:: Import into JDK cacerts (run as Administrator)
keytool -import -trustcacerts ^
  -alias prd-root-ca ^
  -file prd-root-ca.crt ^
  -keystore "%JAVA_HOME%\lib\security\cacerts" ^
  -storepass changeit

:: Verify it was imported
keytool -list -v ^
  -keystore "%JAVA_HOME%\lib\security\cacerts" ^
  -storepass changeit | find /i "prd-root-ca"

:: Restart Hadoop service after importing
```

### Fix B — Update Istio TLS Secret with Full Chain

```bash
# On GKE cluster — update the Istio ingress TLS secret
# fullchain.pem must contain: leaf cert + intermediate CA (concatenated)
cat leaf.crt intermediate.crt > fullchain.pem

kubectl create secret tls prd-tls-secret \
  --cert=fullchain.pem \
  --key=private.key \
  -n istio-system \
  --dry-run=client -o yaml | kubectl apply -f -

# Verify chain depth after update
openssl s_client -connect prd-gke-host:443 -showcerts 2>/dev/null | grep -c "BEGIN CERTIFICATE"
# Must return 3
```

### Fix C — Force TLS 1.2 on Hadoop JVM (cipher mismatch)

```cmd
:: Add to Hadoop JVM args
set HADOOP_OPTS=-Dhttps.protocols=TLSv1.2 -Djdk.tls.client.protocols=TLSv1.2
```

---

## Error Code Reference

| Error | Verify Code | Meaning | Fix |
|-------|-------------|---------|-----|
| `PKIX path building failed` | 20 or 21 | CA not in `cacerts` or chain incomplete | Import CA or fix Istio chain |
| `certificate_unknown` | — | Istio rejecting — mTLS STRICT, no client cert | Add client cert or set PERMISSIVE |
| `handshake_failure` | — | No common cipher or TLS version | Upgrade Java or force TLS 1.2 |
| `certificate has expired` | 10 | PRD cert expired | Renew cert in Istio |
| `self-signed certificate` | 19 | Self-signed not trusted | Import self-signed into `cacerts` |
| `Connection refused` | — | TCP blocked — firewall not open | Open firewall port 443 |
| `Connection timed out` | — | No route to host | Check network routing |

---

## Quick Decision Tree

> Run all commands from the **PRD Hadoop node**

```
STEP 1 — Is the port reachable?
────────────────────────────────
telnet prd-gke-host 443

        │
   ┌────┴──────────────┐
  FAIL                 OK
   │                    │
   ▼                    │
Firewall not open.      │
Port 443 blocked.       │
Fix: open firewall      │
between Hadoop IP       │
and GKE Ingress IP.     │
                        │
                        ▼
              STEP 2 — What does openssl see?
              ─────────────────────────────────
              openssl s_client -connect prd-gke-host:443
              Check "Verify return code" in output

                        │
        ┌───────────────┼───────────────┐
       19               20 / 21          0
        │               │               │
        ▼               ▼               │
  Self-signed      Chain broken    openssl TRUSTS it
  cert. Not in     or CA missing   ⚠ BUT Java may still
  OS truststore.   from OS.        fail — openssl uses OS
  Fix: import                      truststore, Java uses
  into cacerts                     its OWN cacerts
  AND fix Istio                         │
  to serve proper                       │
  CA-signed cert                        ▼
        │               │        STEP 3 — Count cert chain depth
        │               │        ──────────────────────────────────
        │               │        openssl s_client -connect prd-gke-host:443
        │               │        -showcerts 2>nul | find /c "BEGIN CERTIFICATE"
        │               │
        │               │                  │
        │               │         ┌────────┴────────┐
        │               │         1                 2 or 3
        │               │         │                 │
        │               │         ▼                 ▼
        │               │    Istio secret      Chain looks OK
        │               │    has ONLY          from network side.
        │               │    leaf cert.        Java cacerts is
        │               │    Fix: update       the problem.
        │               │    Istio secret           │
        │               │    with fullchain.pem      │
        │               │                           │
        └───────────────┴──────────────────────────►│
                                                    │
                                                    ▼
                                   STEP 4 — Is PRD CA in Java cacerts?
                                   ────────────────────────────────────
                                   First get the issuer from PRD cert:
                                   openssl s_client -connect prd-gke-host:443
                                   2>nul | openssl x509 -noout -issuer

                                   Then search for it in cacerts:
                                   keytool -list -v
                                     -keystore "%JAVA_HOME%\lib\security\cacerts"
                                     -storepass changeit
                                     | find /i "issuer-name-from-above"

                                              │
                                   ┌──────────┴──────────┐
                                 FOUND                NOT FOUND
                                   │                     │
                                   ▼                     ▼
                             CA is trusted.        CA missing.
                             Go to Step 5          Fix: import CA
                             for deeper            keytool -import
                             Java debugging        -alias prd-ca
                                                   -file prd-ca.crt
                                                   -keystore cacerts
                                                   -storepass changeit

                                   │
                                   ▼
                        STEP 5 — Enable Java TLS debug logs
                        ────────────────────────────────────
                        set HADOOP_OPTS=-Djavax.net.debug=ssl:handshake:verbose
                        Restart Hadoop and check logs.

                        Look for:
                          *** ClientHello          → Step 1 OK
                          *** ServerHello          → Step 2 OK
                          *** Certificate chain    → check certs listed
                          *** PKIX path building   → CA not found in cacerts
                          *** handshake_failure    → cipher/TLS version mismatch

                                   │
                                   ▼
                        STEP 6 — Check Istio mTLS policy
                        ─────────────────────────────────
                        kubectl get peerauthentication -A

                          PERMISSIVE → one-way TLS, no client cert needed
                          STRICT     → mTLS, Hadoop must present client cert

                        If PRD = STRICT and UAT = PERMISSIVE:
                        Fix: add client cert to Hadoop
                             OR set PRD to PERMISSIVE
```

---

## Verify Return Code Reference

| Code | Meaning | Action |
|------|---------|--------|
| `0`  | openssl trusts the cert (OS level) | Check Java cacerts separately — Step 4 |
| `19` | Self-signed cert | Import into cacerts + fix Istio cert |
| `20` | CA not in OS truststore / chain broken | Check chain depth — Step 3 |
| `21` | Can't verify first cert — incomplete chain | Fix Istio secret with fullchain.pem |
| `10` | Certificate expired | Renew cert in Istio secret |

> ⚠ `Verify return code: 0` from openssl **does NOT mean Java will succeed**.  
> openssl uses the OS truststore. Java uses `$JAVA_HOME/lib/security/cacerts`.  
> They are completely independent. Always check both.

---

## Where CA Validation Happens and Where to Find Logs

### CA Validation Runs Entirely Inside Hadoop JVM

This is the most important thing to understand about TLS handshake failures.

```
Hadoop JVM                         Istio Ingress Gateway
    │                                       │
    │─── ClientHello ──────────────────────►│
    │◄── ServerHello + Certificate ─────────│
    │                                       │
    │  Certificate lands HERE in JVM        │
    │  ─────────────────────────────        │
    │  1. Read cert issuer field            │
    │  2. Search own cacerts file           │
    │  3. Build trust chain                 │
    │  4. Verify signatures                 │
    │  5. Check hostname vs SAN             │
    │                                       │
    │  ALL of this is LOCAL inside JVM      │
    │  Istio has NO visibility into this    │
    │                                       │
    │  FAILS ❌                              │
    │  SSLHandshakeException thrown         │
    │                                       │
    │─── alert_fatal ──────────────────────►│
    │   (just a TCP close signal)           │
    │   Istio does not know WHY             │
```

Istio only receives a connection close signal at the end. It has no idea the cert was rejected or why.

---

### Log Asymmetry — Hadoop vs Istio vs App Pod

| Location | Hadoop Failure | Postman Success | Has the reason? |
|----------|---------------|-----------------|-----------------|
| **Hadoop JVM logs** | ✅ Full detail — cert chain, issuer, exact CA missing, stack trace | ✅ Connection OK | ✅ YES — debug here |
| **Istio Ingress Gateway pod logs** | ⚠ Minimal — just sees connection closed, `DC` flag, TLS error | ✅ Access log entry with 200 | ❌ No reason why |
| **App pod `istio-proxy` sidecar** | ❌ Empty — never reached | ✅ Access log entry | ❌ Not relevant |
| **App pod container logs** | ❌ Empty — never reached | ✅ Request processed | ❌ Not relevant |

---

### Why Postman Shows a Log in GKE but Hadoop Does Not

```
Postman                    Istio Ingress              App Pod
    │                           │                        │
    │── TLS Handshake ─────────►│                        │
    │   OS trusts cert ✅        │                        │
    │── HTTP Request ──────────►│──── Forward ──────────►│
    │                           │                   ✅ Log entry
    │                           │                   written here

Hadoop                     Istio Ingress              App Pod
    │                           │                        │
    │── TLS Handshake ─────────►│                        │
    │   JVM rejects cert ❌      │                        │
    │── alert_fatal ───────────►│                        X
    │                           │                   ❌ Never reached
    │                           │                   No log entry
```

Postman completes TLS → request reaches app pod → log written.  
Hadoop fails TLS → connection closed at Istio → app pod never sees it.

**Absence of GKE pod logs is itself confirmation the failure is at TLS layer.**

---

### Where to Look for Logs — Dedicated Istio Ingress Namespace

Since you have a dedicated Istio Ingress Gateway in its own namespace, TLS termination happens there — not at the app pod sidecar.

```bash
# 1. Find ingress gateway pod
kubectl get pods -n <your-istio-ingress-namespace>

# 2. Check ingress gateway logs for TLS errors
kubectl logs -n <your-istio-ingress-namespace> \
  -l app=istio-ingressgateway \
  | grep -i "tls\|ssl\|certificate\|handshake\|alert\|reset\|DC"

# 3. Increase log level for more detail
istioctl proxy-config log \
  <ingress-gateway-pod> \
  -n <your-istio-ingress-namespace> \
  --level tls:debug,connection:debug

# 4. Reset after debugging
istioctl proxy-config log \
  <ingress-gateway-pod> \
  -n <your-istio-ingress-namespace> \
  --level warning
```

You will see in Istio logs:
```
TLS error: CERTIFICATE_VERIFY_FAILED
response_flags: DC     ← downstream connection terminated
transport failure reason: TLS error
```

---

### Primary Debug Target — Hadoop JVM Logs

Istio only confirms a drop. **Hadoop logs tell you exactly why.**

```cmd
:: Enable on Hadoop — add to JVM args
set HADOOP_OPTS=-Djavax.net.debug=ssl:handshake:verbose
```

You will see the full chain in Hadoop logs:

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
  Issuer:  CN=PRD-RootCA          ← JVM now searches cacerts for this
]

%% Invalidated session

PKIX path building failed:
unable to find valid certification path to trusted root
                              ↑
                    CN=PRD-RootCA not found in cacerts
                    This is exactly what to import

Alert: fatal, description = certificate_unknown
```

This tells you **exactly which CA is missing** — import that into `$JAVA_HOME/lib/security/cacerts` and the handshake will succeed.
