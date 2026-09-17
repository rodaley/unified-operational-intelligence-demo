# ADR 0001 — Demo architecture: Container Apps, Cosmos DB for NoSQL, repository abstraction

> **SUPERSEDED on 2026-09-16 by [ADR 0004](0004-supersede-container-apps-with-azure-native.md).**
> The Container Apps application described here was retired on the project owner's
> instruction and its Azure deployments were torn down. Nothing below was found to be
> technically wrong — the demonstration strategy changed. Retained for the record;
> the implementation is in git history at `c55ab2a`.

- **Status:** Superseded by ADR 0004
- **Date:** 2026-09-12
- **Deciders:** Solution architecture (demo)
- **Spec references:** §3 Implementation principles, §4 Locked technology stack, §5 Target architecture, §23 Cost controls

## Context

"Unified Operational Intelligence" is a 15-minute executive briefing demonstration, not a production
operations platform. It must be deployable into a short-lived Azure environment by a single presenter,
cost-controlled, passwordless, and reliable enough to run live in front of executives.

The locked stack (spec §4) specifies Azure Container Apps, Azure Container Registry, and Azure Cosmos DB
for NoSQL. Spec §5 explicitly forbids requiring AKS, Azure SQL Database, Azure AI Search, Event Hubs,
Service Bus, a real Datadog tenant, or real on-premises infrastructure in the deployable version.

Two forces are in tension:

1. The demo must run against Azure Cosmos DB for NoSQL to be a credible Azure demonstration.
2. The demo must run on a presenter laptop, in CI, and in a Playwright run with **no** Azure dependency at
   all, because spec §16 requires the core demo to remain usable when external network access is
   unavailable.

## Decision

1. **Compute:** two Azure Container Apps (web and API) in a single Container Apps environment, fronted by
   the platform-managed ingress. Scale-to-zero minimum replicas by default (spec §23). No AKS.
2. **Data:** Azure Cosmos DB for NoSQL, single database, one container per aggregate
   (`telemetry`, `alerts`, `incidents`, `services`, `costs`, `knowledge`, `scenario`), partitioned by a
   field that matches the dominant read pattern. Serverless throughput is the default demo profile;
   provisioned throughput is a parameter.
3. **Persistence abstraction:** all engines and API routes depend on a narrow `DemoRepository` interface,
   never on the Cosmos SDK. Two implementations ship:
   - `InMemoryDemoRepository` — deterministic, zero-dependency, the default for local development, unit
     tests, integration tests, and the Playwright journey.
   - `CosmosDemoRepository` — `@azure/cosmos` + `DefaultAzureCredential`, selected when
     `COSMOS_ENDPOINT` is configured.
     Selection is environment-driven and logged at startup, so the presenter always knows which store is live.
4. **Identity:** the API Container App's system-assigned managed identity holds the Cosmos DB built-in data
   contributor role. No connection strings, no account keys, no Key Vault entry for data access.
5. **Simulated estate:** Azure App Service, Storage, Key Vault, an API Management-style gateway, Windows
   Server, IIS, Linux, an Oracle-style database, a VMware-style host and an enterprise identity service are
   represented purely as **data** in the dependency graph. None of them are deployed (spec §8).

## Consequences

**Positive**

- The demo deploys with `azd up` into a small, cheap, short-lived resource group.
- Unit, integration, and end-to-end tests run fully offline and deterministically.
- Swapping the store is a one-line environment change; no engine code is aware of Cosmos DB.
- Managed identity removes every data-plane secret from the solution.

**Negative**

- The in-memory repository and the Cosmos repository must be kept behaviourally consistent. Mitigated by a
  shared repository contract test suite that both implementations must satisfy.
- Cosmos DB for NoSQL has no server-side joins, so the dependency graph and correlation evidence are
  resolved in application code. Acceptable at demo data volumes (10,000 telemetry events by default).
- Scale-to-zero introduces a cold start on the first request after idle. Mitigated by the facilitator
  pre-demo checklist, which warms both apps.

## Alternatives considered

| Alternative                                      | Why rejected                                                                                                                                       |
| ------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Azure Kubernetes Service                         | Explicitly excluded by spec §5; disproportionate operational and cost overhead for a 15-minute demo                                                |
| Azure SQL Database                               | Explicitly excluded by spec §5 as a demo prerequisite; relational modelling is not needed for the demo's document-shaped aggregates                |
| Azure Static Web Apps + Functions                | Splits the runtime model, complicates OpenTelemetry correlation across web and API, and weakens the "one container image per app" deployment story |
| Cosmos DB emulator as the local default          | Not reliably installable across presenter machines and CI runners; retained as an optional local option, not the default (spec §4)                 |
| Event Hubs / Service Bus for telemetry ingestion | Explicitly excluded by spec §5; the demo ingests through in-process adapters and documents streaming as a production extension                     |

## Production extensions (documented, not implemented)

Event Hubs or Azure Monitor data collection endpoints for real ingestion, Azure AI Search for retrieval
over a large runbook corpus, private endpoints and network isolation, AKS if the customer's platform
standard requires it, and Azure SQL or Microsoft Fabric for long-horizon operational analytics. These are
described in `docs/architecture.md` and are not demo prerequisites.
