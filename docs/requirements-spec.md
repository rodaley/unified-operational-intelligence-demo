> **Status: superseded on 2026-09-16 — retained for the rules it still governs.**
>
> This document was the original contract for the build. The delivered
> demonstration no longer follows its technical stack: the TypeScript monorepo,
> React SPA, Express API, Cosmos DB and Azure Container Apps deployment it
> specifies were built, deployed, then retired on the project owner's explicit
> instruction in favour of a pure IaaS estate demonstrated directly through
> native Azure Monitor in the Azure Portal. That application source remains in
> the git history at `c55ab2a`. The decision, its rationale and its costs are
> recorded in
> [`adr/0004-supersede-container-apps-with-azure-native.md`](adr/0004-supersede-container-apps-with-azure-native.md).
> See [`../README.md`](../README.md) and
> [`demo-azure-portal.md`](demo-azure-portal.md) for what is actually deployed.
>
> **Sections no longer in force:** §4 (locked stack), §6 (repository layout),
> §7 (shared contracts), §26 (mandated documents) and §27 (quality gates). The
> gates in §27 are unrunnable because the code they validate no longer exists,
> and **this specification is superseded, not satisfied.** No claim that §27
> passes should be made.
>
> **What remains binding:** the narrative discipline, labelling requirements,
> approval-gate requirement, no-secrets rule and honesty requirements — in
> particular that no requirement may be reported as passing unless the
> validation command was run and its output inspected. Where this document and
> the README disagree on architecture, the README is correct.
>
> One figure has changed: the correlated-alert headline is **150**, not the
> number used in earlier drafts. The number on screen must match the number
> spoken aloud.

---

You are a principal Azure architect, senior full-stack engineer, site reliability engineer, security engineer, and executive-demo designer.

Build a complete, deployable Azure demonstration named:

Unified Operational Intelligence

This is an executive EBC demonstration for a large life insurance company operating a hybrid environment across Azure and on-premises infrastructure.

Do not produce only an architecture proposal or sample snippets. Create the complete repository, application code, infrastructure-as-code, synthetic data generator, automated tests, deployment workflow, documentation, and executive demonstration script.

==================================================

1. BUSINESS CONTEXT
   \==================================================

The customer currently uses:

- Azure Monitor
- Log Analytics
- Application Insights in selected applications
- Datadog for synthetic monitoring and other operational scenarios
- On-premises monitoring tools

Azure Monitor alerts are currently configured primarily for Azure managed services.

Log Analytics currently ingests:

- Azure managed-service diagnostic logs
- Virtual machine performance data
- Windows Event Logs
- IIS logs
- Linux Syslog
- Custom application logs

The data is used for troubleshooting and auditing.

Datadog was originally adopted because the organization required synthetic monitoring. Monitoring capabilities have since become distributed across platforms, resulting in:

- No company-wide integrated operational dashboard
- Multiple sources of operational truth
- Slow outage impact assessment
- Alert fatigue
- Rising third-party monitoring costs
- Difficulty correlating infrastructure, application, and business-service impact
- An advanced incident-response PoC without finalized production-adoption criteria

The demo must show how Azure can provide a unified operational intelligence layer while preserving an open, tool-neutral telemetry model.

The narrative must not claim that every third-party monitoring capability should be replaced. It must demonstrate a rationalization framework based on operational requirements, incremental value, governance, and total cost of ownership.

================================================== 2. REQUIRED DEMO OUTCOMES
==================================================

The completed solution must demonstrate:

1. Unified visibility across simulated Azure, on-premises, and third-party monitoring sources.
2. OpenTelemetry-based, vendor-neutral telemetry normalization.
3. Correlation of many alerts into one actionable incident.
4. AI-assisted root-cause analysis grounded only in demo data.
5. Mapping of technical incidents to business-service impact.
6. Human approval before any remediation action.
7. Automatic generation of a post-incident review.
8. Comparison of current-state and target-state monitoring costs using clearly labeled fictional data.
9. Measurable production-readiness criteria for AIOps.
10. A repeatable Azure deployment using Azure Developer CLI and Bicep.

================================================== 3. IMPLEMENTATION PRINCIPLES
==================================================

Follow these principles:

