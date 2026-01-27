|| Area || Current || Proposed || Change Impact ||
| eod-service-mono (main) | Build → single DEV, Monolithic execution | Slot based deployment for isolated feature branch testing | (!) Workflow update |
| eod-app-deployment (uat) | Single UAT deployment | Slot based deployment for isolated feature branch testing | (!) Workflow update |
| GKE DEV cluster | Single namespace | dev1 + dev2 namespaces for isolated feature branch testing | (!) Namespace creation \\ (!) Add additional cluster capacity |
| GKE UAT cluster | Single namespace | uat1 + uat2 namespaces for isolated feature branch testing | (!) Namespace creation \\ (!) Add additional cluster capacity |
| Composer | Single DAG per env | Multiple DAGs (dev1, dev2, uat1, uat2) for isolated feature branch testing | (!) DAG creation and logic to handle |
| BigQuery | Single dataset per env | Multiple datasets (dev1, dev2, uat1, uat2) for isolated feature branch testing | (!) Dataset creation |
| eod-app-dataflow | Monolithic execution | Slot based deployment for isolated feature branch testing | (!) GitHub workflow changes |
| Helm | Single override file per env | Multiple override files per slot | (!) Helm Config changes |
| slot-assignment.yml | Not exists | Track slot assignments in default branch | (!) New file creation \\ (!) Claim/Release slot workflows |
