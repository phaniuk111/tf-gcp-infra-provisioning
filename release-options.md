# Deployment Strategy Flows

## Option 1: Static Branches

```mermaid
flowchart TD
    subgraph "Isolated Feature Work"
        A[Feature Branch] -->|merge| B[dev1]
        B -->|deploy| C[DEV1 Environment]
        C -->|test pass| D[uat1]
        D -->|deploy| E[UAT1 Environment]
        E -->|test pass| F[dev]
    end
    
    subgraph "Hotfix Path"
        H[Hotfix Branch] -->|merge directly| F
    end
    
    subgraph "Promotion to Production"
        F -->|deploy| G[DEV Environment]
        G -->|test pass| I[uat]
        I -->|deploy| J[UAT Environment]
        J -->|approval| K[prd]
        K -->|deploy| L[PRD Environment]
    end
    
    subgraph "Sync Required ⚠️"
        F -.->|must sync back| B
        style B fill:#ffcccc
    end
```

---

## Option 2: Slot YAML

```mermaid
flowchart TD
    subgraph "Developer Workflow"
        A[Feature Branch from main] -->|update| B[slots.yaml PR]
        B -->|merge| C{GitHub Actions<br/>reads slots.yaml}
    end
    
    subgraph "slots.yaml"
        S1["slot1:<br/>  branches: [feature-a, feature-b]<br/>  environments: [dev1, uat1]"]
        S2["slot2:<br/>  branches: [feature-c]<br/>  environments: [dev2, uat2]"]
    end
    
    C -->|yq parse| D{Which slot?}
    
    D -->|slot1| E[Deploy to DEV1]
    E --> F[Deploy to UAT1]
    
    D -->|slot2| G[Deploy to DEV2]
    G --> H[Deploy to UAT2]
    
    subgraph "Config Loading"
        E -->|load| E1[config/dev1.properties]
        F -->|load| F1[config/uat1.properties]
        G -->|load| G1[config/dev2.properties]
        H -->|load| H1[config/uat2.properties]
    end
    
    subgraph "Promotion to Production"
        F --> I[Merge to main]
        H --> I
        I -->|deploy| J[DEV Environment]
        J --> K[UAT Environment]
        K --> L[PRD Environment]
    end
```

---

## Option 3: Trunk-Based + Feature Flags

```mermaid
flowchart TD
    subgraph "Developer Workflow"
        A[Feature Branch from main] -->|PR + merge| B[main branch]
    end
    
    subgraph "Environment Selection"
        B --> C{How to choose env?}
        C -->|workflow_dispatch| D1[Manual Selection]
        C -->|PR label| D2[deploy-dev1 label]
        C -->|commit prefix| D3["[dev1] commit msg"]
        C -->|deploy all| D4[All environments]
    end
    
    subgraph "Deployment"
        D1 --> E[GitHub Actions]
        D2 --> E
        D3 --> E
        D4 --> E
        
        E -->|deploy same code| F1[DEV1]
        E -->|deploy same code| F2[DEV2]
        E -->|deploy same code| F3[UAT1]
        E -->|deploy same code| F4[UAT2]
        E -->|deploy same code| F5[PRD]
    end
    
    subgraph "Feature Flags Control Behavior"
        F1 -->|load| G1["config/dev1.properties<br/>feature.new.algo=true"]
        F2 -->|load| G2["config/dev2.properties<br/>feature.new.algo=false"]
        F3 -->|load| G3["config/uat1.properties<br/>feature.new.algo=true"]
        F4 -->|load| G4["config/uat2.properties<br/>feature.new.algo=false"]
        F5 -->|load| G5["config/prd.properties<br/>feature.new.algo=false"]
    end
    
    style F1 fill:#e1f5fe
    style F2 fill:#e1f5fe
    style F3 fill:#fff3e0
    style F4 fill:#fff3e0
    style F5 fill:#c8e6c9
```

---

## Comparison: Environment Isolation

```mermaid
flowchart LR
    subgraph "Option 1: Static Branches"
        A1[dev1 branch] -->|owns| B1[DEV1 env]
        A2[dev2 branch] -->|owns| B2[DEV2 env]
    end
    
    subgraph "Option 2: Slot YAML"
        C1[Any branch] -->|slot1| D1[DEV1 env]
        C2[Any branch] -->|slot2| D2[DEV2 env]
    end
    
    subgraph "Option 3: Trunk"
        E1[main] -->|same code| F1[DEV1 env]
        E1 -->|same code| F2[DEV2 env]
        G1[flags] -.->|control| F1
        G2[flags] -.->|control| F2
    end
```

---

## Config Flow: Spring Boot + Dataflow

```mermaid
flowchart TD
    subgraph "Source of Truth"
        A["config/{env}.properties<br/>─────────────────<br/>feature.new.algo=true<br/>batch.size=500<br/>db.pool.size=10"]
    end
    
    A --> B{GitHub Actions}
    
    subgraph "Spring Boot Deployment"
        B -->|convert to env vars<br/>or Helm values| C[Kubernetes Pod]
        C -->|Spring context init| D["@Value annotations<br/>read properties"]
    end
    
    subgraph "Dataflow Deployment"
        B -->|convert to args| E["gcloud dataflow jobs run<br/>--feature.new.algo=true"]
        E -->|job submit| F["PipelineOptions<br/>reads args"]
    end
    
    subgraph "Change = Redeploy"
        G[Update properties file] --> H[PR + merge]
        H --> I[CI/CD triggers]
        I --> J[Restart pod / Resubmit job]
    end
```
