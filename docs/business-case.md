# The business case

> **Illustrative Sample Data, not a customer estimate.** Every financial figure in this
> document is invented for demonstration. The services, revenue rates, user counts and
> tool spend are shaped to be plausible for a mid-size insurer; none are derived from any
> customer's actual figures. The six virtual machines and their Azure Monitor telemetry
> are real. See [`../README.md`](../README.md) for the full real-versus-synthetic split.

This document states the argument the demonstration makes, so that it is written down
once rather than reconstructed from presenter notes. `demo-azure-portal.md` covers *how*
to present. This covers *what is being claimed*, and — just as important — what is not.

---

## 1. The problem, stated fairly

A mid-size insurer runs a hybrid estate. Over time it has accumulated several monitoring
tools, each adopted for a sound reason and each doing its job. The result is not a
scandal; it is the normal outcome of a decade of good local decisions.

The cost of that accumulation shows up in two places:

**During an incident.** Signals arrive in separate tools, on separate consoles, with
separate naming. A responder's first task is not diagnosis — it is reconciliation.
Working out whether the alert in one tool and the alert in another describe the same
event consumes the minutes that matter most.

**Every month.** Overlapping tools ingest overlapping telemetry. Some of that overlap is
deliberate and worth paying for. Some is nobody's decision — it accumulated.

The question this demonstration raises is narrow and answerable: **how much of what we
ingest is duplicated, and is that duplication intentional?**

## 2. What the demonstration shows

A single correlated incident, viewed entirely through native Azure Monitor.

| Measure | Figure | Source |
| --- | --- | --- |
| Related alerts raised across the estate | **150** | Synthetic Demo Data |
| Actionable incidents after correlation | **1** | Derived by KQL |
| Reduction in items to triage | **99%** | Derived |
| Services affected | 5 of 5 | Synthetic |
| Users affected at peak | **11,098** | Illustrative |
| Revenue exposed at peak | **$78,206 per hour** | Illustrative |

The 150 are **related alerts, not false positives.** Each was a true signal from a
component that was genuinely affected. The value is not that the alerts were wrong — it
is that a responder should be handed **one** incident with evidence rather than 150
notifications to sort by hand.

Correlation establishes a **relationship** between signals and points a responder at the
earliest one (`ALRT-0001`, storage latency on `vm-sql-01`). **It does not prove
causation.** That judgement stays with a human, and so does the remediation decision.

## 3. Where the money is

Illustrative monthly observability spend across the estate:

| Tool | Category | Monthly | Duplicated ingest |
| --- | --- | --- | --- |
| Existing APM tool | Application monitoring | $41,000 | 34% |
| Existing log platform | Log analytics | $28,500 | 41% |
| Azure Monitor | Unified platform | $19,800 | 0% |
| Infrastructure monitoring | Infrastructure | $12,250 | 22% |
| Synthetic monitoring | Digital experience | $6,400 | 8% |
| **Total** | | **$107,950** | |

Applying each tool's duplication rate to its spend gives roughly **$28,800 per month —
about $346,000 a year — attributable to telemetry ingested more than once.**

Three honest qualifications on that number:

1. **Not all duplication is waste.** Some is deliberate redundancy, some is a retention
   or residency requirement, some is a team that needs its own view. The figure is a
   prompt for an audit, not a savings claim.
2. **It is not a migration estimate.** Consolidation has its own cost — effort,
   retraining, re-tooling, risk. None of that is modelled here.
3. **This is not a vendor scorecard.** No tool in that table is presented as inferior.
   Each was adopted for a reason that likely still holds.

## 4. The argument

Three claims, in order of how much weight they carry.

**Correlation belongs where the estate already is.** The insurer's workloads run in
Azure. Azure Monitor already receives their telemetry. Correlating there removes an
integration boundary rather than adding one — nothing to install, no connector to keep
current, no second copy of the data to pay for and secure.

**The response path is the product, not a slideware add-on.** Detection, correlation,
impact, spend and the approval gate are one continuous surface: workbook, dashboard,
Logs, Alerts and an Automation runbook. The audience sees a working Azure estate, not a
prototype built to make a point.

**The gate is a feature.** Nothing remediates itself. A proposed action is presented with
its evidence and blast radius, and a human decides. Approvals *and* refusals are audited.
For a regulated insurer, that is the difference between a demonstration and a deployable
pattern.

## 5. The ask

Not a migration. A scoped, low-commitment next step:

1. **An ingest audit.** Measure actual duplication across existing tools. The number will
   be specific to the estate; the $346k here is illustrative only.
2. **One service, correlated natively.** Pick a single business service and correlate it
   in Azure Monitor alongside existing tooling. Nothing is switched off.
3. **Compare on a real incident.** Measure triage time against the current path.

Existing tools stay in place throughout. If native correlation does not shorten triage on
a real incident, the exercise ends there having cost a few weeks.

## 6. What this demonstration does not claim

Stating these unprompted is a credibility asset.

- **It does not claim the existing monitoring investment was a mistake.** It solved the
  problem it was bought for. The question is consolidation, not blame.
- **It does not claim correlation proves causation.**
- **It does not claim autonomous remediation.** By design, and permanently.
- **It does not claim these financials.** They are illustrative. The real number comes
  from the ingest audit in §5.
- **It does not claim a like-for-like feature comparison** with any third-party tool.
  None was benchmarked, and none is disparaged.
- **It does not model migration cost, retraining or risk.**

## 7. Questions to expect

**"Is this real or a mock-up?"**
The VMs and their telemetry are real. The business and financial layer is synthetic and
labelled as such *in the data itself* — every row carries `IsSynthetic = true`. Open Logs
and query it live.

**"Would we have to replace our current tooling?"**
No, and the proposed step explicitly does not. Estates run multiple tools for good
reasons. The question is whether the overlap is deliberate.

**"Where does the 99% come from?"**
`dcount` of related alerts against `dcount` of correlated incidents, in KQL you can read
on screen. It is arithmetic on labelled demo data, not a benchmark.

**"What about our on-premises estate?"**
Azure Arc extends the same agent and the same Data Collection Rules to machines outside
Azure. Not deployed in this demonstration — see §5 of the presenter guide for the honest
boundary of what was built.

**"Where is the AI?"**
The correlation is deterministic KQL — auditable, repeatable, no model involved. That is
deliberate: the headline number is not a guess. Separately, Azure Monitor Logs ships an
Observability agent that reads the same workspace in natural language, with nothing to
deploy. The two are kept distinct on purpose.
