# ADR 0003 — One canonical, OpenTelemetry-aligned telemetry schema behind source adapters

> **OBSOLETE since 2026-09-16 — see [ADR 0004](0004-supersede-container-apps-with-azure-native.md).**
> The TypeScript source adapters were retired with the application. Normalization is
> now performed by Azure Monitor Data Collection Rules and KQL against Log Analytics
> custom tables. The underlying idea — one canonical shape, populated from several
> sources, so correlation never depends on a vendor's field names — survives in the
> DCR transforms and the workbook queries.

- **Status:** Obsolete; approach re-expressed in DCRs/KQL (see ADR 0004)
- **Date:** 2026-09-12
- **Deciders:** Solution architecture (demo), SRE (demo role)
- **Spec references:** §2 Required demo outcomes, §3 Implementation principles, §5 Target architecture, §7 Canonical data model, §14 Synthetic monitoring story

## Context

The customer's operational signal is spread across Azure Monitor, Log Analytics, Application Insights,
Datadog, and on-premises Windows and Linux tooling. Each emits a different record shape, a different
severity vocabulary, and a different notion of "what broke."

Spec §2 requires vendor-neutral, OpenTelemetry-based telemetry normalization, and spec §5 requires that
"all adapters must convert incoming records into one canonical telemetry schema." Spec §3 requires that the
demo preserve an open, tool-neutral model and must not require a paid Datadog account — the third-party
source must be simulated through "an adapter that uses a documented mock contract."

The risk to avoid is a demo that claims tool neutrality while actually hard-coding one vendor's shape.

## Decision

1. **`TelemetryEvent` is the single canonical record** (spec §7) and is OpenTelemetry-aligned:
   - Resource identity maps to `serviceId`, `componentId`, `environment`, `region`.
   - Signal identity maps to `signalType` (`metric | log | trace | event | synthetic`), `metricName`,
     `metricValue`.
   - Trace context maps to `traceId` (W3C trace-id shape) and a demo-level `correlationId`.
   - Severity maps to a fixed five-level ordinal scale (`critical | high | medium | low | info`), derived
     from the OpenTelemetry severity number ranges.
   - Free-form vendor attributes are preserved in `tags` — normalization never destroys source fidelity.
   - `source` records the originating system and `sourceType` records its class
     (`azure-monitor | third-party-apm | onprem-windows | onprem-linux | application | synthetic-monitor`).
2. **Every ingress is an adapter** implementing `TelemetryAdapter`:
   `AzureMonitorAdapter`, `DatadogStyleAdapter`, `OnPremWindowsAdapter`, `OnPremLinuxAdapter`,
   `ApplicationTelemetryAdapter`, `SyntheticMonitorAdapter`. Each takes a documented, versioned mock source
   record and returns canonical `TelemetryEvent` / `Alert` records validated by the shared Zod schemas.
3. **The mock contracts are documented artifacts**, not incidental fixtures. Each adapter package exports
   its source-record schema, and `docs/data-dictionary.md` documents every field mapping. The Datadog-style
   adapter consumes a _Datadog-shaped_ mock contract; it never calls Datadog and never requires an account.
4. **Normalization is lossless and total.** Unknown severities map to `info` plus a
   `normalization.unmappedSeverity` tag rather than being dropped. Unknown fields are preserved under
   `tags`. Every adapter result is round-trip validated against `TelemetryEventSchema`.
5. **`schemaVersion` is explicit and versioned** on `TelemetryEvent`. Adapters stamp the schema version
   they produce, so a future breaking change is observable rather than silent.
6. **`isSynthetic` is mandatory and always `true`** for adapter output in this demo. The canonical schema
   makes it impossible to construct a record without the flag, which keeps the "Synthetic Demo Data"
   labeling guarantee (spec §3) a type-level property rather than a convention.
7. **Correlation, business impact, cost, and AI grounding consume only the canonical schema.** No engine may
   branch on `source` to recover vendor-specific semantics; if a behaviour is needed, it must be expressed
   as a canonical field.

## Consequences

**Positive**

- Adding a real source later is an adapter change only — no engine, API, or UI change.
- The correlation engine can correlate an Azure Monitor alert, a Datadog-style synthetic failure, and a
  Windows Event Log entry because they are the same shape with the same severity scale and trace context.
- The tool-neutrality claim in the executive narrative is demonstrable in code, not asserted in a slide.
- The demo genuinely needs no Datadog tenant.

**Negative**

- The canonical schema is a lowest-common-denominator across sources; vendor-specific richness lives in
  `tags` and is not first-class. Accepted for demo scope, documented in `docs/data-dictionary.md`.
- Severity mapping is a judgement call per source. Mitigated by making every mapping table explicit,
  exported, and unit-tested rather than embedded in adapter logic.

## Alternatives considered

| Alternative                                                    | Why rejected                                                                                                        |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Store raw vendor records and normalize at query time           | Pushes vendor coupling into every engine and the UI; makes correlation logic vendor-aware                           |
| Use the Azure Monitor / Log Analytics table shape as canonical | Contradicts the tool-neutral narrative and would make the third-party path a second-class citizen                   |
| Use raw OTLP protobuf structures as the internal model         | Unnecessary ceremony for a demo; OTLP remains the _wire_ concept while the canonical schema is the _domain_ concept |
| Per-source schemas with a union type                           | Every consumer would need exhaustive switch handling, and spec §5 requires one canonical schema                     |