- Prefer the smallest reliable architecture that supports the story.
- Use managed Azure services.
- Avoid unnecessary services and architectural complexity.
- Use passwordless authentication and managed identities wherever supported.
- Never store secrets in source code, configuration files, sample data, or GitHub Actions.
- Use OpenTelemetry for application instrumentation.
- Separate synthetic demo data from actual Azure platform telemetry.
- Clearly label all generated information as "Synthetic Demo Data."
- Clearly label all fictional financial information as "Illustrative Sample Data."
- Do not require a paid Datadog account.
- Simulate Datadog events through an adapter that uses a documented mock contract.
- Make Azure OpenAI optional so the application remains demonstrable without model access.
- Do not claim that statistical correlation proves causation.
- Do not implement autonomous production remediation.
- Require explicit human approval for all simulated remediation.
- Do not deploy preview Azure features unless they are isolated behind an optional feature flag and disabled by default.
- Do not use real customer names, personal information, credentials, account numbers, policy numbers, or production data.

================================================== 4. LOCKED TECHNOLOGY STACK
==================================================

Use the following stack unless a technical incompatibility is discovered and documented in an Architecture Decision Record.

Monorepo:

- npm workspaces
- TypeScript
- Node.js 22 LTS

Frontend:

- React
- TypeScript
- Vite
- Fluent UI React Components
- React Router
- TanStack Query
- Recharts for charts
- React Flow for the service-dependency map

Backend:

- Node.js
- TypeScript
- Express
- Zod for request and environment validation
- Pino for structured application logging
- OpenAPI 3.1 specification

Primary demo database:

- Azure Cosmos DB for NoSQL

Local development database:

- Cosmos DB emulator if practical
- Otherwise an in-memory repository with deterministic seed files

AI:

- Azure OpenAI through an abstraction layer
- Retrieval limited to the selected incident, telemetry evidence, runbooks, and prior synthetic post-incident reviews
- Deterministic fallback summarizer when Azure OpenAI is unavailable

Hosting:

- Azure Container Apps
- Azure Container Registry

Observability:

- Azure Monitor
- Log Analytics
- Application Insights
- OpenTelemetry SDK
- Azure Monitor OpenTelemetry exporter or supported Azure Monitor distribution

Secrets and identity:

- Microsoft Entra ID
- Managed identities
- Azure Key Vault only where a secret cannot be eliminated

Infrastructure:

- Bicep
- Azure Developer CLI
- Azure Verified Modules where suitable and stable

CI/CD:

- GitHub Actions
- Federated identity with Azure
- No client secrets

Testing:

- Vitest
- React Testing Library
- Supertest
- Playwright
- Bicep build validation
- ESLint
- Prettier
- TypeScript strict mode

================================================== 5. TARGET ARCHITECTURE
==================================================

Create this logical architecture:

Browser
-> React executive dashboard
-> Express API
-> Cosmos DB

Express API
-> Incident and telemetry repository
-> Correlation engine
-> Business-impact engine
-> Cost-model engine
-> AI investigation service
-> Post-incident review generator

Application and API
-> OpenTelemetry
-> Application Insights
-> Log Analytics

Synthetic-source adapters:
-> Azure Monitor adapter
-> Datadog-style adapter
-> On-premises Windows adapter
-> On-premises Linux adapter
-> Application telemetry adapter

All adapters must convert incoming records into one canonical telemetry schema.

The initial deployable version must not require:

- AKS
- Azure SQL Database
- Azure AI Search
- Event Hubs
- Service Bus
- A real Datadog tenant
- Real on-premises infrastructure

Document these as potential production extensions, not demo prerequisites.

================================================== 6. REPOSITORY STRUCTURE
==================================================

Create this repository structure:

/
apps/
web/
api/
packages/
contracts/
demo-data/
correlation-engine/
business-impact/
cost-model/
ai-provider/
telemetry-adapters/
ui-components/
infra/
main.bicep
main.parameters.json
modules/
scripts/
seed-demo-data.ts
reset-demo.ts
inject-incident.ts
validate-deployment.ts
smoke-test.ts
docs/
architecture.md
architecture.mmd
demo-script.md
facilitator-guide.md
production-readiness.md
security.md
cost-notes.md
data-dictionary.md
api.md
troubleshooting.md
adr/
tests/
e2e/
.github/
workflows/
azure.yaml
package.json
README.md
SECURITY.md
CONTRIBUTING.md
LICENSE

Also create:

- .env.example
- .gitignore
- .editorconfig
- eslint configuration
- prettier configuration
- tsconfig base configuration
- Dependabot configuration
- CodeQL workflow

