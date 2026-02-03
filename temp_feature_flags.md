---
title: Dynamic Feature Branches with Slot Assignment
---
flowchart TD
    subgraph SlotClaim["1️⃣ Slot Claim Process"]
        START([Start]) --> CREATE[Create Feature Branch<br/>from default branch]
        CREATE --> CLAIM[Run Claim Slot Workflow]
        CLAIM --> PR_SLOT[Workflow creates PR to update<br/>slot-assignment.yml in<br/>default branch]
        PR_SLOT --> APPROVE{Lead Approves PR?}
        APPROVE -->|No| FEEDBACK[Address Feedback]
        FEEDBACK --> PR_SLOT
        APPROVE -->|Yes| MERGE_SLOT[PR Merged to default branch]
        MERGE_SLOT --> ASSIGNED[🎰 Slot Assigned!]
    end

    subgraph IsolatedDev["2️⃣ Isolated Development"]
        ASSIGNED --> DEVELOP[Develop & Push Code<br/>to Feature Branch]
        DEVELOP --> CICD[CI/CD Pipeline Triggered]
        CICD --> BUILD[Builds Container Image<br/>Deploys to Isolated DEV]
        BUILD --> TEST_DEV[Tests run using<br/>dedicated Dataset & DAGs]
        TEST_DEV --> READY_UAT{Ready for<br/>Isolated UAT?}
        READY_UAT -->|No| DEVELOP
    end

    subgraph IsolatedUAT["3️⃣ Isolated UAT"]
        READY_UAT -->|Yes| TRIGGER_UAT[Trigger Deploy to<br/>Isolated UAT Workflow]
        TRIGGER_UAT --> PROMOTE_UAT[Promotes build to<br/>Isolated UAT]
        PROMOTE_UAT --> UAT_TEST{UAT Testing<br/>Passed?}
        UAT_TEST -->|No| DEVELOP
    end

    subgraph Integration["4️⃣ Standard Integration"]
        UAT_TEST -->|Yes| MERGE_MAIN[🔀 Merge Feature Branch<br/>to default branch]
        MERGE_MAIN --> RELEASE[Run Release Slot Workflow]
        RELEASE --> STANDARD[Standard Promotion Pipeline<br/>dev → uat → prd]
        STANDARD --> END_SUCCESS([End])
    end

    subgraph HotfixProblem["⚠️ HOTFIX CONFLICT ZONE"]
        HOTFIX[🔥 HOTFIX] -->|Direct to main| MAIN[(main branch)]
        MAIN -.->|⚠️ Sync Required<br/>MERGE CONFLICTS| DEVELOP
    end

    %% Styling
    classDef startEnd fill:#48bb78,stroke:#276749,color:white
    classDef process fill:#4a90d9,stroke:#2c5282,color:white
    classDef decision fill:#f7fafc,stroke:#a0aec0,color:#1a202c
    classDef highlight fill:#faf089,stroke:#d69e2e,color:#744210
    classDef slot fill:#9f7aea,stroke:#6b46c1,color:white
    classDef hotfix fill:#fc8181,stroke:#c53030,color:white
    classDef danger fill:#fed7d7,stroke:#c53030,color:#c53030

    class START,END_SUCCESS startEnd
    class CREATE,CLAIM,PR_SLOT,FEEDBACK,MERGE_SLOT,DEVELOP,CICD,BUILD,TEST_DEV,TRIGGER_UAT,PROMOTE_UAT,RELEASE,STANDARD process
    class APPROVE,READY_UAT,UAT_TEST decision
    class MERGE_MAIN highlight
    class ASSIGNED slot
    class HOTFIX hotfix
    class MAIN danger
