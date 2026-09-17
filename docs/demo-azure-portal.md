# Unified Operational Intelligence — Azure Portal Demo Guide

**The Azure Portal is the demo surface.** There is no custom web application. Everything
shown below is a native Azure Monitor experience rendering data from a live estate.

---

## 0. What is real and what is synthetic

State this out loud at the start. It is a credibility asset, not a disclaimer to hide.

| Layer | Status |
| --- | --- |
| The six virtual machines | **Real.** Running Ubuntu in `rg-uoi-iaas`, eastus2. |
| CPU / memory / disk / network telemetry | **Real.** Collected by Azure Monitor Agent into `InsightsMetrics`. |
| Syslog | **Real.** Collected by Azure Monitor Agent. |
| Heartbeat / agent health | **Real.** |
| Alert rules, fired alerts, action group | **Real Azure Monitor resources.** The correlated-incident alert has genuinely fired. |
| Workbook, dashboard, Automation runbook | **Real Azure resources.** |
| Business services, incidents, revenue, tool spend | **Synthetic.** Generated, labelled `IsSynthetic = true`, ingested through a real Data Collection Rule. |

Every synthetic record carries `IsSynthetic` and `DataClassification`. All financial figures are
**"Illustrative Sample Data, not a customer estimate."** All generated content is
**"Synthetic Demo Data."**

**Known gap, stated plainly:** the VM Insights **Map** tab is not available. The Dependency Agent
does not support the Ubuntu builds in this estate (see `infra-iaas/modules/vms.bicep` for the
rationale). VM Insights **Performance** works from the Azure Monitor Agent alone, and service
topology is presented in the workbook instead.

---

## Environment

Resource names are fixed by the Bicep templates; the subscription and workspace
identifiers belong to whichever tenant you deploy into. Record yours here.

| Item | Value |
| --- | --- |
| Subscription | `<your-subscription-id>` |
| Resource group | `rg-uoi-iaas` |
| Region | `eastus2` |
| Log Analytics workspace | `log-uoi` |
| Workbook | `UOI — Unified Operational Intelligence` |
| Dashboard | `dash-uoi` |
| Automation account | `aa-uoi` |

Find the deployment-specific values after deploying:

```powershell
az monitor log-analytics workspace show -g rg-uoi-iaas -n log-uoi `
  --query customerId -o tsv                       # workspace GUID
az monitor data-collection endpoint list -g rg-uoi-iaas `
  --query "[0].logsIngestion.endpoint" -o tsv     # DCE endpoint
az monitor data-collection rule list -g rg-uoi-iaas `
  --query "[?contains(name,'ingest')].immutableId" -o tsv   # DCR immutable ID