Do not place secrets or real connection strings in .env.example.

================================================== 7. CANONICAL DATA MODEL
==================================================

Define strongly typed, versioned schemas using TypeScript and Zod.

Required entities:

TelemetryEvent:

- id
- schemaVersion
- timestamp
- source
- sourceType
- environment
- region
- serviceId
- componentId
- signalType
- metricName
- metricValue
- severity
- message
- traceId
- correlationId
- tags
- isSynthetic

Alert:

- id
- timestamp
- source
- ruleName
- severity
- serviceId
- componentId
- signalType
- status
- fingerprint
- correlationId
- isSuppressed
- suppressionReason
- isSynthetic

Incident:

- id
- title
- startTime
- detectedTime
- acknowledgedTime
- resolvedTime
- severity
- status
- rootCauseStatus
- probableRootCause
- confidence
- affectedServiceIds
- relatedAlertIds
- relatedTelemetryIds
- businessImpact
- recommendedActions
- humanApprovalStatus
- isSynthetic

BusinessService:

- id
- name
- description
- ownerRole
- dependencies
- criticality
- customerJourney
- recoveryObjective
- isSynthetic

CostRecord:

- id
- month
- category
- provider
- ingestionVolumeGb
- retentionDays
- estimatedCost
- currency
- assumptions
- isIllustrative

KnowledgeArticle:

- id
- incidentId
- title
- summary
- timeline
- rootCause
- correctiveActions
- evidenceReferences
- approvalStatus
- isSynthetic

All APIs must validate payloads using the shared Zod schemas.

================================================== 8. SYNTHETIC DEMO DATA
==================================================

Generate deterministic synthetic data using a configurable seed.

Do not create all records at application startup. Use a dedicated seeding script and idempotent upsert behavior.

Generate:

- 90 days of summary-level historical data
- 10,000 detailed telemetry events by default
- 500 alerts
- 100 incidents
- 20 major incidents
- 5 business applications
- 12 infrastructure components
- 5 synthetic-monitor locations
- Monthly illustrative monitoring-cost records

Allow scale profiles:

- small
- standard
- large

The standard profile is the default.

Required business applications:

1. Customer Portal
2. Claims Processing
3. Billing Platform
4. Agent Portal
5. Policy Administration System

Required simulated infrastructure:

Azure:

- App Service
- Container Apps
- Azure SQL-style dependency
- Storage Account
- Key Vault
- API Management-style gateway

On-premises:

- Windows Server
- IIS
- Linux Server
- Oracle-style database dependency
- VMware-style host
- Enterprise identity service

Do not deploy these simulated infrastructure components. Represent them as data and dependencies in the demo.

Every record must visibly identify itself as synthetic.

================================================== 9. INCIDENT SCENARIOS
==================================================

Implement at least four deterministic scenarios:

Scenario A:
Claims Processing database latency

Scenario B:
Agent Portal authentication failure

Scenario C:
Policy Renewal API degradation

Scenario D:
Customer Portal synthetic-monitor failure

The primary EBC scenario must be Scenario A.

When the presenter selects "Create Major Incident," the application must:

1. Reset the primary scenario to a known baseline.
2. Start a server-side scenario state machine.
3. Generate a progressive incident timeline.
4. Inject at least 150 related alerts across simulated sources.
5. Show database latency as the probable initiating condition.
6. Show downstream API failures.
7. Show queue buildup.
8. Show synthetic-monitor failures.
9. Correlate the alerts into one incident.
10. Calculate affected business services.
11. Show illustrative customer and financial impact.
12. Generate suggested operator actions.
13. Require human approval before simulated remediation.
14. Resolve the incident after the presenter approves remediation.
15. Generate a draft post-incident review.

The scenario must support:

- Start
- Pause
- Resume
- Advance to next phase
- Auto-play
- Reset

Do not depend on real-time timing during the presentation. The presenter must be able to advance each phase manually.

================================================== 10. ALERT CORRELATION ENGINE
==================================================

Implement an explainable deterministic correlation engine before adding AI.

Use these factors:

- Temporal proximity
- Shared service dependency
- Shared trace or correlation ID
- Alert fingerprint similarity
- Parent-child topology
- Common probable cause
- Recurring historical pattern

The engine must output:

- Correlated incident ID
- Included alerts
- Suppressed alerts
- Correlation reasons
- Confidence score
- Evidence references

For the main scenario, demonstrate the reduction of at least 150 alerts into one operational incident.

