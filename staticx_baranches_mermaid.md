---
title: Static Environment Branches Strategy
---
flowchart LR
    subgraph Track1[Track 1]
        direction LR
        DEV1[DEV1] --> UAT1[UAT1]
    end

    subgraph Track2[Track 2]
        direction LR
        DEV2[DEV2] --> UAT2[UAT2]
    end

    subgraph Integration
        direction LR
        DEV[DEV] --> UAT[UAT]
    end

    subgraph Prod[Production]
        direction TB
        PRD[PRD]
        PRL1[PRL1]
    end

    %% Connect tracks to integration
    UAT1 --> DEV
    UAT2 --> DEV

    %% Integration to Production
    UAT --> PRD
    UAT --> PRL1

    %% Hotfix positioned below
    HF[🔥 HOTFIX]
    Track2 ~~~ HF
    HF -->|Direct Push| DEV

    %% Sync Back - Causes Conflicts
    DEV -.->|⚠️ Sync Back<br/>CONFLICTS| DEV1
    DEV -.->|⚠️ Sync Back<br/>CONFLICTS| DEV2

    %% Styling
    classDef devBranch fill:#4a90d9,stroke:#2c5282,color:white
    classDef uatBranch fill:#48bb78,stroke:#276749,color:white
    classDef prodBranch fill:#ed8936,stroke:#c05621,color:white
    classDef integration fill:#9f7aea,stroke:#6b46c1,color:white
    classDef hotfix fill:#fc8181,stroke:#c53030,color:white

    class DEV1,DEV2 devBranch
    class UAT1,UAT2 uatBranch
    class PRD,PRL1 prodBranch
    class DEV,UAT integration
    class HF hotfix
