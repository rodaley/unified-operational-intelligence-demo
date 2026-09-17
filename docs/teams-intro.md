# Teams introduction — StoryBrand (SB7)

A ready-to-paste Teams post introducing this repository to Infrastructure
Solution Engineers, written on the StoryBrand 7-part framework.

The framework's first rule is that **the audience is the hero, not the asset**.
So the hero here is the SE reading the message, not the demo and not the person
who built it. The repository is the tool that makes them more capable.

---

## The post

> **Ever been asked "can you actually show me?" in a monitoring conversation — and had only slides?**
>
> Four monitoring tools. An alert queue nobody trusts. And when something
> breaks, forty minutes before anyone can tell an executive which business
> services are down and how many customers are affected.
>
> Explaining that gap is easy. Showing it is not — especially to an
> infrastructure audience, where a demo has to look like their estate.
>
> I hit that wall myself. I built this as a container app first, and it did not
> resonate with infra buyers. So I rebuilt it as what it should have been:
> **six real Ubuntu VMs, real Azure Monitor Agent telemetry, and the Azure
> Portal as the only demo surface.** No application to deploy, nothing to
> maintain, nothing that looks like a science project.
>
> **Three steps to make it yours:**
> 1. `az deployment sub create` against `infra-iaas/main.bicep` — the whole
>    estate, in your own subscription
> 2. Run the seeder on a VM to lay down the synthetic business layer
> 3. Run `validate-workbook.ps1` — it executes all 17 KQL queries behind the
>    workbook, so you find a broken tile before an audience does
>
> **What you get to show:** 150 related alerts correlated into 1 actionable
> incident. The affected business services, the users behind them, and what the
> customer is spending to learn all this — on one pane, in their own portal.
> When someone says "prove it", you open the query and read the KQL aloud. It is
> deterministic, not a model.
>
> **Without it** you're describing an outcome. **With it** you're standing in
> the customer's own Azure Portal showing one, and the conversation moves from
> "what could Azure do" to "what would this look like on our estate".
>
> Clone it, deploy it into a sandbox once, and walk the running order. The
> presentation itself is about 30 minutes.
>
> 🔗 https://github.com/rodaley/unified-operational-intelligence-demo
>
> *All business data is synthetic and labelled. Financial figures are
> illustrative, not a customer estimate.*

---

## Short version

For a busy channel where the long post will not be read.

> **New demo asset for infra conversations.**
>
> Six real VMs, real Azure Monitor telemetry, and the Azure Portal as the entire
> demo surface — no app to deploy. It shows 150 related alerts correlated into 1
> actionable incident, the business services and users behind it, and the
> observability spend underneath. All native: workbook, VM Insights, Alerts,
> Logs, Automation.
>
> One Bicep deployment into your own subscription, a seeder, and a validation
> script that runs all 17 workbook queries so nothing breaks on stage. Presenter
> guide and a Word walkthrough with screenshots are in the repo.
>
> 🔗 https://github.com/rodaley/unified-operational-intelligence-demo
>
> *Synthetic data throughout; financials are illustrative.*

---

## How it maps to SB7

Useful if you want to retarget the message at a different audience — a
security SE, a data SE, or the customer themselves. Keep the structure and
change the hero.

| SB7 element | In this post |
| --- | --- |
| **1. A character** | The Infrastructure SE, who wants to be credible in the room rather than merely fluent. |
| **2. Has a problem** | *External:* no demonstrable artefact for a monitoring conversation. *Internal:* the discomfort of describing rather than showing. *Philosophical:* an SE should not have to build a demo from scratch to have a credible architecture conversation. |
| **3. And meets a guide** | *Empathy:* "I hit that wall myself — I built the container version first and it did not land." *Authority:* it is deployed, native, and the workbook is validated by 17 executed queries. |
| **4. Who gives them a plan** | Three concrete steps: deploy, seed, validate. Short enough to be believed. |
| **5. And calls them to action** | *Direct:* clone and deploy it into a sandbox. *Transitional:* read the README story and the business case first. |
| **6. That helps them avoid failure** | Turning up with slides; losing an infra audience to a PaaS demo; a tile failing live in front of a customer. |
| **7. And ends in success** | Standing in the customer's own portal, showing the correlation, and answering "prove it" by reading the query aloud. |

---

## Claims discipline

If you adapt this, keep these intact. They are what make the demonstration
survive a sceptical audience.

- **"150 related alerts correlated into 1 actionable incident."** Never "150
  false positives." Every one of the 150 was a true signal; the point is that a
  human had to triage 150 items to find one problem.
- **Correlation, not causation.** The demo groups related signals. It does not
  prove what caused the incident, and the AI layer is explicitly instructed not
  to infer a cause.
- **Synthetic and labelled.** Every generated record carries `IsSynthetic` and
  the banner is visible on every workbook tab. Say so out loud — it is a
  credibility asset, not a disclaimer to bury.
- **Illustrative financials.** The revenue, user and spend figures are invented
  to be plausible. They are not a customer estimate and not a migration business
  case.
- **No autonomous remediation.** Remediation is proposed; a human approves; the
  approval is written to an audit trail. Do not describe it as self-healing.
- **Not a vendor scorecard.** The spend tab shows duplicated ingest across
  tools. That is an architecture observation, not a claim that any competing
  product is bad or that the customer's original tooling choice was wrong.