The UI must not describe this as 150 false positives. Some alerts are valid symptoms. Describe the outcome as:

"150 related alerts correlated into 1 actionable incident."

Show:

- Raw alert count
- Unique incident count
- Suppressed duplicate count
- Related symptom count
- Correlation explanation

================================================== 11. AI INVESTIGATION SERVICE
==================================================

Create an AIProvider interface with two implementations:

1. AzureOpenAIProvider
2. DeterministicDemoProvider

The deterministic provider must work with no Azure OpenAI deployment.

The AI investigation experience must answer:

- What happened?
- What is the probable root cause?
- Which systems are affected?
- What evidence supports the conclusion?
- What is the business impact?
- What should the operator do next?
- What remains uncertain?
- Should leadership be notified?
- Summarize the incident for an executive.

Ground answers only in:

- Current incident data
- Related telemetry
- Dependency map
- Approved runbooks
- Prior synthetic incident reviews

Every answer must include:

- Concise answer
- Evidence list
- Confidence level
- Uncertainties
- Recommended next action
- Generated-at timestamp
- "Synthetic Demo Data" label

The model must be instructed not to invent evidence.

If evidence is insufficient, it must state:

"Insufficient evidence in the demo dataset."

The AI service must not execute remediation.

================================================== 12. BUSINESS-IMPACT ENGINE
==================================================

Create a configurable dependency graph mapping:

Infrastructure component
-> Application component
-> Business service
-> Customer journey
-> Illustrative financial impact

For Scenario A, show:

Probable initiating condition:

- Claims database latency

Technical symptoms:

- Increased API response time
- Request failures
- Queue growth
- Synthetic-monitor failures

Business service:

- Claims Processing

Illustrative affected users:

- 12,000

Illustrative financial impact:

- USD 175,000

All impact numbers must be prominently labeled:

"Illustrative Sample Data"

Document exactly how the demo calculates impact.

Do not present the impact as a prediction from real customer data.

================================================== 13. EXECUTIVE DASHBOARD
==================================================

Build a polished but restrained executive UI.

Avoid visual clutter, excessive animation, and overly technical language.

Required pages:

A. Executive Overview

Display:

- Overall service-health score
- Active major incidents
- Mean time to detect
- Mean time to resolve
- Alert-to-incident reduction
- Services at risk
- Estimated monitoring spend
- Estimated optimization opportunity
- Azure Monitor coverage
- Third-party-tool coverage

B. Unified Observability Map

Display:

- Business applications
- Components
- Azure services
- Simulated on-premises dependencies
- Simulated third-party signals
- Dependency edges
- Current health
- Active incident path
- Business-impact path

Provide filters for:

- Business service
- Platform
- Environment
- Severity
- Source

C. Incident Command Center

Display:

- Incident timeline
- Related alerts
- Correlation explanation
- Probable root cause
- Supporting evidence
- Business impact
- Recommended actions
- Human approval control
- Post-incident review status

D. AIOps Insights

Display:

- Detected anomalies
- Correlated alert groups
- Repeated incident patterns
- Suggested runbooks
- Confidence scores
- Unresolved uncertainty
- Automation-candidate classification

E. Tool Rationalization

Display a decision framework across:

- Azure-native monitoring
- Application performance monitoring
- Synthetic monitoring
- Hybrid infrastructure
- Audit and troubleshooting
- Cross-platform visibility
- Data portability
- Operational workflow
- Estimated cost
- Unique business value

Do not create a biased vendor scorecard.

Present:

- Standardize
- Retain
- Integrate
- Retire
- Investigate

as recommendation categories using illustrative demo assumptions.

F. Cost Optimization

Show illustrative current-state and target-state values.

Default sample values:

- Third-party annualized monitoring cost: USD 950,000
- Azure-native annualized monitoring cost: USD 410,000
- Illustrative optimization opportunity: USD 540,000

Prominently label every financial visual:

"Illustrative Sample Data, not a customer estimate."

Allow the presenter to change:

- Daily ingestion volume
- Retention period
- Duplicate ingestion percentage
- Sampling percentage
- Archive percentage
- Third-party coverage percentage

Recalculate the illustration using documented formulas.

G. Executive Copilot

Provide suggested prompts and an evidence panel.

The experience must default to the current incident and never answer from unrestricted external knowledge.

================================================== 14. SYNTHETIC MONITORING STORY
==================================================

