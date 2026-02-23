sequenceDiagram
    participant Dev as Developer
    participant AppRepo as App Monorepo (Main)
    participant CI as CI/CD
    participant DepRepo as Deployment Repo
    participant BaseDev as Baseline Dev
    participant Dev1 as dev1 (Isolated WLTS via Flags)
    participant Uat1 as uat1 (Isolated WLTS via Flags)
    participant BaseUat as Baseline UAT
    participant Prl1 as prl1
    participant Prd as prd

    Note over AppRepo: Pre-Hotfix: WLTS Exists on Main (Flags Off by Default)
    Note over Dev1: WLTS Pushed to dev1 (Flags: On)
    Note over Uat1: WLTS Pushed to uat1 (Flags: On)

    Note over AppRepo: Hotfix Flow Starts (All Flows from Main)
    Dev->>AppRepo: Hotfix PR to Main
    AppRepo->>CI: Trigger Pre-Merge
    CI->>CI: Gate: Unit/Lint/SAST/SCA/Build Verify (Pass)
    CI->>AppRepo: Merge Hotfix to Main
    AppRepo->>CI: Build v1.0.1
    CI->>CI: Gate: Build Integrity/Scan/SBOM/Sign (Pass)
    CI->>BaseDev: Deploy v1.0.1 to Baseline Dev
    BaseDev->>CI: Gate: Smoke/Health (Pass)
    CI->>DepRepo: Update Base Config (values.yaml)
    DepRepo->>BaseUat: Deploy v1.0.1
    BaseUat->>CI: Gate: Smoke/Regression/Perf/Health (Pass)
    CI->>CI: Gate: Observability Soak (Metrics/SLO Green)
    CI->>CI: Gate: Rollback Readiness (Prev Image/DB Reversible)
    CI->>CI: Gate: Manual Approval (If High-Risk)
    CI->>DepRepo: Promote to prl1 Config
    DepRepo->>Prl1: Deploy v1.0.1
    Prl1->>CI: Gate: Full E2E/Load/DAST/Chaos (Pass)
    CI->>CI: Gate: Observability Soak (Pass)
    CI->>CI: Gate: Manual Approval (Release Mgr)
    CI->>DepRepo: Promote to prd Config
    DepRepo->>Prd: Deploy v1.0.1
    Prd->>CI: Gate: Canary 1%→10%→50%→100% (SLO per Stage/Auto-Rollback)
    Prd->>CI: Gate: Post-Deploy Monitor (30 min)

    Note over Dev: Adding to WLTS Integration When Ready (Via Flags on Main, Auto-Deploy from Main)
    Dev->>AppRepo: WLTS PR to Main (Rebase on Hotfix)
    AppRepo->>CI: Trigger Pre-Merge
    CI->>CI: Gate: Unit/Lint/SAST/Flag Matrix On/Off (Pass)
    CI->>AppRepo: Merge WLTS to Main
    AppRepo->>CI: Build v1.1.0
    CI->>CI: Gate: Build Integrity/Scan/SBOM/Sign (Pass)
    CI->>Dev1: Deploy v1.1.0 to dev1 (Flags: WLTS On)
    Dev1->>CI: Gate: Combo Functional/Hotfix Preserve (Flags On/Off)
    CI->>Uat1: Deploy v1.1.0 to uat1 (Flags: WLTS On)
    Uat1->>CI: Gate: Integration/E2E/Perf/Exploratory (Pass)
    CI->>CI: Gate: Manual Sign-Off (If Needed)
    CI->>DepRepo: Update Base Config (Flags: Off)
    DepRepo->>BaseUat: Deploy v1.1.0 (Hidden/Dark)
    BaseUat->>CI: Gate: Full Regression/Integration/DB Migration (Pass)
    CI->>CI: Gate: Observability Soak (Pass)
    CI->>CI: Gate: Rollback Readiness (Pass)
    CI->>CI: Gate: Manual Approval (2 Approvers)
    CI->>DepRepo: Promote to prl1 Config (Flags: Off)
    DepRepo->>Prl1: Deploy v1.1.0
    Prl1->>CI: Gate: Toggle Sequence (Off→On) + Load/Security (Pass)
    CI->>CI: Gate: Observability Soak 30 min (Pass)
    CI->>CI: Gate: Manual Go/No-Go (Checklist)
    CI->>DepRepo: Promote to prd Config (Flags: Off)
    DepRepo->>Prd: Deploy v1.1.0 (Dark)
    Prd->>CI: Gate: Deployment Health/Baseline SLO (Pass)
    CI->>DepRepo: Gradual Flag On (1%→10%→50%→100%)
    Prd->>CI: Gate: SLO per Stage (p99/Errors/Biz Metrics/Auto-Revert)
    Prd->>CI: Gate: Post-Deploy Monitor 1 hr (Full On)