```

None of these are secrets — they are resource identifiers, and every call
against them is authorised by Entra ID and RBAC. They are parameterised here so
the guide is portable between tenants, not because they are sensitive.

---

## 0. Before you present — start the estate (10 min, unattended)

**The six virtual machines are normally left deallocated.** They cost roughly
`$17.28`/day when running and nothing but disk while stopped, and a nightly
auto-shutdown at 23:00 UTC stops them again if someone forgets. So the first
step on demo day is always to start them.

```powershell
$ids = az vm list -g rg-uoi-iaas --query "[].id" -o tsv
az vm start --ids $ids
```

Allow **5–10 minutes** after the VMs report `VM running` before you present.
Nothing is broken during that window — the Azure Monitor agent has to come up,
reconnect and ship its first batch, so VM Insights and the CPU charts will look
sparse or empty until it does. Confirm with:

```powershell
az vm list -g rg-uoi-iaas --show-details --query "[].{n:name,p:powerState}" -o table
```

Then **seed the synthetic business layer** (see *Seed once, on the day you
present* below) and run `infra-iaas/scripts/validate-workbook.ps1` — it executes
every embedded workbook query and tells you which tiles will render. A tile
returning no rows on stage is the failure mode this step exists to prevent.

To leave the estate cold again afterwards:

```powershell
az vm deallocate --ids $(az vm list -g rg-uoi-iaas --query "[].id" -o tsv)
```

> Deallocating preserves the disks, the workspace, the workbook, the dashboard
> and all previously ingested data. Only compute billing stops. Starting the
> VMs again returns the estate to exactly the state it was in.

---

## 1. Dashboard — the opening frame (2 min)

**Portal → Dashboard → select `dash-uoi`.**

This is the "walk in and it is already on screen" view. It carries the synthetic-data label,
the headline correlation number, and two live Azure Monitor charts reading real VM metrics.

Say: *"This is native Azure Monitor. No custom application, no export, no middleware."*

---

## 2. Workbook — the main event (10–12 min)

**Portal → Monitor → Workbooks → `UOI — Unified Operational Intelligence`.**

Five tabs. There is a shared **TimeRange** parameter at the top — change it once and all
16 query items re-scope together. The default is **24 hours**.

> **The synthetic business layer is anchored to the moment you seed it**, and it spans roughly
> a 45-minute window. Once that window falls outside the selected time range, the incident,
> impact and spend tabs render empty and the headline tile shows nothing. **Re-seed on the day
> you present.** If a tile is unexpectedly blank, widen TimeRange before assuming a fault.

### Tab 1 — Estate health
Six VMs, their tier, and whether they are currently reporting; then real CPU, memory and
network from `InsightsMetrics`.

Point at it: *"These are real machines emitting real telemetry, collected by the Azure Monitor
Agent through a Data Collection Rule. Nothing here is mocked."*

### Tab 2 — Incident correlation — **the money slide**
The headline tile reads:

| Related alerts | Actionable incidents | Reduction in items to triage |
| --- | --- | --- |
| 150 | 1 | 99% |

Say exactly: **"150 related alerts correlated into 1 actionable incident."**

Do **not** say "false positives". They were not false — each one was a true signal about the
same underlying condition. The value is correlation, not suppression.

Then walk down the tab: the alert storm over time by tier, the earliest Sev1 signal, and the
distribution across services.

On the earliest-signal tile, say: *"This is the first related signal in the window. Correlation
shows these alerts are related — it does not by itself prove causation. It tells the responder
where to look first."*

### Tab 3 — Business impact
Service health, peak concurrent degradation, and revenue at risk per business service.

Label it before anyone asks: *"Illustrative sample data, not a customer estimate."*

### Tab 4 — Observability spend
Current tool spend by category and the overlap analysis.

This is a **consolidation** argument, not a competitive teardown. Do not frame the customer's
existing Datadog investment as a mistake — it solved the problem they had. The argument is that
estate-wide correlation is now available natively where the workloads already run.

### Tab 5 — Response
The evidence chain behind the incident, and the remediation audit trail — which will be empty
of today's run until you complete section 4.

---

## 3. Native Azure Monitor drill-down (5 min)

This is the part that only works because it is genuinely Azure-native. Leave the workbook.

**a. VM Insights.** Monitor → Virtual Machines → Performance tab. Real charts, all six VMs.
Or open `vm-web-01` → Monitoring → Insights.

**b. Alerts.** Monitor → Alerts. Filter to `rg-uoi-iaas`. There are **genuinely fired Sev1
alerts** named *"Related estate alerts correlated into an actionable incident"*. Open one and
show the fired history — this is a real alert rule that really fired, not a screenshot.

**c. Logs.** Monitor → Logs, scope `log-uoi`. Run ad-hoc KQL live. This is the strongest
credibility move available, because an executive audience can ask for anything:

```kusto
UoiEstateAlert_CL
| where IsSynthetic == true
| summarize RelatedAlerts = dcount(AlertId) by IncidentId
```

```kusto
InsightsMetrics
| where Namespace == 'Processor' and Name == 'UtilizationPercentage'
| summarize avg(Val) by Computer, bin(TimeGenerated, 5m)
| render timechart
```

**d. Data Collection Rules.** Monitor → Data Collection Rules. Show `dcr-vminsights-uoi`,
`dcr-syslog-uoi`, `dcr-ingest-uoi`. This answers "how does the data get here" with a resource,
not a diagram.

**e. Observability agent — the AI layer (4 min).** Still in Monitor → Logs, click
**Observability agent** in the query toolbar. There is **no Azure OpenAI resource in this
estate** — no model deployment, no key, no endpoint. The agent ships in the Logs blade.

Use this prompt verbatim:

```text
For incident INC-2026-0916-001 in table UoiEstateAlert_CL over the last 7 days:
count DISTINCT AlertId (rows may be ingested more than once), and name the single
earliest signal. Keep the answer to a few short lines. Synthetic demo data.
Do not assert a root cause.
```

Verified live: it returned **150 distinct AlertId values**, named `ALRT-0001` on `vm-sql-01`
for Document Archive, and closed with *"No root cause inferred."* — matching the workbook
headline exactly. It took about 1¼ minutes and displayed every KQL query it ran.

> **Two traps.** Asked the same question *without* the DISTINCT instruction, the agent answered
> **"Related alerts: 300"** — it counts rows, and the seeder had been run twice. The workbook
> de-duplicates on `AlertId` and scopes to the newest ingestion batch, so it still showed 150.
> **Keep the DISTINCT wording, and seed only once.** Second trap: it is not instant. Narrate the
> previous slide while it works, or ask it before the session.

Say: *"I have not deployed a model, and there is no AI service in this resource group. Notice it
shows me every query it ran, and notice it declined to assert a root cause — because I asked it
not to. The correlation itself is deterministic KQL you can audit."*

**f. Optional — built-in ML in KQL.** For a technical audience, both verified against this estate:

```kusto
UoiEstateAlert_CL
| where IsSynthetic == true
| project Service, Tier, Severity, Component
| evaluate autocluster()
```

Returns six discovered segments, including a 35-alert `vm-app-02` / Sev2 / app-tier segment,
found without being told what to look for.

```kusto
InsightsMetrics
| where Namespace == 'Processor' and Name == 'UtilizationPercentage'
| make-series CPU=avg(Val) default=0 on TimeGenerated from ago(2d) to now() step 15m by Computer
| extend (anom, score, baseline) = series_decompose_anomalies(CPU, 2.0)
| render anomalychart with(anomalycolumns=anom)
```

Finds genuine load excursions on the real VMs (CPU peaks of 50–74% against a ~3% average). Be
precise: this is anomaly detection on **real telemetry**. It did not detect the synthetic
incident, which lives in a different table. Do not conflate the two.

---

## 4. The approval gate (5 min) — run this live

**Portal → Automation Accounts → `aa-uoi` → Runbooks → `Invoke-ApprovedRemediation`.**

There is **no autonomous remediation**. The gate is enforced in code, not promised in a slide.

**Run it twice. The refusal first — that is the point.**

1. Click **Start**. Set `ApprovalDecision` = `Reject`, `ApprovedBy` = your name.
   The runbook records the refusal, changes nothing, and stops.
2. Click **Start** again. Set `ApprovalDecision` = `Approve`, `ApprovedBy` = your name.
   It walks the simulated remediation steps and writes an audit record.

Both paths write to `UoiRemediationAudit_CL`. Return to workbook **Tab 5 — Response** and show
the audit trail with both entries.

Say: *"The system proposes. A human decides. Both the approval and the refusal are audited."*

Note: the runbook **simulates** remediation. It does not modify the VMs in either path.

---

## 5. Suggested running order

| # | Surface | Time |
| --- | --- | --- |
| 1 | Dashboard `dash-uoi` | 2 min |
| 2 | Workbook tabs 1–5 | 10–12 min |
| 3 | VM Insights → Alerts → Logs → DCRs | 5 min |
| 4 | Observability agent (scripted prompt) | 4 min |
| 5 | Runbook: refuse, then approve, then audit trail | 5 min |

Roughly 30 minutes with discussion.

---

## 6. Before the demo

The estate runs six `Standard_D2ls_v7` VMs at **$17.28/day** if left running
($0.12/hr each, verified against the Azure retail price API), or roughly **$548/month**
at 24×7 once StandardSSD OS disks (~$14/mo) and Log Analytics ingestion (~$8/mo at a
measured 0.089 GB/day billable) are included. **No auto-shutdown is configured.**
Deallocate between demos:

```powershell
az vm deallocate --ids $(az vm list -g rg-uoi-iaas --subscription <sub> --query "[].id" -o tsv) --no-wait
```

Restart and re-seed ahead of a session:

```powershell
az vm start --ids $(az vm list -g rg-uoi-iaas --subscription <sub> --query "[].id" -o tsv)
```

Then re-seed. The seeder runs **on an estate VM** and authenticates through its managed
identity, so there is no secret anywhere and nothing to configure locally:

```powershell
$dce = '<your-dce-endpoint>'     # see the Environment table above
$dcr = '<your-dcr-immutable-id>'
# upload infra-iaas/scripts/seed-estate.py to the VM, then:
az vm run-command invoke -g rg-uoi-iaas -n vm-web-01 `
  --command-id RunShellScript --scripts `
  "python3 /tmp/seed.py --endpoint $dce --rule-id $dcr --anchor now"