Implement simulated synthetic probes for:

- Customer login
- Submit insurance claim
- Retrieve claim status
- Agent sign-in
- Policy renewal

Show:

- Probe location
- Availability
- Response time
- Failed step
- Screenshot placeholder
- Related trace ID
- Related business service

The demo must acknowledge that synthetic monitoring was a legitimate reason for adopting Datadog.

The demo narrative should ask:

- Is synthetic monitoring still a differentiated requirement?
- Is the capability duplicated?
- Where should synthetic results be integrated?
- Which platform should be the operator's starting point?
- What is the incremental value relative to cost?

Do not frame the original Datadog decision as a mistake.

================================================== 15. SECURITY REQUIREMENTS
==================================================

Implement:

- Microsoft Entra ID authentication for the deployed environment
- A local-development authentication bypass enabled only in development
- Role definitions for Viewer, Operator, and Demo Administrator
- Managed identity from Container Apps to Cosmos DB and supported Azure resources
- Key Vault only if a secret is unavoidable
- Secure HTTP headers
- Restricted CORS
- Request size limits
- Input validation
- Rate limiting on AI endpoints
- Correlation IDs
- Structured audit events for scenario actions
- No sensitive data in logs
- No secrets in browser bundles
- No connection strings returned from APIs
- No publicly writable endpoints
- Least-privilege RBAC assignments
- User-facing confirmation before scenario reset or remediation approval

Create docs/security.md containing:

- Threat model
- Trust boundaries
- Identity flow
- Data classification
- Secret-management approach
- Logging policy
- Known demo limitations
- Production-hardening recommendations

================================================== 16. RELIABILITY REQUIREMENTS
==================================================

Implement:

- Health endpoint
- Readiness endpoint
- Graceful shutdown
- Cosmos DB retry handling
- Request timeouts
- AI-provider timeouts
- Circuit breaker or bounded fallback for optional AI calls
- Idempotent seeding
- Idempotent incident injection
- Scenario reset
- Browser refresh recovery
- Empty-state UI
- Error boundaries
- Friendly failure messages
- Deterministic fallback if Azure OpenAI is unavailable

The core demo must remain usable when:

- Azure OpenAI is not configured
- AI requests fail
- External network access is unavailable
- The presenter resets the scenario repeatedly

================================================== 17. ACCESSIBILITY AND UX
==================================================

Meet WCAG 2.2 AA where practical.

Include:

- Keyboard navigation
- Visible focus states
- Semantic landmarks
- Accessible chart summaries
- Color-independent status indicators
- Screen-reader labels
- Reduced-motion support
- Responsive layouts
- High-contrast compatibility

Do not rely on red and green alone.

================================================== 18. INFRASTRUCTURE-AS-CODE
==================================================

Create Bicep modules for:

- Resource group-scoped deployment
- Log Analytics workspace
- Application Insights
- Azure Container Registry
- Container Apps environment
- Web container app
- API container app
- Cosmos DB account and database
- Key Vault if required
- Managed identities
- RBAC
- Diagnostic settings
- Alerts
- Budget and cost-alert configuration
- Optional Azure OpenAI integration parameters

Use secure parameters.

Infrastructure must support:

- Environment name
- Azure region
- Resource naming prefix
- Tags
- Container image references
- Minimum and maximum replicas
- Cosmos DB throughput profile
- Log-retention setting
- Azure OpenAI enabled or disabled
- Authentication enabled or local-demo mode

Use outputs only for non-secret values.

Run Bicep validation and linting.

================================================== 19. AZURE DEVELOPER CLI
==================================================

Create:

- azure.yaml
- environment-variable requirements
- post-provision hook
- post-deploy seed hook
- validation hook
- README deployment instructions

The intended deployment flow must be:

azd auth login
azd init
azd env new
azd up

If additional commands are required, document them clearly and automate them where practical.

After deployment:

1. Seed synthetic demo data.
2. Validate API health.
3. Validate web availability.
4. Validate Application Insights connectivity.
5. Print the deployed application URL.
6. Print the location of the demo script.
7. Never print secrets.

================================================== 20. GITHUB ACTIONS
==================================================

Create workflows for:

Pull requests:

- Install dependencies
- Check formatting
- Lint
- Type-check
- Run unit tests
- Run API integration tests
- Build web and API
- Validate OpenAPI
- Build Bicep
- Run dependency audit
- Run CodeQL where applicable

Main branch:

