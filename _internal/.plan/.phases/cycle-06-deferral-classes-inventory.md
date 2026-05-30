# Cycle 6 deferral classes inventory + gate proposal

**Phase:** 03 / Cycle 6
**Persona:** Writer (Opus 4.7)
**Date:** 2026-05-30
**Branch:** `phase-03/critical-rewrites` @ `5d9f6a2` (Cycle 5 close)
**Frozen FraiseQL SHA:** `d0a4ed4ec1770c70707f68fd9019f2b561d87461`

This document is internal. It does not ship. It records the URL-level inventory for the Cycle-4 deferrals, the decision-space per class, and the proposed gate framing (G8). The Writer-GREEN cycle that follows applies whichever path the user picks at G8.

---

## Class A — `fraiseql/examples` (16 URLs)

### Pages affected (4)

- `src/content/docs/examples/index.mdx` — 10 hits
- `src/content/docs/examples/saas-blog.mdx` — 2 hits
- `src/content/docs/examples/realtime-collaboration.mdx` — 2 hits
- `src/content/docs/examples/mobile-analytics-backend.mdx` — 2 hits

Brief said "11 URLs"; actual count after re-grep is **16 URLs**. The discrepancy is the index page (brief said 4, actual is 10 because each catalog card carries a `**Repository**:` link plus a trailing `git clone` block + Fork CTA). Inventory below is exhaustive.

### URL inventory

| # | File | Line | URL |
|---|------|------|-----|
| 1 | `examples/index.mdx` | 93 | `https://github.com/fraiseql/examples/saas-blog-platform` |
| 2 | `examples/index.mdx` | 126 | `https://github.com/fraiseql/examples/federation-ecommerce` |
| 3 | `examples/index.mdx` | 158 | `https://github.com/fraiseql/examples/realtime-collaboration` |
| 4 | `examples/index.mdx` | 190 | `https://github.com/fraiseql/examples/realtime-analytics` |
| 5 | `examples/index.mdx` | 225 | `https://github.com/fraiseql/examples/mobile-analytics-backend` |
| 6 | `examples/index.mdx` | 250 | `https://github.com/fraiseql/examples/saas-federation-nats` |
| 7 | `examples/index.mdx` | 275 | `https://github.com/fraiseql/examples/nats-event-pipeline` |
| 8 | `examples/index.mdx` | 301 | `https://github.com/fraiseql/examples/microservices-choreography` |
| 9 | `examples/index.mdx` | 313 | `https://github.com/fraiseql/examples.git` (in `git clone` block) |
| 10 | `examples/index.mdx` | 489 | `https://github.com/fraiseql/examples` (Fork CTA) |
| 11 | `examples/saas-blog.mdx` | 10 | `https://github.com/fraiseql/examples/saas-blog` |
| 12 | `examples/saas-blog.mdx` | 516 | `https://github.com/fraiseql/examples/saas-blog` (in `git clone` block) |
| 13 | `examples/realtime-collaboration.mdx` | 10 | `https://github.com/fraiseql/examples/realtime-collaboration` |
| 14 | `examples/realtime-collaboration.mdx` | 436 | `https://github.com/fraiseql/examples/realtime-collaboration` (in `git clone` block) |
| 15 | `examples/mobile-analytics-backend.mdx` | 10 | `https://github.com/fraiseql/examples/mobile-analytics-backend` |
| 16 | `examples/mobile-analytics-backend.mdx` | 401 | `https://github.com/fraiseql/examples/mobile-analytics-backend` (in `git clone` block) |

Note: the page-side index also exposes additional starter-repo names that are not currently URL-linked but presume the same org (`fraiseql-starter-minimal`, `fraiseql-starter-blog`, `fraiseql-starter-saas` — lines 39/42/45 of `examples/index.mdx`). Any A1/A3 choice should consider whether these starter repos also need creation; an A2 path naturally removes them along with the URLs.

### Decision options (one-paragraph trade-off each)

- **A1 — Create `fraiseql/examples` org repo + sub-repos to match.** Largest-scope path. Requires creating the `fraiseql/examples` GitHub repo and 8 sub-paths (or 8 sibling repos under a `fraiseql/examples-*` convention — orchestrator must decide which shape). Each sub-repo carries a runnable scaffold matching the doc page's worked example. This is infra work outside Phase 03 scope. Pros: docs read as written; reader gets a working starter. Cons: 8+ repos to seed, maintain, CI-wire, and update on every framework release. The maintenance debt scales with the docs surface, not with the framework surface. Plausible only if the org commits long-term to keeping the examples current; otherwise it spawns a new class of stale-docs failure.