```

Expect 150 alert records, 360 service-health records and 30 cost records, all `IsSynthetic=true`.

**Timing that will catch you out:** telemetry takes roughly 10 minutes to appear after VMs
start, and a newly created custom table takes about 10 minutes for its first ingestion. Zero
rows immediately after a successful upload is latency, not failure. **Start the estate at least
20 minutes before the demo.**

**Re-seed on the day you present.** The synthetic business layer is timestamped at seeding time
and spans about 45 minutes. The workbook defaults to a 24-hour window, so data seeded yesterday
will have aged out and the incident, impact and spend tabs will be empty. Re-seeding is the fix.

Re-seeding is safe for the workbook but **seed only once per session**. The Logs Ingestion API
has no upsert, so seeding twice writes 300 rows rather than 150. Every workbook query scopes to
the most recent ingestion batch via `ingestion_time()` and de-duplicates on `AlertId`, so the
headline still reads 150 — verified on a double-seeded workspace. **The Observability agent in
§3e is not immune**: it counts rows and will answer 300 unless the prompt says "count DISTINCT
AlertId". If you do re-seed, use the exact prompt in §3e.

Confirm before going on stage:

```powershell
.\infra-iaas\scripts\validate-workbook.ps1 -SubscriptionId <sub>
```

This executes all 17 embedded workbook queries against the live workspace. ARM validates the
workbook JSON but never the KQL inside it, so this is the only check that catches a broken tile
before an audience does.

---

## 7. Questions you will be asked

**"Is this real or a mock-up?"**
The VMs and their telemetry are real. The business and financial layer is synthetic and
labelled as such in the data itself. Open Logs and query it live.

**"Does correlation prove root cause?"**
No. Correlation establishes that signals are related and collapses triage volume. It points a
responder at the earliest related signal. Determining causation remains a human judgement.

**"Can it fix things automatically?"**
It is deliberately built not to. Remediation requires an explicit human approval decision, and
both approvals and refusals are audited.

**"Where is the AI in this?"**
Two different things, and it matters not to blur them. The correlation is **deterministic KQL** —
auditable, repeatable, no model involved. That is the point: the number on the slide is not a
guess. Separately, Azure Monitor Logs now ships an **Observability agent** that reads the same
workspace in natural language. It is built in — nothing was deployed for it.

**"Can we trust what the agent says?"**
Trust it the way you would trust a junior analyst: check the work. It shows you every KQL query
it ran, and the portal labels its output "AI-generated content may be incorrect." In testing it
answered 300 instead of 150 because it counted rows rather than distinct alerts — which is why
the query beneath it, not the agent, is the source of truth.

**"Why not keep using what we have?"**
Nothing here says the existing investment was wrong. The argument is consolidation: estate-wide
correlation available natively where the workloads already run, with one less integration
boundary.

---

## 8. What is deliberately not included

These are documented as production extensions, not built:

- AKS, Azure SQL, Azure AI Search, Event Hubs, Service Bus
- Any real Datadog tenant or real on-premises infrastructure
- Azure OpenAI, or any deployed model, key or endpoint. The AI in §3e is the Observability
  agent built into Azure Monitor Logs; there is nothing to provision. The correlation itself is
  deterministic KQL, auditable line by line, and does not use AI at all.
- VM Insights Map / service dependency topology (Dependency Agent unsupported on this OS)