- Run all validation
- Build container images
- Push to Azure Container Registry
- Deploy with Azure Developer CLI or Bicep
- Run post-deployment smoke tests

Use GitHub-to-Azure workload identity federation.

Do not use stored Azure client secrets.

Document required GitHub environments, variables, permissions, and protection rules.

================================================== 21. TEST REQUIREMENTS
==================================================

Create tests for:

- Telemetry schema validation
- Adapter normalization
- Correlation rules
- Business-impact calculation
- Cost-model formulas
- Scenario state transitions
- Incident reset
- AI fallback behavior
- Evidence grounding
- Authorization decisions
- API endpoints
- Core React components
- Main presenter journey

Required Playwright journey:

1. Open Executive Overview.
2. Confirm synthetic-data banner.
3. Start Claims Processing incident.
4. Advance through detection.
5. Open correlated incident.
6. Confirm 150 or more related alerts.
7. Confirm one actionable incident.
8. Review probable root cause and evidence.
9. Review business impact.
10. Approve simulated remediation.
11. Resolve the incident.
12. Open generated post-incident review.
13. Reset the demo.

Tests must not require an actual Azure OpenAI deployment.

================================================== 22. OBSERVABILITY FOR THE DEMO ITSELF
==================================================

Instrument the web and API applications.

Capture:

- HTTP requests
- Dependencies
- Exceptions
- Custom events
- Scenario transitions
- Incident injections
- Correlation duration
- AI-provider selection
- AI request duration
- AI fallback usage
- Demo reset events

Do not log:

- Tokens
- Secrets
- Authorization headers
- Full AI prompts containing user-entered data
- Personal information

Create example KQL queries for:

- Failed requests
- Slow API calls
- Scenario activity
- AI fallback rate
- Correlation latency
- Incident injection errors

Create at least:

- One application-health alert
- One server-error alert
- One latency alert

All monitoring artifacts must be included in Bicep where supported.

================================================== 23. COST CONTROLS
==================================================

Design for a low-cost, short-lived demonstration environment.

Implement:

- Minimum practical service tiers
- Scale-to-zero where supported
- Low default retention
- Configurable Cosmos DB throughput
- No unnecessary private endpoints in the default demo profile
- An optional hardened-production profile
- Azure budget alert
- Resource tags
- Teardown instructions

Create docs/cost-notes.md with:

- Deployed services
- Primary cost drivers
- Demo-profile assumptions
- Cost-reduction options
- Teardown procedure

Do not invent exact Azure pricing.

================================================== 24. EXECUTIVE DEMO SCRIPT
==================================================

Create docs/demo-script.md for a 15-minute EBC demonstration.

Use this structure:

0:00-2:00
Customer context and current-state challenge

2:00-4:00
Unified observability view

4:00-6:00
Inject Claims Processing incident

6:00-9:00
Alert correlation and root-cause investigation

9:00-11:00
Business-impact analysis

11:00-13:00
Human-approved remediation and post-incident review

13:00-14:00
Tool rationalization and illustrative cost model

14:00-15:00
Production-readiness framework and close

For each segment include:

- Presenter action
- Expected screen
- Suggested words
- Key message
- Business outcome
- Optional customer question
- Recovery step if the demo action fails

The speaker narrative must include:

"The objective is not to eliminate tools. The objective is to eliminate operational blind spots and accelerate decisions."

Also include:

"The original decision to adopt synthetic monitoring addressed a valid business requirement. The question now is whether today's capability, operating model, and cost structure still justify the same platform boundaries."

End with:

"The future state is not more dashboards. It is faster, evidence-based operational decisions with appropriate human control."

================================================== 25. PRODUCTION-READINESS FRAMEWORK
==================================================

Create docs/production-readiness.md.

Define readiness gates in these categories:

Technical:

- Detection precision
- Correlation quality
- Evidence completeness
- Service reliability
- Security controls

Operational:

- Runbook coverage
- Operator acceptance
- Escalation routes
- Human approval
- Support ownership
- Auditability

Business:

- MTTD improvement
- MTTR improvement
- Alert-volume reduction
- Incident-impact reduction
- Operator-effort reduction
- Cost optimization

Governance:

- Model and prompt versioning
- Evaluation dataset
- Change approval
- Rollback
- Data retention
- Responsible AI review

Each gate must have:

- Definition
- Evidence required
- Pass criteria
- Owner role
- Review cadence
- Rollback trigger

