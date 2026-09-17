# Security Policy

## Scope

This repository contains an **executive demonstration** built on native Azure
Monitor. It holds no customer data, no personal data, no production credentials
and no real business telemetry. Everything it generates is **Synthetic Demo
Data**, and all financial figures are **Illustrative Sample Data, not a customer
estimate.**

The virtual machines and their platform telemetry are real, so the deployed
estate is a real attack surface even though the business data on top of it is
invented.

A weakness here can still:

- expose the Azure subscription a demonstration was deployed into,
- be copied into a fork that does handle real data, or
- produce a misleading claim in front of an executive audience.

All three are worth reporting.

## Reporting a vulnerability

**Please do not open a public issue for a security problem.**

Report it privately using GitHub's private vulnerability reporting: go to the
**Security** tab of this repository and choose **Report a vulnerability**. If
that is unavailable to you, contact the repository owner directly.

Please include:

- what the issue is and where it lives,
- how to reproduce it,
- what an attacker could actually achieve,
- any suggested fix.

You will get an acknowledgement, an assessment, and a fix or an explicit
decision not to fix with reasoning. Please give a reasonable window before
disclosing publicly.

## What we consider a vulnerability here

In roughly descending order of seriousness:

1. **Any credential, key, token or connection string committed to this
   repository.** The design goal is that none exists. Ingestion authenticates
   with the system-assigned managed identities of the VMs and the Automation
   account through IMDS. A committed secret is a defect regardless of whether it
   is live.
2. **A path that bypasses the human approval gate.** `Invoke-ApprovedRemediation.ps1`
   must not be able to reach remediation without a recorded human decision. This
   is a correctness property and a trust property at the same time.
3. **An over-broad Azure role assignment** in the Bicep templates. Ingestion
   identities should hold Monitoring Metrics Publisher on the data collection
   rule and nothing wider.
4. **Unintended network exposure of the estate** — an NSG rule or public address
   that makes a VM reachable from the internet.
5. **Injection through the seeding path** that would let crafted input reach the
   workspace as something other than a labelled synthetic record.
6. **A KQL or workbook change that silently removes a synthetic-data label** from
   what an audience sees.

## What is already known

These are deliberate trade-offs, not undiscovered issues. Reporting them again
is not necessary:

- **The Log Analytics workspace retains superseded synthetic data.** Log
  Analytics does not delete data promptly by any available mechanism — neither
  the purge API nor table recreation. Rather than depend on deletion, every
  seeded-data query scopes to the most recent ingestion batch using
  `ingestion_time()`. Older rows remain queryable in the workspace by anyone
  with workspace read access. They are synthetic and labelled.
- **Remediation is simulated.** `Invoke-ApprovedRemediation.ps1` changes nothing
  on the VMs in either the approve or the reject path. It is a demonstration of
  the gate, not a remediation tool.
- **VM Insights Map is absent** because the Dependency Agent is not installed.
  That is a capability gap, not a security control.
- **`MDE.Linux` extensions** appear on the VMs. They are auto-provisioned by
  subscription policy and are not deployed by this repository.

If you can show that one of these is worse than documented, that is very much
worth reporting.

## Supported versions

Only the current `master` branch is supported. This is a demonstration
repository; there are no maintained release branches and no backported fixes.

## Security practices in this repository

- **No secrets anywhere.** No Azure client secret, key, connection string or
  token in source, configuration, sample data or scripts. Ingestion uses managed
  identity via IMDS, so there is no credential to supply or rotate.
- The estate SSH key is generated and kept **outside the repository**, and only
  the public key is passed as a deployment parameter.
- The seeder has **no third-party dependencies** — Python standard library only —
  so there is no dependency supply chain to compromise.
- Synthetic labelling (`IsSynthetic`, `DataClassification`) is enforced centrally
  in the generator, which fails loudly rather than emitting an unlabelled record.
- The approval gate **fails closed**: anything other than an explicit `Approve`
  is recorded as a refusal and stops.
- Both approvals and refusals are written to an audit table.

## Note on prior versions

This repository previously contained a TypeScript application deployed to Azure
Container Apps, with its own authentication model and threat surface. That
application has been retired and its Azure deployments torn down. Its source
remains in the git history, and security findings against that history are out
of scope.