- **A2 — Rewrite all 4 pages to drop the "look at our code on GitHub" framing.** Smallest-scope path. Each page becomes a tutorial-only resource: the worked example stays, the `**Repository**:` header link, the `git clone …` block, and the Fork CTA all go. Pros: page-side only, no infra debt, no out-of-band publishing pipeline. The pages still teach the same patterns — readers walk the steps in their own repo. Cons: removes the "instant clone-and-run" affordance the catalog page currently promises (some readers prefer that path). The catalog page (`examples/index.mdx`) needs a re-frame: its title is "Example Applications" and its sub-cards are catalog cards built around external repos. Re-frame as "Worked examples by use-case" with each card pointing to the in-doc walkthrough.

- **A3 — Point at `fraiseql/fraiseql/examples/` (framework repo's `examples/` subdir).** Middle path. The framework repo carries a `examples/` directory with **23 sub-trees** at frozen SHA (see prerequisite check below). Slug mismatch: the docs page slugs (`saas-blog-platform`, `realtime-collaboration`, `mobile-analytics-backend`, `federation-ecommerce`, `realtime-analytics`, `saas-federation-nats`, `nats-event-pipeline`, `microservices-choreography`) **do not** map 1:1 to the framework repo's slugs (`saas`, `real_time_chat`, `analytics_dashboard`, `multitenant`, `federation`, `streaming`, `mutation-patterns`, `cascade-create-post`, `blog_api`, `ecommerce_api`, `native-auth-app`, `observability`, `ltree-hierarchical-data`, `clickhouse`, `migrations`, …). Pros: smaller infra lift (the directory already exists); the framework repo is already maintained; examples evolve alongside the framework. Cons: each doc page would need its `**Repository**:` rewritten with a curated `tree/<SHA>/examples/<slug>` path AND its worked example rewritten to match the framework example's actual code (today's docs and the framework's examples teach different things). The page-side rewrite cost is comparable to A2; the infra benefit is that pages survive future framework changes if pinned to a tag, not to an unmaintained sibling org.

### A3 prerequisite check — does `fraiseql/fraiseql/examples/` exist at frozen SHA?

**YES.** `git -C ~/code/fraiseql ls-tree d0a4ed4ec1770c70707f68fd9019f2b561d87461 | grep examples` returns:

```
040000 tree 88899860ee45fa521a9fc64765ad69127edb96dc	examples
```

`ls-tree` of that subtree returns 23 entries (README + 22 sub-dirs: `_TEMPLATE`, `analytics_dashboard`, `basic`, `blog_api`, `cascade-create-post`, `ci`, `clickhouse`, `ecommerce_api`, `federation`, `ltree-hierarchical-data`, `migrations`, `multitenant`, `mutation-patterns`, `native-auth-app`, `observability`, `r`, `real_time_chat`, `rust`, `saas`, `sql`, `streaming`, `todo_xs`). The directory exists and is non-empty, but **none** of the framework slugs match the docs slugs verbatim. A3 therefore implies a curated mapping table (docs slug → framework example slug) plus per-page prose rework, not a mechanical URL-swap.

### Recommended default if user picks no preference

**A2 (page-side rewrite, drop the GitHub framing).** Smallest scope, no infra debt, page surface stays useful as tutorials. The docs are net-honest after A2 — they teach the patterns the catalog promised, without dangling URLs. A1 spawns a perpetual maintenance burden the org has not yet committed to. A3 looks cheap but the slug-mismatch + per-page worked-example rewrite makes its true cost comparable to A2 with a remaining risk surface (framework SHA drift breaks doc pins).

---

## Class B — `velocitybench` (10 URLs)

### Pages affected (2)

- `src/content/docs/operations/performance-benchmarks.mdx` — 7 hits (1 frontmatter `description` + 6 body)
- `src/content/docs/community/blog/rest-direct-execution-benchmark.mdx` — 3 GitHub-URL hits (page also references "VelocityBench" by name another 6 times in prose)

Brief said "2 hits across 2 pages"; the brief was counting only the bare `github.com/fraiseql/velocitybench` URL forms. Actual count of URL-form hits is **5** (3 in `performance-benchmarks.mdx`, 2 in `rest-direct-execution-benchmark.mdx` — both in `git clone` blocks). Total mentions of the **brand** "VelocityBench" across both pages is ~13 (frontmatter, prose, source-attribution captions, CardGrid). Both shapes need the same decision but the prose impact of B2 is larger than the URL-count alone suggests.

### URL inventory

| # | File | Line | URL / mention |
|---|------|------|---------------|
| 1 | `operations/performance-benchmarks.mdx` | 3 | (frontmatter `description`) "FraiseQL performance data from VelocityBench …" |
| 2 | `operations/performance-benchmarks.mdx` | 10 | `https://github.com/fraiseql/velocitybench` (prose link, "Independent data from [VelocityBench]") |
| 3 | `operations/performance-benchmarks.mdx` | 18 | "Source: VelocityBench 2026-02-21." caption |
| 4 | `operations/performance-benchmarks.mdx` | 50 | "Source: VelocityBench 2026-02-22, …" caption |
| 5 | `operations/performance-benchmarks.mdx` | 181 | "_Full transport suite benchmarks will be added to VelocityBench when available._" |
| 6 | `operations/performance-benchmarks.mdx` | 187 | prose: "All numbers on this page come from the VelocityBench public reports." |
| 7 | `operations/performance-benchmarks.mdx` | 190 | `git clone https://github.com/fraiseql/velocitybench` |
| 8 | `operations/performance-benchmarks.mdx` | 199–200 | CardGrid `Card title="VelocityBench"` linking `https://github.com/fraiseql/velocitybench` |
| 9 | `community/blog/rest-direct-execution-benchmark.mdx` | 28 | `[VelocityBench](https://github.com/fraiseql/velocitybench)` ("our open-source benchmarking harness") |
| 10 | `community/blog/rest-direct-execution-benchmark.mdx` | 31 | prose: "`velocitybench_benchmark` dataset" |
| 11 | `community/blog/rest-direct-execution-benchmark.mdx` | 37 | `[VelocityBench results](https://github.com/fraiseql/velocitybench)` |
| 12 | `community/blog/rest-direct-execution-benchmark.mdx` | 43 | prose: "Only the GraphQL column contains measured VelocityBench data." |
| 13 | `community/blog/rest-direct-execution-benchmark.mdx` | 54 | `[VelocityBench framework-matrix results](https://github.com/fraiseql/velocitybench)` |
| 14 | `community/blog/rest-direct-execution-benchmark.mdx` | 91 | prose: "The GraphQL baseline comes from VelocityBench:" |
| 15 | `community/blog/rest-direct-execution-benchmark.mdx` | 94 | `git clone https://github.com/fraiseql/velocitybench.git` |
| 16 | `community/blog/rest-direct-execution-benchmark.mdx` | 100 | prose: "not a dedicated VelocityBench scenario" |

Brief filename mismatch: brief said `rest-direct-execution-benchmark.md`; the actual file is `.mdx`. Inventory above is against the real file.

### Decision options

- **B1 — Create the `fraiseql/velocitybench` repo with reproducible benchmark scripts + data.** Infra-heavy path. Requires creating the repo, publishing the harness, the dataset, the `make bench` Makefile, the per-framework profiles, and the public results. The two doc pages then survive as-written. Pros: docs read as written; "Independent data" framing remains honest; the page becomes the front door to a tool readers can run. Cons: the harness needs ongoing curation (re-run on framework releases, add new frameworks, version the dataset); the "Independent" claim is awkward when the harness lives under `fraiseql/` — readers may discount the numbers. The `2026-02-21` and `2026-02-22` capture dates in the page imply the harness has already been run privately; B1 amounts to publishing what exists, plus committing to publish updates.

- **B2 — Rewrite both pages to drop "Independent data from VelocityBench" framing.** Page-side path. Use only first-party benchmark data with reader-actionable reproduction instructions. The performance-benchmarks page becomes "These are our numbers from this hardware on this date; here's how to reproduce them with `hey` + the schema in `examples/blog_api/`." The blog post is reframed as "Our internal harness compared X vs Y on this date." Pros: page-side only, no maintenance debt; honest claim (these are our numbers, no marketing veneer). Cons: removes the "third-party harness" credibility marker that helps readers trust the numbers. Mitigation: explicit reproduction recipe makes the numbers verifiable in a more durable way than appealing to an external harness whose maintenance status is unclear.

### Recommended default if user picks no preference

**B2 (page-side rewrite, drop the VelocityBench framing).** Same logic as A2: smallest-scope, no perpetual maintenance debt, honest after rewrite. The "Independent data" framing is technically true only if the harness has a long-term maintenance commitment from the org. A reader who wants to verify can re-run the documented `hey` invocation against the documented schema. If the org later commits to a public harness, B1 becomes a follow-on cycle; nothing is lost.

---

## Class C — `demo.fraiseql.dev` (6 pages, 6 URLs)

### Pages affected (6)

All 6 pages embed the live demo via the `<EmbeddedSandbox />` Astro component, passing `endpoint="https://demo.fraiseql.dev/graphql"`.

| # | File | Line | URL / context |
|---|------|------|---------------|
| 1 | `playground.mdx` | 14 | `<EmbeddedSandbox endpoint="https://demo.fraiseql.dev/graphql" …>` — the playground page; the demo *is* the page. |
| 2 | `concepts/how-it-works.mdx` | 424 | embedded near a "Try it yourself" section |
| 3 | `getting-started/quickstart.mdx` | 454 | embedded after the worked-example walkthrough |
| 4 | `features/mutual-exclusivity.mdx` | 195 | embedded for the feature demo |
| 5 | `features/automatic-where.mdx` | 150 | embedded for the feature demo |
| 6 | `features/rich-filters.mdx` | 83 | embedded for the feature demo |

Per the Phase 01 link-audit, `demo.fraiseql.dev` returns a TLS SAN mismatch — the cert covers a different name. Browsers reject; readers hit a broken sandbox instead of a working one.

### Decision options

- **C1 — Infra-fix the TLS SAN mismatch on `demo.fraiseql.dev`.** Infra path. Add `demo.fraiseql.dev` to the cert SAN (or re-issue the cert), verify the GraphQL server is actually running behind it, confirm the embedded sandbox loads in a real browser. Pros: docs read as written; all 6 pages keep their live-demo affordance — a substantial UX win, especially on `playground.mdx` where the demo *is* the page. Cons: outside Phase 03 scope; requires org-side infra ownership (DNS / cert / hosting); risks recurrence on future cert renewals; the demo server itself needs uptime monitoring or the pages break silently again.

- **C2 — Rewrite all 6 pages to drop the live-demo claim.** Page-side path. Replace each `<EmbeddedSandbox endpoint="https://demo.fraiseql.dev/graphql" …/>` with a "host the playground locally with `bun run dev`" alternative (or a static query/response example, or a link to the in-repo example schema). The `playground.mdx` page becomes either a self-hosting guide or is removed from the sidebar entirely. Pros: page-side only, no infra surface to defend. Cons: removes a high-impact reader affordance — the "click and try" surface is a big part of why readers stay engaged. The 5 non-playground pages can shed the embed without much loss (they all have surrounding prose + code samples); the playground page loses its raison d'être.

### Recommended default if user picks no preference

**C1 (infra fix the TLS SAN), surfaced as an out-of-Phase-03 ticket.** The cost of a single cert reissue + DNS check is small; the reader value of the live demo (especially `playground.mdx`) is large. Orchestrator surfaces this as a parallel infra ticket; if the user declines C1 or the infra owner can't commit, fall back to C2 page-by-page (with `playground.mdx` either deleted from the sidebar or rewritten as a self-hosting recipe).

Distinction worth flagging: C is the only deferral class where the page-side path **loses** meaningful reader value. A and B are page-side rewrites of marketing affordances (catalog-of-external-repos, third-party-harness-attribution); C is a page-side rewrite of a working interactive surface.

---

## Class D — `charts.fraiseql.io`

**0 hits confirmed.** `grep -rn "charts.fraiseql.io" /home/lionel/code/fraiseql-docs/src/content/docs/` returns no matches. The sweep matrix § "Cycle 4 deferrals" row D notes this was an orchestrator-side artefact in the original task brief, not a `src/`-side reference. No action required by Cycle 6 or any downstream cycle.

---

## Follow-on — `community/support.mdx`

**File:** `src/content/docs/community/support.mdx`
**Line:** 150
**Current text:**

```
- **Status Page**: status page coming soon — check [GitHub Issues](https://github.com/fraiseql/fraiseql/issues) for service announcements
```

**Reviewer flag (Cycle 4):** "coming soon" violates archaeology-free (checklist item 12) by the spirit of the rule even though the line as written points at a real fallback. The line is also self-contradicting: it directs the reader at the GitHub Issues page in the same sentence that defers a "status page".

**Proposed replacement:**

```
- **Service announcements**: [GitHub Issues](https://github.com/fraiseql/fraiseql/issues) — file an issue with the `service` label, or check existing issues for outage / regression notices.
```

Drops the "coming soon" framing entirely. Reframes the line around the actually-existing surface (Issues) instead of treating Issues as the fallback for an absent surface. No status-page commitment implied.

---

## Proposed gate framing

### G8 (novel — Cycle 6) — Phase-01 Cycle-4 deferral resolution

Four sub-decisions. Orchestrator surfaces all four to the user via `AskUserQuestion`. Each sub-decision has an orchestrator default that the user can override; if the user accepts all defaults, the orchestrator can resolve G8 in a single round-trip.

| Sub-gate | Class | Options | Orchestrator default | Rationale for default |
|----------|-------|---------|----------------------|----------------------|
| **G8a** | Class A (`fraiseql/examples`) | A1 / A2 / A3 | **A2** (page-side rewrite, drop GitHub framing) | Smallest scope, no infra debt, page surface stays useful as tutorials. A1 spawns perpetual maintenance debt; A3 carries hidden slug-mismatch + per-page rewrite cost comparable to A2 with worse durability. |
| **G8b** | Class B (`velocitybench`) | B1 / B2 | **B2** (page-side rewrite, drop VelocityBench framing) | Same logic as A2: no maintenance debt; first-party benchmark + reproduction recipe is more honest and more durable than appealing to an unmaintained external harness. |
| **G8c** | Class C (`demo.fraiseql.dev`) | C1 / C2 | **C1** (infra-fix the TLS SAN) | The **only** class where the page-side path loses meaningful reader value (`playground.mdx` *is* the demo). A single cert reissue is small; the reader UX gain is large. Falls back to C2 if infra owner declines. |
| **G8d** | `community/support.mdx` follow-on | (proposed text above) | **Accept proposed text** | Reviewer-flagged in Cycle 4; line is self-contradicting today; rewrite is one-line and net-honest. |

### Why a single gate (G8) rather than G8/G9/G10/G11

The four sub-decisions are causally independent (each picks a path for a disjoint set of pages) but ergonomically coupled — the user sees them once, picks defaults or overrides, and the Writer-GREEN cycle that follows applies the resolved set page-by-page. Splitting into four numbered gates spawns four separate human round-trips for a coordinated decision; folding them as G8a-G8d keeps the round-trip count at one while preserving the per-class audit trail.

If the user prefers to defer one sub-decision (e.g., G8c needs an infra-owner conversation), that sub-decision can be left open while the others resolve. The Writer-GREEN cycle then operates on the resolved subset and a follow-on cycle resolves the remainder. The gate notation supports partial resolution.

### After G8 resolves

Writer-GREEN (Cycle 7 or a dedicated G8-resolution cycle, orchestrator's call) applies the chosen path per class:

- **A2 (default)** — rewrite `/examples/index`, `/examples/saas-blog`, `/examples/realtime-collaboration`, `/examples/mobile-analytics-backend` to drop the catalog-of-external-repos framing. Each page becomes a tutorial-only resource with an in-page worked example. The catalog page (`examples/index.mdx`) needs structural rework, not just URL removal.
- **B2 (default)** — rewrite `operations/performance-benchmarks.mdx` and `community/blog/rest-direct-execution-benchmark.mdx` to drop the VelocityBench framing. Replace with first-party benchmark numbers + an explicit `hey` reproduction recipe against the documented schema.
- **C1 (default)** — surface a parallel infra ticket for the TLS SAN fix; no page edits. Fallback to C2 if the infra owner declines (then 6 pages need the `<EmbeddedSandbox/>` replaced page-by-page).
- **G8d (default)** — one-line edit to `community/support.mdx:150`.

The Writer-GREEN cycle re-grounds against this inventory document plus the user's G8 resolution; no further RED work is required to apply the chosen path.

---

*This document does not ship. Deleted in Phase 10 along with the rest of `_internal/.plan/`.*