Clearly label the thresholds as sample recommendations that must be adapted to the customer's environment.

================================================== 26. DOCUMENTATION
==================================================

README.md must include:

- Business story
- Architecture summary
- Prerequisites
- Local setup
- Azure deployment
- Entra ID setup
- Optional Azure OpenAI setup
- Demo-data seeding
- Incident injection
- Demo reset
- Test commands
- Troubleshooting
- Resource cleanup
- Security disclaimer
- Synthetic-data disclaimer

docs/facilitator-guide.md must include:

- Pre-demo checklist
- Browser setup
- Data-reset procedure
- Backup demo path
- Known limitations
- Suggested executive questions
- Q&A guidance
- Post-demo cleanup

docs/architecture.md must include:

- Logical architecture
- Azure resource architecture
- Identity flow
- Telemetry flow
- Incident flow
- AI grounding flow
- Deployment flow
- Production-extension options

Create a Mermaid architecture diagram in docs/architecture.mmd.

================================================== 27. REQUIRED QUALITY GATES
==================================================

The implementation is complete only when:

- npm install succeeds.
- npm run lint succeeds.
- npm run typecheck succeeds.
- npm test succeeds.
- npm run build succeeds.
- npm run test:e2e succeeds against a local environment.
- Bicep builds successfully.
- The OpenAPI document validates.
- The synthetic seed process is idempotent.
- The primary incident can be reset and replayed.
- The application functions without Azure OpenAI.
- No secrets are committed.
- The README deployment steps match the generated files.
- All fictional values are clearly labeled.
- All user-visible major workflows have accessible names.
- The core demo can be deployed using azd up.

Do not state that a requirement passes unless you actually run the relevant validation command and inspect the result.

================================================== 28. IMPLEMENTATION PHASES
==================================================

Work in the following order.

Phase 1:

- Inspect repository.
- Create implementation plan.
- Create architecture decision records.
- Scaffold monorepo.
- Define shared contracts.

Phase 2:

- Implement deterministic seed generator.
- Implement repositories.
- Implement telemetry adapters.
- Implement correlation engine.
- Add tests.

Phase 3:

- Implement API.
- Generate OpenAPI specification.
- Add authentication and authorization abstractions.
- Add integration tests.

Phase 4:

- Implement executive web application.
- Implement all required pages.
- Add accessibility features.
- Add component tests.

Phase 5:

- Implement scenario state machine.
- Implement presenter's controls.
- Add Playwright test.

Phase 6:

- Implement Azure OpenAI provider.
- Implement deterministic fallback provider.
- Add evidence-grounding tests.

Phase 7:

- Add OpenTelemetry instrumentation.
- Add Application Insights integration.
- Add monitoring queries and alerts.

Phase 8:

- Create Bicep and Azure Developer CLI configuration.
- Add managed identities and RBAC.
- Validate Bicep.

Phase 9:

- Add GitHub Actions.
- Add security workflows.
- Complete documentation and demo script.

Phase 10:

- Run all quality gates.
- Fix failures.
- Produce final implementation report.

At the end of each phase:

1. Summarize files created or changed.
2. Run the relevant validations.
3. Report actual validation results.
4. Fix failures before continuing.
5. Commit logically related changes if repository permissions allow.

Do not stop after scaffolding.

================================================== 29. FINAL IMPLEMENTATION REPORT
==================================================

When complete, provide:

- Architecture summary
- Repository tree
- Azure resources created
- Local-run commands
- Azure-deployment commands
- Test results
- Security controls implemented
- Demo flow
- Known limitations
- Optional production enhancements
- Cleanup command

Explicitly distinguish:

- Implemented and tested
- Implemented but not Azure-validated
- Optional
- Not implemented

Never claim that Azure deployment succeeded unless the deployment command completed successfully.

================================================== 30. START NOW
==================================================

Begin by inspecting the repository.

Then create:

1. docs/implementation-plan.md
2. docs/adr/0001-architecture.md
3. docs/adr/0002-ai-fallback.md
4. docs/adr/0003-telemetry-normalization.md
5. The monorepo structure
6. Shared TypeScript and Zod contracts
7. The first passing unit tests

Continue through every implementation phase without waiting for additional confirmation unless access credentials or an Azure subscription are technically required.

If Azure credentials are unavailable, complete and validate everything that can run locally, validate the Bicep statically, and clearly document the unexecuted Azure deployment step.
