# Contributing

This repository defines an Azure executive demonstration built on native Azure
Monitor. There is no application to build and no package manager involved — the
deliverable is Bicep, KQL and a small number of scripts.

A few constraints are not negotiable. A change that breaks one will not be
merged no matter how good it otherwise is.

---

## Getting set up

You need:

- The Azure CLI, signed in (`az login`)
- The Bicep CLI (`az bicep install`)
- PowerShell 7+ for the scripts
- Python 3 (standard library only — the seeder has no dependencies by design)

There is nothing to install from a package manager.

---

## Validating a change

| Command | What it checks |
| --- | --- |
| `az bicep build --file infra-iaas/main.bicep` | Templates compile. Must produce **zero** warnings. |
| `.\infra-iaas\scripts\validate-workbook.ps1 -SubscriptionId <id>` | Every KQL query in the workbook executes against the live workspace. |
| `python infra-iaas/scripts/seed-estate.py --dry-run` | The generator runs and every record is labelled. |

**Run them and read the output.** Do not record a check as passing unless you
executed it and inspected the result. Do not claim an Azure deployment succeeded
unless a deployment command actually completed successfully.

`validate-workbook.ps1` matters more than it looks. ARM validates workbook JSON
but never the KQL inside it, so a workbook can deploy cleanly and still render
broken tiles in front of an audience.

---

## Non-negotiable constraints

### Labelling

Every generated record must carry `IsSynthetic` and `DataClassification`. This is
enforced centrally in `seed-estate.py`; the generator fails loudly rather than
emitting an unlabelled record. Do not add a code path that bypasses it.

All generated content is **Synthetic Demo Data.** All financial figures are
**Illustrative Sample Data, not a customer estimate.**

### No secrets

No credential, connection string, key or client secret may appear in source,
configuration, sample data or CI. Ingestion authenticates with the managed
identities of the VMs and the Automation account through IMDS. If a change
appears to need a stored secret, the design is wrong.

### No autonomous remediation

Remediation requires an explicit human approval decision. The gate is enforced in
`Invoke-ApprovedRemediation.ps1`, which fails closed and audits both approvals
and refusals. Do not add an automatic or implicit approval path.

### Narrative discipline

- **"150 related alerts correlated into 1 actionable incident."** Never describe
  them as false positives.
- Correlation indicates relationship, **not** proven causation.
- Do not frame the customer's existing monitoring investment as a mistake.
- No biased vendor scorecard.

The headline number on screen must match the number spoken aloud. If you change
`TOTAL_ALERTS` in the seeder, update the workbook, the README and
`docs/demo-azure-portal.md` in the same change.

---

## Conventions worth knowing

- **KQL string literals and column aliases use single quotes** (`'Sev1'`,
  `['Related alerts']`). Double quotes are rejected when queries are passed
  through the Azure CLI and require ugly escaping inside workbook JSON.
- **Seeded-data queries scope to the latest ingestion batch** using
  `ingestion_time()`, so re-seeding is safe and cannot inflate the headline
  number. Log Analytics does not delete data promptly by any available
  mechanism — neither the purge API nor table recreation — so do not build
  anything that depends on deletion. The remediation audit query deliberately
  omits this filter so its history is retained.
- Suppress a Bicep diagnostic only with `#disable-next-line` plus a comment
  explaining why it is wrong. Do not silence warnings broadly.
- When a workaround exists because of a platform limitation, leave a comment
  recording the limitation so nobody reintroduces the problem. The removal of
  the Dependency Agent in `infra-iaas/modules/vms.bicep` is the model.

---

## Cost

The estate runs six `Standard_D2ls_v7` VMs at **$17.28/day** — $0.12/hr each,
verified against the Azure retail price API — or roughly **$548/month** at 24×7
including disks and Log Analytics ingestion. **No auto-shutdown is configured.**
Deallocate them when you are not presenting or testing.
