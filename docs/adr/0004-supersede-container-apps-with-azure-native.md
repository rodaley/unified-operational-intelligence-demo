# ADR 0004 — Supersede the Container Apps application with a native Azure Monitor estate

- **Status:** Accepted
- **Date:** 2026-09-16
- **Decided by:** Project owner (direct instruction)
- **Supersedes:** ADR 0001 (architecture), and §4, §6, §7, §26 and §27 of
  `docs/requirements-spec.md`
- **Affects:** ADR 0002 (AI fallback) and ADR 0003 (telemetry normalization) — both
  obsolete, see *Consequences*

---

## Context

The repository originally implemented `docs/requirements-spec.md` in full: an npm
workspaces TypeScript monorepo with a React/Vite/Fluent UI SPA, an Express + Zod API,
Cosmos DB for NoSQL, 342 unit and integration tests, five Playwright journeys, and
Bicep/azd deployment to Azure Container Apps. Two environments were deployed and
verified, the second with Entra ID enforcement and anonymous writes rejected.

The application was **not** defective. It built, its tests passed, and its deployment
was independently verified. §4 of the specification permits deviation from the locked
stack only when "a technical incompatibility is discovered and documented in an
Architecture Decision Record." **No such incompatibility was found, so that clause
does not apply here.** This decision is not a §4 deviation; it is the project owner
replacing the specification's premise.

The reason was about the demonstration, not the code. The audience for this work is an
executive one, and the argument being made is that Azure provides estate-wide
operational intelligence *natively*. A bespoke web application undermines that
argument: it invites the response "so you had to build something," and it places a
custom SPA between the audience and the Azure product. The project owner's direction
was explicit — rebuild on IaaS and native Azure Monitor, with the Azure Portal as the
only surface, and virtual machines rather than PaaS containers.

## Decision

Retire the Container Apps application. Rebuild the demonstration as a live Azure
estate observed entirely through first-party Azure surfaces:

- **Six Ubuntu virtual machines** (`Standard_D2ls_v7`) simulating the web, application
  and data tiers of a life-insurance estate, with the Azure Monitor Agent.
- **Log Analytics** with three Data Collection Rules, plus custom tables for the
  synthetic business layer, ingested through a real Data Collection Endpoint.
- **A five-tab workbook** as the primary demonstration surface, an Azure portal
  dashboard as the opening frame, real metric and scheduled-query alert rules, and an
  **Azure Automation runbook** implementing the human approval gate.
- **No custom application code of any kind.** Everything the audience sees is a native
  Azure experience.

Tear down both Container Apps deployments (`rg-uoi-demo`, `rg-uoi-uoi-demo`), also on
the project owner's explicit instruction.

## Consequences

### Accepted losses

- **§27's quality gates are unrunnable.** `npm install`, `lint`, `typecheck`, `test`,
  `build` and `test:e2e` have no code to act on. The 342 tests and five Playwright
  journeys are gone from the working tree. **The specification is superseded, not
  satisfied**, and no claim to the contrary should be made.
- **Documents mandated by §15, §24, §25 and §26 were deleted** — `security.md`,
  `demo-script.md`, `production-readiness.md`, `architecture.md`, `architecture.mmd`,
  `facilitator-guide.md` and `openapi.json` among them. They described an application
  that no longer exists.
- **ADR 0002 (AI fallback) is obsolete.** The `AIProvider` interface, the
  `AzureOpenAIProvider` and the `DeterministicDemoProvider` went with the application.
  The estate contains no Azure OpenAI resource. Correlation is now deterministic KQL.
  Natural-language analysis, where shown, uses the Observability agent built into the
  Azure Monitor Logs blade, which requires no provisioning.
- **ADR 0003 (telemetry normalization) is obsolete** as written. Normalization is now
  performed by Data Collection Rules and KQL rather than by TypeScript adapters.
- **The cost profile is materially worse.** The Container Apps environment scaled to
  zero and cost nothing idle. Six always-on VMs cost **$17.28/day**, roughly
  **$548/month** at 24×7. **This trade-off was not put to the project owner before
  deployment — that was an error.** No auto-shutdown schedule is configured.
  Deallocate between sessions.

### Retained

The constraints that were never about the stack remain binding, and are restated in
`README.md`:

- "150 related alerts correlated into 1 actionable incident" — never "false positives."
- Correlation does not prove causation.
- No autonomous remediation; a human approval gate, with approvals *and* refusals audited.
- No secrets anywhere; managed identity throughout.
- Every generated record carries `IsSynthetic`; all financials labelled
  "Illustrative Sample Data, not a customer estimate."
- The existing monitoring investment is never framed as a mistake.

### Reversibility

Complete. Commit **`c55ab2a`** on `origin/master` holds all 227 files of the
application and its tests. Nothing is lost; deleted work can be restored with
`git checkout c55ab2a -- <path>`.

## Process note

This ADR was written on 2026-09-17, a day after the decision it records, and only
after the gap was raised in review. The `docs/adr/` directory was deleted along with
the application rather than being extended with a supersession record. That was a
mistake: deleting the decision log destroyed the rationale for the very decisions
being reversed, leaving a repository in which a major architectural reversal had no
recorded justification.

ADRs 0001–0003 have since been restored from `c55ab2a` and marked superseded, which is
what should have happened at the time. Superseded decisions are marked, not deleted.
