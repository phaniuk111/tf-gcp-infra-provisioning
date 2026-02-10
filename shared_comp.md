graph LR
    subgraph GKE_Namespaces ["GKE Namespaces (Java Services)"]
        direction TB
        NS1["<b>Namespace: DEV</b><br/>Calls with config_dev.properties"]
        NS2["<b>Namespace: DEV 1</b><br/>Calls with config_dev1.properties"]
        NS3["<b>Namespace: DEV 2</b><br/>Calls with config_dev2.properties"]
    end

    subgraph COMPOSER ["Shared Composer Instance"]
        DAG["<b>Universal Launcher DAG</b><br/>(One Master Process)"]
    end

    subgraph GCP_DATAFLOW ["Dataflow (GCP Compute)"]
        direction TB
        J1["Job: Process DEV"]
        J2["Job: Process DEV 1"]
        J3["Job: Process DEV 2"]
    end

    %% Flow
    NS1 & NS2 & NS3 -->|Triggers via API| DAG
    DAG -->|Starts Unique Job| J1 & J2 & J3
