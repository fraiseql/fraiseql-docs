# Phase 08: Sweep, link audit, SDK reconciliation

## Objective

Re-walk every remaining doc page that hasn't been touched by phases 03–07, verify it against the v2.3.2 framework, fix what's wrong, link it into the new content, regenerate screenshots, and reconcile the SDK status tables with `roadmap.md`.

## Why this exists

Phases 03–07 produced a lot of new content. The rest of the site needs to harmonise: cross-links updated, version references cleaned, dead links repaired, and any "the old way said X" prose either updated or removed. This is also where SDK status reconciliation and screenshot regen happen — chores that don't fit elsewhere but cannot be skipped.

## Success criteria

- [ ] Every page in `src/content/docs/` has been **read in its entirety** by a human/agent during this phase and either:
  - left as-is (state: OK in sweep matrix), or
  - patched in a small commit covering this phase, or
  - flagged for a larger rewrite (which gets done in this phase if small, deferred to a follow-on if large).
- [ ] All cross-links to phase 03–07 pages exist (bidirectional where appropriate).
- [ ] Sidebar reflects the IA decision from phase 01 with every new page wired in.
- [ ] SDK status pages match `roadmap.md`'s status table:
  - Functional SDKs: Python, TypeScript, Go, Java, Kotlin, Scala, Swift, PHP, Rust, C#.
  - Not started: Elixir, F#.
  - Other languages (Clojure, Dart, Groovy, Ruby) — current status sourced from source (cross-SDK CI matrix) and stated truthfully.
- [ ] Screenshots regenerated where the underlying UI changed.
- [ ] External links re-audited (since phase 01).
- [ ] `index.mdx` and `concepts/why-fraiseql.md` reviewed for stale claims.
- [ ] Sweep matrix shows every row at status `OK`.

## Scope (in)

### Pages to verify (not previously touched)

- `index.mdx`
- `analytics-architecture.mdx`
- `community/code-of-conduct.md`, `community/contributing.md`, `community/support.md`
- `concepts/configuration.md`, `concepts/cqrs.mdx`, `concepts/developer-owned-sql.mdx`, `concepts/elo-validation.md`, `concepts/how-it-works.mdx`, `concepts/mutations.mdx`, `concepts/schema.md`, `concepts/type-system.md`, `concepts/view-composition.mdx`, `concepts/why-fraiseql.md`
- `confiture/*` (5 pages)
- `databases/*` (5 pages)
- `deployment/*` (7 pages)
- `diagrams/architecture.md`
- `examples/*` (9 pages)
- `features/analytics.md`, `features/apq.md`, `features/arrow-dataplane.md`, `features/audit-logging.mdx`, `features/automatic-where.mdx`, `features/caching.md`, `features/encryption.md`, `features/federation.md`, `features/function-shapes.md`, `features/multi-database.mdx`, `features/mutual-exclusivity.mdx`, `features/nats.md`, `features/oauth-providers.md`, `features/observability.md`, `features/pagination.md`, `features/rate-limiting.md`, `features/resilience.md`, `features/rich-filters.mdx`, `features/security.md`, `features/subscriptions.md` (sanity check — phase 04 added the realtime subsystem page; subscriptions remains the protocol page), `features/webhooks.md`, `features/wire-protocol.md`
- `getting-started/first-api.mdx`, `getting-started/first-hour.mdx`, `getting-started/installation.md`, `getting-started/introduction.md`, `getting-started/quickstart.mdx`
- `guides/advanced-federation.md`, `guides/advanced-nats.md`, `guides/advanced-patterns.mdx`, `guides/apollo-sandbox-security.md`, `guides/custom-resolvers.md`, `guides/custom-scalars.md`, `guides/deployment.md`, `guides/error-handling.md`, `guides/faq.md`, `guides/federation-configuration.md`, `guides/federation-nats-integration.md`, `guides/index.md`, `guides/observer-webhook-patterns.md`, `guides/performance-benchmarks.md`, `guides/performance.md`, `guides/schema-design.md`, `guides/testing.md`, `guides/troubleshooting.md`
- `migrations/from-apollo.md`, `migrations/from-hasura.md`, `migrations/from-prisma.md`, `migrations/from-rest.md`, `migrations/index.md`
- `reference/scalars.md`, `reference/semantic-scalars.md`, `reference/decorators.md`, `reference/graphql-api.md`, `reference/naming-conventions.md`, `reference/validation-rules.md`
- `sdk/*` (16 pages)
- `tools/schema-validator.mdx`
- `troubleshooting/*` (5 pages + 4 by-database subpages)
- `vs/apollo.md`, `vs/hasura.md`, `vs/prisma.md`

(That's ~110 pages — every page that isn't owned by an earlier phase.)

## Scope (out)

- Pages already finalised by phases 03–07.
- Adding new top-level sections.
- Full rewrites of pages that need them — those get a row in the follow-up plan.

## Dependencies

- **Requires:** Phases 03–07. All cross-link targets must exist before this phase starts.
- **Blocks:** Phase 09 (which expects every framework bug surfaced during the overhaul to be known by this point).

