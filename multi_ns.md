h2. As-Is vs To-Be CI/CD Flow

{panel:title=AS-IS (Current Flow)|borderColor=#0052CC|bgColor=#DEEBFF}
h3. eod-service-mono (main branch)
{code}
PR Merge to main
      ↓
Build Docker Image
      ↓
Deploy to DEV (automatic)
      ↓
Auto-push to SIT branch
{code}

h3. eod-app-deployment
{code}
sit branch → SIT Environment
      ↓
PR: sit → uat → UAT Environment
      ↓
PR: uat → prl1 → PRL1 (+ Release + CHG)
PR: uat → prd  → PRD  (+ Release + CHG)
{code}
{panel}

{panel:title=TO-BE (Proposed Flow)|borderColor=#0052CC|bgColor=#DEEBFF}
h3. eod-service-mono (main branch) - WITH PR LABELS
{code}
Developer creates PR to main
      ↓
Developer applies PR label:
   • target:dev1 → Deploy to dev1 namespace
   • target:dev2 → Deploy to dev2 namespace
      ↓
PR Merged to main
      ↓
Build Docker Image
      ↓
GitHub Actions reads label → Deploy to target dev namespace(s)
      ↓
Auto-push to SIT branch
{code}

h3. eod-app-deployment (uat branch) - WITH PR LABELS
{code}
Developer creates PR: sit → uat
      ↓
Developer applies PR label:
   • target:uat1 → Deploy to uat1 namespace
   • target:uat2 → Deploy to uat2 namespace
      ↓
PR Merged
      ↓
GitHub Actions reads label → Deploy to target uat namespace(s)
{code}

h3. eod-app-deployment (prl1, prd branches) - NO CHANGE
{code}
PR: uat → prl1 → PRL1 (+ Release + CHG)
PR: uat → prd  → PRD  (+ Release + CHG)
{code}
{panel}

----

h2. Side-by-Side Comparison

||Stage||AS-IS||TO-BE||
|DEV Deployment|Automatic on merge to main|PR Label selects namespace (dev1/dev2)|
|UAT Deployment|Single UAT environment|PR Label selects namespace (uat1/uat2)|
|SIT Promotion|Auto-push to sit branch|Auto-push to sit branch (No Change)|
|PRL1/PRD|PR-based with Release + CHG|PR-based with Release + CHG (No Change)|

----

h2. PR Labels

||Label||Target||Repository||
|target:dev1|dev1 namespace|eod-service-mono|
|target:dev2|dev2 namespace|eod-service-mono|
|target:uat1|uat1 namespace|eod-app-deployment|
|target:uat2|uat2 namespace|eod-app-deployment|
