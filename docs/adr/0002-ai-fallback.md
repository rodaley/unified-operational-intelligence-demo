# ADR 0002 — AI is optional: provider abstraction with a deterministic default

> **OBSOLETE since 2026-09-16 — see [ADR 0004](0004-supersede-container-apps-with-azure-native.md).**
> The `AIProvider` interface, `AzureOpenAIProvider` and `DeterministicDemoProvider`
> were retired with the application. The current estate contains no Azure OpenAI
> resource; correlation is deterministic KQL, and natural-language analysis uses the
> Observability agent built into the Azure Monitor Logs blade. The principle below —
> that the demonstration must work with no AI service provisioned — still holds, and
> now holds trivially.

- **Status:** Obsolete; principle retained (see ADR 0004)
- **Date:** 2026-09-12
- **Deciders:** Solution architecture (demo), Responsible AI reviewer (demo role)
- **Spec references:** §3 Implementation principles, §4 Locked technology stack, §11 AI investigation service, §16 Reliability, §21 Test requirements

## Context

The demonstration includes an AI-assisted investigation experience (spec §11) and an Executive Copilot page
(spec §13G). However:

- Spec §3 requires that "Azure OpenAI is optional so the application remains demonstrable without model access."
- Spec §16 requires the core demo to remain usable when Azure OpenAI is not configured, when AI requests
  fail, and when external network access is unavailable.
- Spec §21 requires that tests must not need an actual Azure OpenAI deployment.
- An EBC demonstration cannot depend on a live model endpoint, a quota grant, or a regional capacity
  allocation that may not exist on the day.

At the same time the AI answers must be **grounded** — spec §11 restricts retrieval to the current incident,
related telemetry, the dependency map, approved runbooks, and prior synthetic incident reviews, and forbids
inventing evidence.

## Decision

1. **Define one interface, `AIProvider`**, with a single semantic operation (`investigate`) plus a
   `describe()` capability descriptor. Every answer is returned as a strongly typed, Zod-validated
   `AIInvestigationAnswer` containing: concise answer, evidence list, confidence level, uncertainties,
   recommended next action, generated-at timestamp, provider identifier, and the literal
   `"Synthetic Demo Data"` label.
2. **Ship two implementations:**
   - `DeterministicDemoProvider` — pure, offline, no network, no model. It composes answers by templating
     over the evidence bundle. It is the **default**.
   - `AzureOpenAIProvider` — Azure OpenAI via `DefaultAzureCredential` (Entra ID token, no API key), used
     only when `AZURE_OPENAI_ENDPOINT` **and** `AZURE_OPENAI_DEPLOYMENT` are both configured.
3. **The evidence bundle is built before, and independently of, provider selection.** Retrieval is
   performed by `EvidenceRetriever` against repository data only. The provider receives a closed evidence
   set and may not fetch anything else. This makes grounding a property of the architecture, not of a prompt.
4. **Post-validate every model answer.** `AzureOpenAIProvider` output is parsed with Zod and every cited
   evidence reference is checked against the evidence bundle. Any citation that is not in the bundle is
   dropped and recorded as an uncertainty. If validation leaves no supported evidence, the answer is
   replaced by the deterministic answer and marked as a fallback.
5. **Bounded fallback.** A timeout (default 12s), a bounded retry, and a simple circuit breaker wrap the
   Azure OpenAI call. Any error, timeout, or open circuit falls back to `DeterministicDemoProvider`.
   The fallback is always visible in the UI and emitted as a custom telemetry event.
6. **Insufficient evidence is a first-class answer.** When the evidence bundle cannot support a question,
   both providers return exactly `"Insufficient evidence in the demo dataset."`
7. **The AI service never executes remediation.** It may only _recommend_ actions. Remediation is gated by
   an explicit human approval endpoint (spec §3, §9, §15).

## Consequences

**Positive**

- The entire demo, including the Copilot page, runs with zero Azure OpenAI configuration.
- Tests are deterministic and offline; no model is required in CI or in Playwright.
- Grounding is enforced structurally, so an ungrounded claim cannot silently reach the executive audience.
- Provider selection and fallback usage are observable, which directly supports the production-readiness
  evidence requirements in spec §25.

**Negative**

- Deterministic answers are templated and therefore less fluent than model output. This is acceptable and
  is disclosed in the UI provider badge.
- Two answer-generation paths must be kept semantically aligned. Mitigated by a shared answer schema plus a
  shared test suite that runs the same grounding assertions against both providers.

## Alternatives considered

| Alternative                                         | Why rejected                                                                                                |
| --------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Require Azure OpenAI                                | Violates spec §3/§16/§21; makes the demo fragile on quota, region, and network                              |
| Record/replay fixtures of real model responses      | Still requires a model to produce the fixtures, and stale fixtures silently drift from the evidence         |
| Prompt-only grounding ("only use provided context") | Prompt instructions are not an enforcement mechanism; post-validation against a closed evidence set is      |
| Azure AI Search retrieval                           | Excluded by spec §5 for the deployable demo; documented as a production extension for large runbook corpora |