## Personas involved

This phase has different shape than 03–07: it's mostly verification of pre-existing pages, not new content. Read-heavy, edit-light.

| Cycle | Personas |
|-------|----------|
| 1–7 (sweeps by sidebar group) | Reviewer-style read (Opus 4.7 — judgement: "is this page OK or does it need a flag?") → Cleanup (Sonnet 4.6) for patches; → Writer (Opus 4.7) only for pages flagged needing >25 lines of rewrite |
| 8 (Screenshot regen) | Cleanup (mechanical) |
| 9 (External link re-audit) | Link Auditor (Haiku 4.5) → Cleanup |
| 10 (Sweep matrix close-out) | Cleanup |
| 11 (style audit) | Style Auditor → Cleanup |

For the read-heavy cycles 1–7, the Reviewer-style invocation does not run the full 15-point checklist on every page — that's prohibitive for ~110 pages. Instead, it runs a triage pass: pages flagged for substantive rewrite get the full 15-point checklist by a separate Reviewer invocation; pages flagged for small patches go straight to Cleanup.

## TDD cycles

Cycles are organised by sidebar group. Each cycle reads all pages in a group, applies fixes in small commits.

### Cycle 1: Getting Started + Concepts sweep

- **RED:** read each page; capture any:
  - Stale version reference.
  - Snippet that fails when reproduced.
  - Cross-link missing to new content (e.g. `concepts/configuration.md` should link to phase-07's TOML reference).
  - "The old way" prose that no longer applies.
- **GREEN:** apply per-page small fixes.
- **REFACTOR:** if a page is wholly outdated and a full rewrite is needed, flag it as a follow-up rather than expanding scope here.
- **CLEANUP:** every page either green or flagged.

### Cycle 2: Features sweep

- **RED:** read each `features/*` page that exists today. The big issues to expect:
  - `features/federation.md` still describes multi-database federation correctly, but Apollo Federation 2 with full directive set + mTLS + plan viz lives now in phases 04+06. Add cross-links.
  - `features/audit-logging.mdx` needs to reflect the v2.2 mutation audit tracing + usage aggregation.
  - `features/security.md` needs the v2.3 S33–S48 hardening listed; check threat-model coverage.
  - `features/subscriptions.md` cross-links to the new realtime subsystem page (phase 04).
  - `features/observability.md` needs v2.3 admin query-stats endpoints + Prometheus gauges.
  - `features/encryption.md` ensure consistency with `[security.state_encryption]` etc.
- **GREEN:** per-page patches.
- **CLEANUP:** all features pages verified or flagged.

### Cycle 3: Guides sweep

- **RED:** guides are the most varied; many were written with Python SDK in mind. Spot-check each:
  - `guides/advanced-federation.md` — cross-links to mTLS, plan viz, full directive set.
  - `guides/advanced-patterns.mdx` — outdated patterns?
  - `guides/error-handling.md` — error taxonomy is now `FraiseQLError` (v2.3 breaking change); ensure migration is reflected.
  - `guides/performance.md`, `guides/performance-benchmarks.md` — v2.3 perf wins listed?
  - `guides/troubleshooting.md` — common issues with new subsystems?
- **GREEN:** per-page patches.
- **CLEANUP:** all guides verified or flagged.

### Cycle 4: Reference sweep (non-rebuilt)

- **RED:** phase 07 rebuilt CLI, TOML, operators. The remaining reference pages need a verification sweep:
  - `reference/scalars.md` — every built-in scalar grep-able in source.
  - `reference/semantic-scalars.md` — all 49+ semantic scalars listed correctly.
  - `reference/decorators.md` — SDK-flavoured; reconcile with `roadmap.md` SDK status (do not show Elixir/F# decorators if those SDKs are "Not started").
  - `reference/graphql-api.md` — endpoint surface; cross-link to MCP and REST.
  - `reference/naming-conventions.md` — camelCase normalization documented.
  - `reference/validation-rules.md` — `ValidationRule::Pattern` shape (v2.3 changed it to `CompiledPattern`); document.
- **GREEN:** per-page patches.
- **CLEANUP:** every reference symbol grep-able in source.

### Cycle 5: Databases + Deployment + Troubleshooting

- **RED:** these are largely operations-oriented:
  - `databases/*` — verify connection-string examples against source.
  - `deployment/*` — verify Docker / k8s / cloud examples; check security defaults.
  - `troubleshooting/*` — common-issues page should reflect v2.3 error messages.
- **GREEN:** patches; container-verify any non-trivial command.
- **CLEANUP:** complete.

### Cycle 6: SDK + Examples + Tools + vs

- **RED:** SDK pages risk over-claiming. Examples may use outdated APIs. `vs/*` pages need v2.3 accuracy.
  - For each SDK page: verify presence in the cross-SDK CI matrix; verify decorators / config shown match the SDK's current public surface; if SDK is "Not started" per roadmap, page is marked as such with a roadmap link.
  - For each `examples/*` page: confirm the example schema and queries reproduce in a container.
  - For `vs/apollo`, `vs/hasura`, `vs/prisma`: verify comparison claims against v2.3 capabilities (not v2.0).
- **GREEN:** patches.
- **CLEANUP:** complete.

### Cycle 7: Community + Confiture + diagrams + analytics-architecture + index

- **RED:** the last odds and ends:
  - `community/contributing.md` — does it reference the new docs-test harness? It should.
  - `confiture/*` — verify the migration tool docs reflect current shape; reproduce one migration end-to-end.
  - `diagrams/architecture.md` — does the architecture diagram still match the crate graph?
  - `analytics-architecture.mdx` — Arrow Flight + analytics queries still accurate?
  - `index.mdx` — final version sweep; ensure card grid links resolve; ensure the "v2.0.0-alpha is production-ready" is gone (phase 01 should have caught it, but verify).
- **GREEN:** patches.
- **CLEANUP:** complete.

### Cycle 8: Screenshot regeneration

- **RED:** any page with a UI screenshot (Studio, Apollo Sandbox, error pages, Grafana dashboard). Compare each against the live UI.
- **GREEN:** regen any stale screenshot at 1440×900, retina, light mode (per style guide).
- **REFACTOR:** if a screenshot is decorative rather than load-bearing, consider removing.
- **CLEANUP:** every screenshot is current.

### Cycle 9: External link re-audit

- **RED:** phase 01 audited external links. Months have passed.
- **GREEN:** re-run the audit script. Fix any new dead/redirected links.
- **CLEANUP:** clean audit transcript stored as `_internal/external-link-audit-phase08.json`.

### Cycle 10: Sweep matrix close-out

- **RED:** the sweep matrix from phase 01 has rows with statuses other than OK.
- **GREEN:** walk the matrix; close every row to OK or to "deferred to follow-on" with explicit rationale.
- **CLEANUP:** the matrix is committed at full-green. Any deferred rows are listed in `_internal/.plan/follow-on-backlog.md` (created here, used by phase 09).

### Cycle 11: Phase-close style audit

Persona: Style Auditor → Cleanup.

- **RED:** the sweep touched ~110 pages with many small patches across many persona invocations. Style consistency across the full surface is the highest risk in this phase.
- **GREEN:** Style Auditor reads a stratified random sample (one page per sidebar group, ~12 pages total) plus every page that received >25 lines of edits in cycles 1–7. Produces `_internal/.plan/style-audits/phase-08.md`. If the sample reveals systemic drift, the Auditor flags it for a broader pass.
- **CLEANUP:** Cleanup applies. If the broader pass was flagged, escalate to Opus for a second Style Auditor invocation across more pages.

## Adversarial review protocol

The sweep phase has a peculiar review property: there is no single new artifact to review. Instead:

1. Reviewer picks 20 pages at random (uniformly across sidebar groups).
2. For each, reviewer reads end-to-end with the 12-point checklist.
3. Any failure becomes a small follow-up commit; reviewer re-checks.
4. Reviewer audits the sweep matrix for any row that smells suspicious (e.g. a guide marked OK that they recall having issues).
5. Reviewer runs `astro check` and `bun run build` from a clean clone.

## Container verification matrix

Most pages don't need fresh verification; this phase relies on per-page judgement. Spot-check 10% of pages with container reproductions:

| Sample target | DB matrix |
|---------------|-----------|
| 3 random feature pages | per page |
| 2 random example pages | per page |
| 1 random reference page | per page |
| 2 random getting-started flows | full matrix |
| 2 random database-specific pages | corresponding DB |

## Risks specific to this phase

| Risk | Mitigation |
|------|------------|
| Scope creep — every page can become a rewrite | Hard rule: any page needing >100 lines changed is deferred to follow-on; the row is marked deferred, not patched here |
| SDK status table drift between this phase and the `roadmap.md` | Cycle 6 grabs `roadmap.md` SHA; future drift is a follow-up |
| Screenshot fatigue if many UIs changed | Phase 04 already produced Studio screenshots; reuse where possible |
| Examples pages may rely on schemas that need fixture additions | Add fixtures in `scripts/docs-test/fixtures/examples/` as needed |
| Some pages may have been originally written about features that no longer exist | Don't preserve the page for sentimental reasons; delete and document the deletion in `_internal/sidebar-decision.md` |

## Estimated effort

**Effort proxy: 1.5.** ~110 pages of read-heavy triage. Reviewer-style Opus invocations are the dominant cost — but each is shorter than a full 15-point checklist (most pages need only a triage classification). Cleanup-Sonnet for the patch-volume. Link Auditor-Haiku is cheap. Style Auditor at close runs on a sample, not the full ~110 pages.

## Status

- [ ] Not started
- [ ] RED in progress
- [ ] GREEN in progress
- [ ] REFACTOR in progress
- [ ] CLEANUP in progress
- [ ] Complete

## Owner

*(unclaimed)*

## Pages completed

*(append per cycle; this phase will produce a long list)*

## Framework bugs filed

*(usually small surface drift surfaced by spot-checks)*
