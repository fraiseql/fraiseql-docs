---
title: Sweep matrix
description: Phase-01 / Cycle-7 inventory — every docs page accounted for.
---

{/* This file is internal planning. Excluded from the build by the `_`-filename prefix and the `_internal/` parent directory per Astro convention. */}

{/* source: astro.config.mjs:L1-L6 — `_internal/` exclusion comment; both `_internal/` and `_`-prefixed filenames keep Astro and Pagefind out. */}

# Sweep matrix

**Authored:** Phase 01 / Cycle 7 — 2026-05-29.
**Branch:** `phase-01/triage-and-ia`.
**Authority:** post-Option-A sidebar (per `_sidebar-decision.md`, Cycle 6 close).
**Frozen FraiseQL SHA:** `d0a4ed4ec1770c70707f68fd9019f2b561d87461`.

{/* source: _internal/.plan/.phases/README.md:L7-L26 — frozen SHA + G2 SHA-bump procedure. */}
{/* source: src/content/docs/_internal/_sidebar-decision.md:L1-L107 — Option A move map, 76 redirects, 76 moves, page-count 172 (off-by-1 in §6 noted by Cycle 6 Reviewer; corrected in §6 of that document at Cycle 7 close per Cycle 6 Reviewer follow-on). */}

## How to use this matrix

Phase 02-09 Writers: find your phase's rows in the by-phase view below, then jump to the slug rows in the main matrix for state, DB matrix claims, and cross-phase deps. Phase 10 Final Reviewer: every page must end Phase 09 with state ∈ `{OK, redirected}` and `Owning phase` ∈ `{08 | 10 | --}` — anything else is an open gate.

## Page-state legend

- **OK** — no Phase 01 audit finding, no known issue. Phase 08 final sweep may still touch for prose polish.
- **needs-update** — small, scoped fix queued (e.g., one version anchor, one CLI flag mismatch).
- **needs-rewrite** — substantial prose work; the owning phase will largely rewrite the page.
- **broken-snippet** — at least one code / SQL / CLI snippet does not run; the page reads OK otherwise.
- **wrong-content** — prose contradicts framework behaviour at the frozen SHA; reader will be misled.
- **missing** — page does not exist yet; the owning phase creates it.
- **redirected** — page moved by Cycle 6; OLD slug now resolves via Astro top-level `redirects` map to a NEW slug listed in this matrix.

DB matrix shorthand: `PG | MySQL | SQLite | MSSQL`. `all 4` means the page tabs through all four. `n/a` means the page is DB-agnostic (concept, SDK, marketing, ops). `?` means undetermined at Cycle 7 — Phase 02/03 owners verify per page.

## By-phase view (rows per phase, slug bullets only)

The main matrix below is sorted by sidebar order. Each phase reads the slice that names it as `Owning phase`.

### Phase 02 — Migration and changelog hub (`changelog.mdx` rewrite; v2.0→v2.3 migration pages; breaking matrix). Adjacent: quickstart SQL bugs; install matrix; SDK release alignment.

- `/changelog` — full rewrite (v2.1 "Unreleased" framing is stale)
- `/getting-started/quickstart` — 3 SQL bugs at L156 / L167-179 / L184 (Phase 00 / Cycle 5)
- `/getting-started/installation` — cargo command-name alignment with `/reference/cli`
- `/reference/cli` — cargo command-name alignment with `/getting-started/installation`
- `/sdk` index + 11 SDK pages — SDK release alignment (all pinned to v2.1)
- `/getting-started/five-minute-quickstart`, `/getting-started/first-api`, `/getting-started/adding-mutations`, `/getting-started/starters` — touch only as adjacent to the quickstart sweep

### Phase 03 — Critical rewrites (multi-tenancy, file-storage, observers, authentication). Owns the four Cycle 4 deferral classes.

- `/building/multi-tenancy` — critical rewrite
- `/features/file-storage` — critical rewrite (and consumer of FW-1 #326 storage endpoint override once landed in Phase 09)
- `/features/observers`, `/building/observers`, `/building/observer-webhook-patterns`, `/operations/observer-runbook` — observers triple-overlap consolidation now that IA splits them three ways
- `/building/authentication`, `/features/security`, `/features/encryption`, `/features/oauth-providers`, `/features/audit-logging`, `/features/rate-limiting`, `/features/server-side-injection` — authentication / security rewrites
- `/concepts/why-fraiseql`, `/concepts/how-it-works`, `/concepts/cqrs`, `/concepts/developer-owned-sql`, `/concepts/view-composition`, `/concepts/type-system`, `/concepts/schema`, `/concepts/configuration`, `/concepts/elo-validation`, `/concepts/mutations`-via-`/features/mutations` — concepts rewrite pass
- `/examples/index` + 9 examples — `fraiseql/examples` URL decision (Cycle 4 deferral class A)
- `/operations/performance-benchmarks`, `/community/blog/rest-direct-execution-benchmark` — `velocitybench` decision (Cycle 4 deferral class B)
- `/getting-started/quickstart`, `/concepts/how-it-works`, `/playground`, `/features/mutual-exclusivity`, `/features/automatic-where`, `/features/rich-filters` — `demo.fraiseql.dev` decision (Cycle 4 deferral class C)
- `/community/support` — replace "status page coming soon" with a definite Issues pointer (Cycle 4 Reviewer follow-on)
- 5 `/community/vs/*` pages — comparison-prose rewrite

### Phase 04 — New features part 1 (Studio, Functions WASM, Realtime). All `missing` — new pages.

- `/features/studio` — `missing` (lands under Features → Integration per `_sidebar-decision.md` §5)
- `/features/functions-wasm` — `missing` (Features → Integration)
- `/features/realtime` — `missing` (Features → Integration)
- `/features/subscriptions` — likely needs-rewrite as Realtime / Subscriptions are reconciled
- `/features/webhooks`, `/features/nats` — touch as adjacent to Realtime/Studio

### Phase 05 — New features part 2 (Auth extensions, LTree, partial-period, native aggregations).

- `/features/auth-extensions` — `missing` (Features → Security)
- `/features/ltree` — `missing` (Features → Query & Data; cross-link from `/databases/postgresql`)
- `/features/partial-period` — `missing` (Features → Query & Data)
- `/features/native-aggregations` — `missing` (Features → Performance)
- `/databases/postgresql` — cross-link addition for LTree (otherwise OK)

### Phase 06 — Transport and protocol (REST deepening, MCP, federation mTLS, schema integrity, trusted documents).

- `/features/rest-transport` — REST deepening (page exists)
- `/features/mcp` — `missing` (Features → Integration; cross-link from Community → AI-Assisted)
- `/features/trusted-documents` — `missing` (Features → Security)
- `/features/federation` — federation mTLS prose addition
- `/features/schema-integrity` — `missing` or fold into `/features/security`
- `/features/grpc-transport`, `/features/transports`, `/features/wire-protocol` — touch as adjacent to REST deepening
- `/building/federation-gateway`, `/building/federation-configuration`, `/building/federation-nats-integration`, `/building/advanced-federation`, `/building/advanced-nats`, `/building/apollo-sandbox-security` — federation prose consolidation (Cycle 1 Reviewer's "federation prose partial" follow-on)

### Phase 07 — Reference rebuild (CLI, TOML, operators, scalars).

- `/reference/cli` — full rebuild against frozen-SHA `crates/fraiseql-cli/`
- `/reference/admin-api` — rebuild
- `/reference/toml-config` — rebuild against frozen-SHA `server_config/`
- `/reference/graphql-api` — rebuild
- `/reference/rest-api` — rebuild
- `/reference/decorators` — rebuild
- `/reference/scalars` — rebuild
- `/reference/semantic-scalars` — rebuild
- `/reference/operators` — rebuild
- `/reference/validation-rules` — rebuild
- `/reference/naming-conventions` — rebuild
- `/reference/sql-patterns` — rebuild
- `/reference/authoring-ir` — rebuild

### Phase 08 — Sweep + final link audit. Owns SDK reconciliation tail + remaining feature pages + screenshots + re-audit of external links.

- All `sdk/*` pages — version-pin sweep (after Phase 02 SDK alignment)
- All `examples/*` pages — final prose polish (after Phase 03 content decision)
- 5 `community/vs/*` pages — final polish (after Phase 03 content decision)
- 4 `community/use-cases/*` pages, 6 `community/ai/*` pages, 7 `community/blog/*` pages — final polish
- 7 `databases/*` pages — polish + cross-link verification
- Every page rendered by previous phases — Style Auditor + Cleanup pass
- Re-run `scripts/docs-test/audit-external-links.sh` (Cycle 4 audit re-runner)

### Phase 09 — Framework QA pass (FW-1 + FW-2 close; storage endpoint overrides; PG-hardcode fix). NOT a docs-page phase.

- FW-1 https://github.com/fraiseql/fraiseql/issues/326 — Azure / GCS endpoint override
- FW-2 https://github.com/fraiseql/fraiseql/issues/327 — server PG hardcode
- Page side-effects: `/features/file-storage` (storage endpoints reachable through server), `/getting-started/quickstart` (multi-DB tabs become real)

### Phase 10 — Finalize (archaeology removal, build perf, redirect map regression test, launch).

- `/_internal/_sidebar-decision.md` page-count nit fix (172/172 not 173/173 — see also Cycle 7 commit 2 below)
- `/_internal/_sweep-matrix.md` (this file) — delete with the rest of `_internal/.plan/`
- `src/components/SiteTitle.astro` — fix pre-existing `virtual:starlight/user-images ts(2307)` baseline (currently blocks a pre-commit hook per Cycle 2 Cleanup deferral)
- Redirect-map regression test — `scripts/docs-test/redirects.docs-test.sh` (per Cycle 6 Reviewer follow-on + Cycle 6 Writer §4-Q7)
- Methodology §4 JSX-comment amendment (Cycle 1 / Cycle 2 Reviewer follow-on) — `{/* source: ... */}` accepted as equivalent to `<!-- source: ... -->`
- Compose-file SHA-literal duplication (Phase 00 / Cycle 9 deferral) — switch `args:` literal to read from `FRAISEQL_SHA` file
- Pre-commit hook activation (Cycle 2 Cleanup REFACTOR deferral)
- Delete `_internal/.plan/`, all `_internal/` red-evidence, audits

## Matrix (sorted by sidebar order, post-Option A)

### Getting Started

| Slug | State | Owning phase | DB claim | DB actual | Deps | Notes |
|------|-------|--------------|----------|-----------|------|-------|
| /getting-started/introduction | OK | 08 | n/a | n/a | — | Cycle 4 swapped `fraiseql/specql` hyperlink → plain text. No open issues. |
| /getting-started/five-minute-quickstart | OK | 02 | PG (single image) | PG | adjacent to quickstart | Per Phase 00 / Cycle 5 the external `fraiseql-starter-minimal` repo + opaque image is non-trivial to multi-DB. Phase 02 may touch when reconciling install matrix. |
| /getting-started/installation | needs-update | 02 | n/a | n/a | cli.mdx | **Cycle 5 Writer follow-on:** cargo command is `cargo install fraiseql`; `/reference/cli` says `cargo install fraiseql-cli`. Align in Phase 02. Cycle 1 corrected `--version` output to 2.3.2; Cycle 2 added `text` lang tag on the version-output fence; Cycle 5 removed Homebrew (no tap exists). |
| /getting-started/quickstart | broken-snippet | **02** | claims all 4 | PG only | FW-2 #327 | **3 page bugs from Phase 00 / Cycle 5 smoke:** L156 SQLite `'author', vu.data` needs `json(vu.data)`; L167 + L179 MSSQL `WITH SCHEMABINDING` incompatible with view-on-view (`v_post` references `v_user`); L184 MSSQL `vu.data AS author` needs `JSON_QUERY(vu.data)`. Also impacted by FW-2 — server only routes PG today. Page tabs through all 4 DBs but only PG is end-to-end functional. {/* source: scripts/docs-test/fixtures/{sqlite,mssql}/_smoke.sql — DEVIATION comments document each. */} |
| /getting-started/first-api | OK | 08 | ? | ? | — | No Phase-01 signals. Phase 08 polish. |
| /getting-started/adding-mutations | OK | 08 | ? | ? | overlap with `/features/mutations` | Cycle 6 Writer noted overlap with `/features/mutations` (Option A G1 evidence). Phase 03 may consolidate. |
| /getting-started/starters | OK | 08 | n/a | n/a | — | No Phase-01 signals. |
| /playground | OK | 03 | n/a | n/a | demo.fraiseql.dev | **Cycle 4 deferral C:** `demo.fraiseql.dev` reference — TLS SAN mismatch; infra or prose fix in Phase 03. |

### Core Concepts

| Slug | State | Owning phase | DB claim | DB actual | Deps | Notes |
|------|-------|--------------|----------|-----------|------|-------|
| /concepts/how-it-works | needs-rewrite | 03 | n/a | n/a | demo.fraiseql.dev; cross-link to `/concepts/why-fraiseql` added in Cycle 3 | **Cycle 4 deferral C:** `demo.fraiseql.dev` reference. Phase 3 lines 321/331/342 use FraiseQL compilation "Phase 1/2/3" phrasing — pre-existing content, not docs-overhaul archaeology (Cycle 3 Reviewer cleared). |
| /concepts/why-fraiseql | needs-rewrite | 03 | n/a | n/a | — | Added Phase 00. Cycle 3 wired inbound link from `how-it-works`. Concepts rewrite pass in Phase 03. |
| /concepts/developer-owned-sql | needs-rewrite | 03 | n/a | n/a | — | Concepts rewrite pass. |
| /concepts/cqrs | needs-rewrite | 03 | n/a | n/a | — | Concepts rewrite pass. |
| /concepts/view-composition | needs-rewrite | 03 | n/a | n/a | — | Concepts rewrite pass. |
| /concepts/type-system | needs-rewrite | 03 | n/a | n/a | — | Concepts rewrite pass. |
| /concepts/schema | needs-rewrite | 03 | n/a | n/a | — | Cycle 4 swapped `fraiseql/specql` hyperlink → plain text. Concepts rewrite pass. |
| /concepts/configuration | OK | 08 | n/a | n/a | — | Phase 01 / Cycle 1 inspected version anchors; HISTORICAL "Added in v2.1.0" markers preserved. Polish in Phase 08. |
| /concepts/elo-validation | OK | 08 | n/a | n/a | — | Added Phase 00. Cycle 3 verified adequate inbound links. Polish in Phase 08. |

### Building

| Slug | State | Owning phase | DB claim | DB actual | Deps | Notes |
|------|-------|--------------|----------|-----------|------|-------|
| /building | OK | 08 | n/a | n/a | redirected from `/guides` | Redirect 1 of 76. Section index page. |
| /building/authentication | needs-rewrite | 03 | n/a | n/a | redirected from `/guides/authentication` | Phase 03 critical rewrite (authentication). |
| /building/rest-vs-graphql | OK | 08 | n/a | n/a | redirected from `/guides/rest-vs-graphql` | Cycle 1 verified HISTORICAL version anchor — keep. |
| /building/schema-design | OK | 08 | n/a | n/a | redirected from `/guides/schema-design` | No Phase-01 signals. |
| /building/error-handling | OK | 08 | n/a | n/a | redirected from `/guides/error-handling` | No Phase-01 signals. |
| /building/custom-scalars | OK | 08 | n/a | n/a | redirected from `/guides/custom-scalars` | No Phase-01 signals. |
| /building/custom-queries | OK | 08 | n/a | n/a | redirected from `/guides/custom-queries` | No Phase-01 signals. |
| /building/custom-resolvers | OK | 08 | n/a | n/a | redirected from `/guides/custom-resolvers` | No Phase-01 signals. |
| /building/testing | OK | 08 | ? | ? | redirected from `/guides/testing` | No Phase-01 signals. |
| /building/dev-mode | OK | 08 | n/a | n/a | redirected from `/guides/dev-mode` | No Phase-01 signals. |
| /building/observers | needs-rewrite | 03 | n/a | n/a | redirected from `/guides/observers`; observers triple-overlap | One leg of the observers triple-overlap (was `concepts/observers` + `guides/observers` + `operations/observer-runbook`); Phase 03 consolidates against `/features/observers` and `/operations/observer-runbook`. |
| /building/observer-webhook-patterns | needs-rewrite | 03 | n/a | n/a | redirected from `/guides/observer-webhook-patterns` | Added Phase 00. Phase 03 observer consolidation. |
| /building/projection-tables | OK | 08 | ? | ? | redirected from `/guides/projection-tables` | No Phase-01 signals. |
| /building/threaded-comments | OK | 08 | ? | ? | redirected from `/guides/threaded-comments` | No Phase-01 signals. |
| /building/advanced-patterns | OK | 08 | ? | ? | redirected from `/guides/advanced-patterns` | No Phase-01 signals. Recent commits added DB tabs (per repo head). |
| /building/multi-tenancy | needs-rewrite | **03** | ? | ? | redirected from `/guides/multi-tenancy` | Phase 03 critical rewrite (multi-tenancy). |
| /building/federation-gateway | needs-rewrite | 06 | n/a | n/a | redirected from `/guides/federation-gateway` | Federation prose consolidation (Cycle 1 Reviewer follow-on). |
| /building/federation-configuration | needs-rewrite | 06 | PG + MySQL (federation) | ? | redirected from `/guides/federation-configuration` | Added Phase 00. Federation consolidation. |
| /building/federation-nats-integration | needs-rewrite | 06 | n/a | n/a | redirected from `/guides/federation-nats-integration` | Cycle 1 corrected version anchor. **Pre-existing baseline warning:** `astro-expressive-code language "conf" not found` — Cleanup deferred to Writer in Phase 02/03; not blocking build. |
| /building/advanced-federation | needs-rewrite | 06 | n/a | n/a | redirected from `/guides/advanced-federation` | Cycle 1 corrected version anchor. Federation consolidation. |
| /building/advanced-nats | OK | 06 | n/a | n/a | redirected from `/guides/advanced-nats` | Adjacent to federation consolidation. |
| /building/apollo-sandbox-security | OK | 06 | n/a | n/a | redirected from `/guides/apollo-sandbox-security` | Cycle 4 fixed two Apollo doc URLs. Adjacent to federation work. |
| /building/migrations | OK | 08 | n/a | n/a | redirected from `/migrations` | Migrations index. |
| /building/migrations/incremental | OK | 08 | n/a | n/a | redirected from `/migrations/incremental` | Cycle 4 swapped `install.fraiseql.dev` → releases-page comment. |
| /building/migrations/from-prisma | OK | 08 | n/a | n/a | redirected from `/migrations/from-prisma` | No Phase-01 signals. |
| /building/migrations/from-apollo | OK | 08 | n/a | n/a | redirected from `/migrations/from-apollo` | No Phase-01 signals. |
| /building/migrations/from-hasura | OK | 08 | n/a | n/a | redirected from `/migrations/from-hasura` | No Phase-01 signals. |
| /building/migrations/from-rest | OK | 08 | n/a | n/a | redirected from `/migrations/from-rest` | No Phase-01 signals. |
| /building/migrations/from-postgrest | OK | 08 | n/a | n/a | redirected from `/migrations/from-postgrest` | Cycle 1 verified HISTORICAL version anchor — keep. |
| /building/schema-validator | OK | 08 | n/a | n/a | redirected from `/tools/schema-validator` | Last surviving page of the single-page top-level `tools/` directory; folded into Building → Tools sub-group. |

### Features

| Slug | State | Owning phase | DB claim | DB actual | Deps | Notes |
|------|-------|--------------|----------|-----------|------|-------|
| /features/automatic-where | OK | 03 | ? | ? | demo.fraiseql.dev | **Cycle 4 deferral C:** `demo.fraiseql.dev` reference. |
| /features/rich-filters | OK | 03 | ? | ? | demo.fraiseql.dev | **Cycle 4 deferral C:** `demo.fraiseql.dev` reference. |
| /features/pagination | OK | 08 | ? | ? | — | No Phase-01 signals. |
| /features/function-shapes | OK | 08 | ? | ? | — | No Phase-01 signals. |
| /features/mutual-exclusivity | OK | 03 | ? | ? | demo.fraiseql.dev | **Cycle 4 deferral C:** `demo.fraiseql.dev` reference. |
| /features/mutations | needs-rewrite | 03 | n/a | n/a | redirected from `/concepts/mutations`; overlaps `/getting-started/adding-mutations` | Was `concepts/mutations` — moved to features under Option A. Phase 03 may consolidate with the getting-started intro. |
| /features/caching | OK | 08 | n/a | n/a | — | No Phase-01 signals. |
| /features/apq | OK | 08 | n/a | n/a | — | Persisted queries. No Phase-01 signals. |
| /features/arrow-dataplane | OK | 08 | n/a | n/a | — | Arrow feature-flag content. No Phase-01 signals. |
| /features/wire-protocol | OK | 08 | n/a | n/a | — | No Phase-01 signals. |
| /features/security | needs-rewrite | 03 | n/a | n/a | — | Cycle 1 verified 6 HISTORICAL "Added in vX.Y" anchors — keep. Phase 03 critical rewrite (authentication / security cluster). |
| /features/server-side-injection | needs-rewrite | 03 | n/a | n/a | — | Phase 03 security cluster. |
| /features/encryption | needs-rewrite | 03 | n/a | n/a | — | Phase 03 security cluster. |
| /features/oauth-providers | needs-rewrite | 03 | n/a | n/a | — | Phase 03 security cluster. |
| /features/audit-logging | needs-rewrite | 03 | n/a | n/a | — | Cycle 1 verified HISTORICAL version anchor. Cycle 4 pinned GH link to frozen SHA (`d0a4ed4.../docs/guides/production-security-checklist.md`). Phase 03 security cluster. |
| /features/rate-limiting | needs-rewrite | 03 | n/a | n/a | — | Phase 03 security cluster. |
| /features/transports | OK | 06 | n/a | n/a | redirected from `/transports` | Last surviving page of single-page top-level `transports/`; absorbed into Features → Transports. Phase 06 transport deepening. |
| /features/rest-transport | needs-rewrite | **06** | n/a | n/a | — | Phase 06 REST deepening. |
| /features/grpc-transport | OK | 06 | n/a | n/a | — | Phase 06 transport polish. |
| /features/observers | needs-rewrite | 03 | n/a | n/a | redirected from `/concepts/observers`; observers triple-overlap | Was `concepts/observers` — moved to Features. Phase 03 consolidates the observers triple (concept → here, guide → `/building/observers`, runbook → `/operations/observer-runbook`). |
| /features/subscriptions | needs-rewrite | 04 | n/a | n/a | overlaps with future `/features/realtime` | Phase 04 (Realtime) consolidation. |
| /features/webhooks | needs-rewrite | 04 | n/a | n/a | adjacent to observers + realtime | Phase 04 adjacency. |
| /features/nats | OK | 04 | n/a | n/a | NATS server version (not FraiseQL version per Cycle 1 audit) | Phase 04 adjacency. |
| /features/federation | needs-rewrite | 06 | n/a | n/a | — | Cycle 1 dropped a v2.0.1 anchor + replaced "planned for v2.2.0 (Q1 2027)" — v2.2.0 shipped 2026-05-02. Phase 06 federation mTLS prose. |
| /features/multi-database | OK | 08 | all 4 | PG functional (FW-2 #327) | FW-2 | Phase 08 polish; multi-DB claims become reality only after Phase 09 closes FW-2. |
| /features/file-storage | needs-rewrite | **03** | n/a | S3 only end-to-end (FW-1 #326) | FW-1 | Phase 03 critical rewrite. Storage endpoint override (Azure + GCS) blocked on FW-1 #326; Phase 09 close enables full multi-backend prose. |
| /features/observability | needs-update | 02/03 | n/a | n/a | examples/index.mdx shape | **Cycle 1 Reviewer follow-on:** L340 + L530 `/health` JSON example blobs use `"version": "2.0.0"` literal + stale shape. Phase 02/03 owner refreshes blob (version + database object shape) against Phase 00 / Cycle 2 GREEN transcript. |
| /features/analytics | OK | 08 | n/a | n/a | — | No Phase-01 signals. |
| /features/resilience | OK | 08 | n/a | n/a | — | No Phase-01 signals. |

### Reference

| Slug | State | Owning phase | DB claim | DB actual | Deps | Notes |
|------|-------|--------------|----------|-----------|------|-------|
| /reference/cli | needs-rewrite | **07** | n/a | n/a | installation.mdx cargo cmd alignment | Cycle 1 corrected 3 `--version` outputs to 2.3.2. Cycle 5 removed Homebrew tab. **Cycle 5 Writer follow-on:** cargo command says `cargo install fraiseql-cli`; `/getting-started/installation` says `cargo install fraiseql`. Phase 02 aligns; Phase 07 full rebuild. |
| /reference/admin-api | needs-rewrite | 07 | n/a | n/a | — | Phase 07 rebuild. |
| /reference/toml-config | needs-rewrite | 07 | n/a | n/a | — | Cycle 1 verified HISTORICAL "Added in vX.Y" markers — keep until rebuild. |
| /reference/graphql-api | needs-rewrite | 07 | n/a | n/a | — | Phase 07 rebuild. |
| /reference/rest-api | needs-rewrite | 07 | n/a | n/a | — | Phase 07 rebuild. |
| /reference/decorators | needs-rewrite | 07 | n/a | n/a | — | Cycle 1 verified HISTORICAL markers; Cycle 4 swapped `fraiseql/specql` hyperlink → plain text. |
| /reference/scalars | needs-rewrite | 07 | n/a | n/a | — | Cycle 1: L840 SemVer EXAMPLE string, keep. Phase 07 rebuild. |
| /reference/semantic-scalars | needs-rewrite | 07 | n/a | n/a | — | Phase 07 rebuild. |
| /reference/operators | needs-rewrite | 07 | n/a | n/a | — | Cycle 2: L101 fence-imbalance fixed (closing ``` added). Cycle 1: L1238 SemVer EXAMPLE string, keep. |
| /reference/validation-rules | needs-rewrite | 07 | n/a | n/a | — | Phase 07 rebuild. |
| /reference/naming-conventions | needs-rewrite | 07 | n/a | n/a | — | Phase 07 rebuild. |
| /reference/sql-patterns | needs-rewrite | 07 | all 4 | ? | — | Phase 07 rebuild. |
| /reference/authoring-ir | needs-rewrite | 07 | n/a | n/a | — | Cycle 4 swapped `fraiseql/specql` hyperlink → plain text. Phase 07 rebuild. |

### Operations

| Slug | State | Owning phase | DB claim | DB actual | Deps | Notes |
|------|-------|--------------|----------|-----------|------|-------|
| /operations/deployment | OK | 08 | n/a | n/a | redirected from `/deployment` | Section index, post-move. |
| /operations/deployment/docker | OK | 08 | n/a | n/a | redirected from `/deployment/docker` | No Phase-01 signals. |
| /operations/deployment/kubernetes | needs-update | 08 | n/a | n/a | redirected from `/deployment/kubernetes` | Cycle 1 fixed `:2.0.0` → `:2.3.2` image tag (no such tag at 2.0.0). |
| /operations/deployment/aws | OK | 08 | n/a | n/a | redirected from `/deployment/aws` | No Phase-01 signals. |
| /operations/deployment/gcp | OK | 08 | n/a | n/a | redirected from `/deployment/gcp` | No Phase-01 signals. |
| /operations/deployment/azure | OK | 08 | n/a | n/a | redirected from `/deployment/azure` | No Phase-01 signals. |
| /operations/deployment/scaling | OK | 08 | n/a | n/a | redirected from `/deployment/scaling` | No Phase-01 signals. |
| /operations/deployment-guide | needs-rewrite | 02/03 | n/a | n/a | redirected from `/guides/deployment`; parent dir `operations/deployment/` exists | **Cycle 6 Reviewer follow-on:** `-guide` suffix is a collision-avoidance rename; consider merging into `/operations/deployment` (or its index) during Phase 02/03 prose consolidation. Until then, the `-guide` sibling is a Reviewer-flagged "where does this actually live?" reader hazard. |
| /operations/performance | OK | 08 | n/a | n/a | redirected from `/guides/performance` | Phase 08 polish (federation/performance/security clusters were Cycle 1 follow-on candidates). |
| /operations/performance-benchmarks | needs-rewrite | 03 | n/a | n/a | velocitybench; redirected from `/guides/performance-benchmarks` | **Cycle 4 deferral B:** `velocitybench` repo references — prose claim "Independent data from VelocityBench" is load-bearing; Phase 03 prose decision. |
| /operations/observer-runbook | needs-rewrite | 03 | n/a | n/a | observers triple-overlap | Third leg of the observers triple-overlap; Phase 03 consolidation against `/features/observers` + `/building/observers`. |
| /operations/troubleshooting | OK | 08 | n/a | n/a | redirected from `/troubleshooting` | Section index. |
| /operations/troubleshooting/common-issues | needs-update | 08 | all 4 | ? | redirected from `/troubleshooting/common-issues` | Cycle 1 fixed `v2.0.1+ → v2.3.0+` REST default anchor (L1456). Cycle 4 fixed AWS RDS truststore URL (`truststore.amazonaws.com` → `truststore.pki.rds.amazonaws.com/.../global-bundle.pem`). DB tabs recently added (per git head). |
| /operations/troubleshooting/performance-issues | OK | 08 | all 4 | ? | redirected from `/troubleshooting/performance-issues` | DB tabs recently added (per git head). |
| /operations/troubleshooting/security-issues | OK | 08 | all 4 | ? | redirected from `/troubleshooting/security-issues` | DB tabs recently added (per git head). |
| /operations/troubleshooting/federation-nats | OK | 08 | n/a | n/a | redirected from `/troubleshooting/federation-nats` | No Phase-01 signals. |
| /operations/troubleshooting/by-database/postgresql | OK | 08 | PG | ? | redirected from `/troubleshooting/by-database/postgresql` | DB-specific. |
| /operations/troubleshooting/by-database/mysql | OK | 08 | MySQL | ? | redirected from `/troubleshooting/by-database/mysql` | DB-specific. |
| /operations/troubleshooting/by-database/sqlite | OK | 08 | SQLite | ? | redirected from `/troubleshooting/by-database/sqlite` | DB-specific. |
| /operations/troubleshooting/by-database/sqlserver | OK | 08 | MSSQL | ? | redirected from `/troubleshooting/by-database/sqlserver` | Cycle 4 updated `docs.microsoft.com/sql/sql-server/` → `learn.microsoft.com` (L818). |
| /operations/troubleshooting-guide | needs-rewrite | 02/03 | n/a | n/a | redirected from `/guides/troubleshooting`; parent dir `operations/troubleshooting/` exists | **Cycle 6 Reviewer follow-on:** `-guide` suffix is collision-avoidance; same merge candidate as `operations/deployment-guide` above. |
| /operations/faq | needs-update | 08 | n/a | n/a | redirected from `/guides/faq` | Cycle 4 swapped 2 `fraiseql/fraiseql/discussions` → `/issues`. |

### Databases

| Slug | State | Owning phase | DB claim | DB actual | Deps | Notes |
|------|-------|--------------|----------|-----------|------|-------|
| /databases | OK | 08 | all 4 | n/a | — | Section index. |
| /databases/compatibility | OK | 08 | all 4 | n/a | — | Matrix page. |
| /databases/postgresql | needs-update | 05 | PG | PG | LTree cross-link planned | Cycle 2 truncated frontmatter description to ≤155 chars. Phase 05 adds LTree cross-link. |
| /databases/mysql | OK | 08 | MySQL | MySQL (page-SQL only; not via server per FW-2 #327) | FW-2 | No Phase-01 signals. |
| /databases/sqlite | OK | 08 | SQLite | SQLite (page-SQL only; FW-2 #327) | FW-2 | No Phase-01 signals. |
| /databases/sqlserver | OK | 08 | MSSQL | MSSQL (page-SQL only; FW-2 #327) | FW-2 | No Phase-01 signals. |
| /databases/sqlserver-enterprise | needs-update | 08 | MSSQL | ? | FW-2 | Cycle 2 truncated frontmatter description to ≤155 chars. DB tabs present. |

### SDKs

| Slug | State | Owning phase | DB claim | DB actual | Deps | Notes |
|------|-------|--------------|----------|-----------|------|-------|
| /sdk | needs-rewrite | 02 | n/a | n/a | SDK release alignment | SDK release pin alignment (all SDKs pinned to v2.1.0 per Cycle 1 audit). |
| /sdk/python | needs-rewrite | 02 | n/a | n/a | SDK alignment | v2.1.0 pin. |
| /sdk/typescript | needs-rewrite | 02 | n/a | n/a | SDK alignment | v2.1.0 pin. |
| /sdk/go | needs-rewrite | 02 | n/a | n/a | SDK alignment | v2.1.0 pin. |
| /sdk/java | needs-rewrite | 02 | n/a | n/a | SDK alignment | v2.1.0 pin. |
| /sdk/rust | needs-rewrite | 02 | n/a | n/a | SDK alignment | v2.1.0 pin. |
| /sdk/php | needs-rewrite | 02 | n/a | n/a | SDK alignment | v2.1.0 pin. |
| /sdk/csharp | needs-rewrite | 02 | n/a | n/a | SDK alignment | v2.1.0 pin. |
| /sdk/elixir | needs-rewrite | 02 | n/a | n/a | SDK alignment | v2.1.0 pin. |
| /sdk/fsharp | needs-rewrite | 02 | n/a | n/a | SDK alignment | v2.1.0 pin. |
| /sdk/ruby | needs-rewrite | 02 | n/a | n/a | SDK alignment | v2.1.0 pin. |
| /sdk/dart | needs-rewrite | 02 | n/a | n/a | SDK alignment | v2.1.0 pin. |

### Confiture

| Slug | State | Owning phase | DB claim | DB actual | Deps | Notes |
|------|-------|--------------|----------|-----------|------|-------|
| /confiture | OK | 08 | n/a | n/a | — | Subsystem index. |
| /confiture/build | OK | 08 | n/a | n/a | — | No Phase-01 signals. |
| /confiture/migrate | OK | 08 | n/a | n/a | — | No Phase-01 signals. |
| /confiture/sync | OK | 08 | n/a | n/a | — | No Phase-01 signals. |
| /confiture/schema-to-schema | OK | 08 | n/a | n/a | — | No Phase-01 signals. |

### Examples

| Slug | State | Owning phase | DB claim | DB actual | Deps | Notes |
|------|-------|--------------|----------|-----------|------|-------|
| /examples | needs-rewrite | 03 | n/a | n/a | fraiseql/examples (4 URLs); demo.fraiseql.dev (1); pre-existing meta-citation | **Cycle 4 deferral A:** `fraiseql/examples` repo URLs (11 across 4 pages). Cycle 1: L23 server log + L355 / L359 `/health` example refresh + Phase-00-Cycle-2 meta-citation. **Cycle 5 Writer follow-on:** L355 contains `{/* source: Phase 00 / Cycle 2 GREEN transcript */}` — a meta-development citation flagged by Cycle 5 Reviewer as ARCHAEOLOGY-FREE candidate (strict-letter pass, spirit-of-the-rule fail); Phase 03 polish or Phase 10 finalisation sweeps it. **Cycle 1 Reviewer follow-on:** L359 `/health` example shape still says `"database": "connected"` (string) — actual server returns object form; refresh in Phase 02/03. |
| /examples/multi-tenant-saas | OK | 03 | ? | ? | — | Phase 03 examples pass. |
| /examples/saas-blog | OK | 03 | ? | ? | fraiseql/examples | **Cycle 4 deferral A:** `fraiseql/examples` URL. |
| /examples/realtime-collaboration | OK | 03 | ? | ? | fraiseql/examples | **Cycle 4 deferral A:** `fraiseql/examples` URL. |
| /examples/realtime-analytics | OK | 03 | ? | ? | — | Phase 03 examples pass. |
| /examples/mobile-analytics-backend | OK | 03 | ? | ? | fraiseql/examples | **Cycle 4 deferral A:** `fraiseql/examples` URL. |
| /examples/federation-ecommerce | OK | 03 | n/a | n/a | — | Phase 03 examples pass. |
| /examples/saas-federation-nats | OK | 03 | n/a | n/a | — | Cycle 1: L645 auth-service startup log version anchor fixed. L588 Apollo Federation directive pin (EXAMPLE — keep). |
| /examples/microservices-choreography | OK | 03 | n/a | n/a | — | Phase 03 examples pass. |
| /examples/nats-event-pipeline | OK | 03 | n/a | n/a | — | Phase 03 examples pass. |

### Community

| Slug | State | Owning phase | DB claim | DB actual | Deps | Notes |
|------|-------|--------------|----------|-----------|------|-------|
| /community/contributing | OK | 08 | n/a | n/a | — | Cycle 1: L65 bug-report template version placeholder fixed. Cycle 4: 3 `/discussions` → `/issues` swaps. |
| /community/code-of-conduct | OK | 08 | n/a | n/a | — | Boilerplate. |
| /community/support | needs-update | 03 | n/a | n/a | — | Cycle 4 swapped `status.fraiseql.dev` → prose "status page coming soon". **Cycle 4 Reviewer follow-on:** replace "coming soon" with a definite Issues pointer (Phase 03 or Phase 10). |
| /changelog | needs-rewrite | **02** | n/a | n/a | — | Cycle 1 explicitly deferred: header reads "v2.1 (Unreleased)" but v2.1.0 / v2.2.0 / v2.3.x have all shipped. Phase 02 owns the deep rewrite (release-notes hub). |
| /community/ai | needs-rewrite | 08 | n/a | n/a | redirected from `/ai` | Phase 08 polish. |
| /community/ai/generating-views | OK | 08 | n/a | n/a | redirected from `/ai/generating-views` | One internal LinkCard href reference (`/ai/generating-views`) now redirects. |
| /community/ai/python-client | OK | 08 | n/a | n/a | redirected from `/ai/python-client` | Phase 08 polish. |
| /community/ai/mcp-server | OK | 08 | n/a | n/a | redirected from `/ai/mcp-server` | Adjacent to Phase 06 MCP feature page (cross-link). |
| /community/ai/langchain | OK | 08 | n/a | n/a | redirected from `/ai/langchain` | Phase 08 polish. |
| /community/ai/llamaindex | OK | 08 | n/a | n/a | redirected from `/ai/llamaindex` | Phase 08 polish. |
| /community/use-cases/dotnet-teams | needs-update | 08 | MSSQL | ? | redirected from `/use-cases/dotnet-teams` | Cycle 2 truncated frontmatter (Reviewer noted minor SEO keyword loss "Dapper", "Windows Auth"). Cycle 4 swapped `install.fraiseql.dev` → releases-page comment. |
| /community/use-cases/python-teams | needs-update | 08 | n/a | n/a | redirected from `/use-cases/python-teams` | Cycle 2 frontmatter truncation. Cycle 4: `install.fraiseql.dev` + `fraiseql/specql` swaps. |
| /community/use-cases/saas-companies | OK | 08 | n/a | n/a | redirected from `/use-cases/saas-companies` | Phase 08 polish. |
| /community/use-cases/event-driven-teams | needs-update | 08 | n/a | n/a | redirected from `/use-cases/event-driven-teams` | Cycle 2 frontmatter truncation. |
| /community/vs/hasura | needs-rewrite | 03 | n/a | n/a | redirected from `/vs/hasura` | Cycle 4 swapped `install.fraiseql.dev` → releases-page comment. Phase 03 comparison rewrite. |
| /community/vs/hasura-sqlserver | needs-rewrite | 03 | MSSQL | n/a | redirected from `/vs/hasura-sqlserver` | Cycle 1: L17 + adjacent v2.0.2+ SQL Server Relay cursor anchors → v2.1+. Cycle 2 frontmatter truncation. Cycle 4 `install.fraiseql.dev` swap. |
| /community/vs/apollo | needs-rewrite | 03 | n/a | n/a | redirected from `/vs/apollo` | Phase 03 comparison rewrite. |
| /community/vs/prisma | needs-rewrite | 03 | n/a | n/a | redirected from `/vs/prisma` | Phase 03 comparison rewrite. |
| /community/vs/postgrest | needs-rewrite | 03 | n/a | n/a | redirected from `/vs/postgrest` | Phase 03 comparison rewrite. |
| /community/blog | OK | 08 | n/a | n/a | redirected from `/blog` | Phase 08 polish. |
| /community/blog/three-transports-one-binary | OK | 08 | n/a | n/a | redirected from `/blog/three-transports-one-binary` | Phase 08 polish. |
| /community/blog/why-grpc-skips-json | OK | 08 | n/a | n/a | redirected from `/blog/why-grpc-skips-json` | Phase 08 polish. |
| /community/blog/rest-annotation-driven | OK | 08 | n/a | n/a | redirected from `/blog/rest-annotation-driven` | Phase 08 polish. |
| /community/blog/eleven-languages-one-server | OK | 08 | n/a | n/a | redirected from `/blog/eleven-languages-one-server` | Phase 08 polish. |
| /community/blog/how-compilation-works | OK | 08 | n/a | n/a | redirected from `/blog/how-compilation-works` | Phase 08 polish. |
| /community/blog/rest-direct-execution-benchmark | needs-rewrite | 03 | n/a | n/a | velocitybench; redirected from `/blog/rest-direct-execution-benchmark` | **Cycle 4 deferral B:** `velocitybench` reference. Phase 03 benchmarks decision. |

### Top-level

| Slug | State | Owning phase | DB claim | DB actual | Deps | Notes |
|------|-------|--------------|----------|-----------|------|-------|
| / (index.mdx) | needs-update | 08 | n/a | n/a | — | Cycle 1 fixed Enterprise Features anchor (`v2.1.0 → v2.3.2`). No further open issues for Phase 01. Phase 08 polish. |

**Page-row total: 172.** Matches the Cycle 6 Reviewer count (172 pre-cycle, 172 post-cycle, page-count parity preserved).

## Framework bugs (not docs pages; Phase 09 reconciliation)

Two framework issues filed during Phase 00 and tracked in `_internal/.plan/framework-qa-triage.md`. Phase 09 (Framework Bug-Fixer persona) closes each via a PR against `~/code/fraiseql` (gate G4 per merge); Phase 09 Cleanup removes the affected pages' `## Known issues` blocks after merge.

| ID | Issue | Severity | Affects (page rows) | Phase 09 close path |
|----|-------|----------|---------------------|---------------------|
| FW-1 | https://github.com/fraiseql/fraiseql/issues/326 — `storage(azure,gcs): expose endpoint override` so Azurite + fake-gcs-server are reachable via config | qol | `/features/file-storage`, `/features/multi-database`, `/operations/observer-runbook` (storage callouts) | Add endpoint param to `AzureBackend::new` + `GcsBackend::new`; wire `StorageConfig.endpoint` through the `azure` / `gcs` arms of `create_backend`. Docs side: `/features/file-storage` removes the "S3 only end-to-end via FraiseQL server" caveat. |
| FW-2 | https://github.com/fraiseql/fraiseql/issues/327 — `fraiseql-server binary hardcodes PostgresAdapter` — quickstart multi-DB tabs unreachable | regression-or-doc-bug | `/getting-started/quickstart`, `/features/multi-database`, `/databases/mysql`, `/databases/sqlite`, `/databases/sqlserver`, `/databases/sqlserver-enterprise` | Wire `MySqlAdapter` / `SqliteAdapter` / MSSQL `tiberius` adapter into `fraiseql-server/src/main.rs:L240-L260` adapter factory. Docs side: quickstart multi-DB tabs go from aspirational to functional. |

## Cross-phase items (not docs pages)

These are meta-items the matrix tracks so they do not slip past Phase 10 finalisation. Phase ownership for each is named in parentheses; orphaned items default to Phase 10.

| Item | Owning phase | Description |
|------|--------------|-------------|
| Methodology §4 JSX-comment amendment | Phase 01 close OR 10 | Cycle 1 + Cycle 2 + Cycle 5 Reviewers all flagged: `{/* source: ... */}` is the MDX-3-compatible equivalent of `<!-- source: ... -->`. Land amendment in `_internal/.plan/methodology.md`. |
| `_sidebar-decision.md` §6 page-count nit (172 not 173) | Cycle 7 (this cycle, commit 2) OR 10 | Cycle 6 Reviewer flagged off-by-1; corrected at Cycle 7 close per the commit log. |
| Redirect-map regression test | Phase 02 OR 10 | Cycle 6 Writer §4-Q7 deferred + Cycle 6 Reviewer follow-on: `scripts/docs-test/redirects.docs-test.sh` (per-redirect probe) OR an Astro build-time check. Phase 02 if a Writer wants to fold it into the changelog-rewrite cycle; otherwise Phase 10. |
| Pre-commit hook activation | Phase 10 | Cycle 2 Cleanup deferred. Pre-requisite: fix the `SiteTitle.astro` baseline first (see next row). |
| `src/components/SiteTitle.astro` `virtual:starlight/user-images ts(2307)` baseline | Phase 10 | Pre-existing 1-error `bun run check` baseline. Cycle 1, 2, 3, 4 each confirmed it is unchanged by their work. Phase 10 cleanup. Not a docs-page row. |
| Compose-file SHA-literal duplication | Phase 09 OR 10 | Phase 00 / Cycle 9 deferred: `docker-compose.docs-test.yml` `args:` value is a literal SHA, not a read from `FRAISEQL_SHA`. Byte-identical today; G2-bump procedure documents the dual-flip requirement. |
| G4 branch-protection flip to require `page-test (_smoke)` | Phase 10 (human admin) | Phase 00 / Cycle 9 left as soft gate. |
| PR #11 (Phase 00 close) ready-for-review flip | human | Outside Writer scope. |
| PR #12 (Phase 01) draft → merge | After Phase 01 close | Reviewer-approved through Cycle 6; awaiting Phase 01 close cycle. |
| Delete `_internal/.plan/` + `_internal/_*.md` planning docs | Phase 10 | Eternal sunshine: this matrix and `_sidebar-decision.md` get deleted with the rest of the plan tree. |

## Cycle 4 deferrals (URL-level, not page-level)

Repeating here so a Phase 02/03 Writer can pull each defer class as a single ticket rather than per-page.

| Class | URL pattern | Pages affected | Owning phase | Content / infra decision |
|-------|-------------|----------------|--------------|--------------------------|
| A | `https://github.com/fraiseql/examples` and 11 sub-paths | `/examples/index` (4 hits), `/examples/saas-blog`, `/examples/realtime-collaboration`, `/examples/mobile-analytics-backend` | Phase 03 | Decide: (a) create the `fraiseql/examples` org repo + sub-repos; (b) rewrite the pages to drop "look at our code on GitHub" framing; (c) point at `fraiseql/fraiseql/examples/` if appropriate. |
| B | `velocitybench` | `/operations/performance-benchmarks`, `/community/blog/rest-direct-execution-benchmark` | Phase 03 | Decide: (a) create the repo; (b) rewrite to drop the "Independent data from VelocityBench" framing. |
| C | `demo.fraiseql.dev` | `/playground`, `/concepts/how-it-works`, `/features/mutual-exclusivity`, `/getting-started/quickstart`, `/features/automatic-where`, `/features/rich-filters` | Phase 02/03 + infra | Infra fix the TLS SAN mismatch on the demo subdomain OR rewrite the pages to drop the live-demo claim. |
| D | `charts.fraiseql.io` | 0 hits in `src/content/docs/` at Cycle 7 audit | n/a | Listed in the task brief but no current `src/` reference (Cycle 4 Reviewer confirmed orchestrator-side artefact). No row needed. |

## Adjacencies and shared partials (Cycle 1 + Cycle 6 Writer follow-ons)

The Cycle 1 Writer + Cycle 6 Writer suggested two shared-include opportunities. Phase 02/03 Writer may evaluate:

- **Federation "available as beta" prose:** three pages (`/features/federation`, `/building/federation-nats-integration`, `/building/advanced-federation`) share the verbatim sentence `Apollo Federation support is available as a beta feature.` Candidate for promotion to a shared partial.
- **Observers triple-overlap:** post-Option-A split is three pages (`/features/observers`, `/building/observers`, `/operations/observer-runbook`). Each plays a distinct role per `_sidebar-decision.md` §5 (what / how / run). Phase 03 should keep them as three distinct pages but ensure clear cross-links + scope statements; do NOT collapse.

## Owning-phase counts

Approximate row counts per owning phase (rounded; main matrix is the source of truth):

- Phase 02 — release-notes / migration / install / SDK alignment: **~22** rows (1 changelog + 4 getting-started + 2 install/cli alignment + 12 SDKs + 3 Cycle-1-Reviewer follow-ons).
- Phase 03 — critical rewrites + observers triple + concepts pass + comparisons + Cycle 4 deferrals A/B/C: **~48** rows.
- Phase 04 — new features part 1 (Studio, Functions WASM, Realtime): **3-4 missing + ~3 adjacent** rows.
- Phase 05 — new features part 2 (Auth ext, LTree, partial-period, native aggs): **~4 missing + 1 cross-link** rows.
- Phase 06 — transport + protocol (REST deepening, MCP, federation mTLS, trusted documents): **~12** rows.
- Phase 07 — reference rebuild: **13** rows (all of `/reference/*`).
- Phase 08 — sweep + polish + link-audit re-run: **~80** rows (the catch-all final-polish phase).
- Phase 09 — framework QA pass: **0 docs-page rows** (2 framework-bug rows + 5-6 affected-page side-effects).
- Phase 10 — finalize: **0 docs-page rows** (8 cross-phase rows above).

These do not sum to 172 because Phase 03 and Phase 08 share many rows (Phase 03 substantive rewrite; Phase 08 polish-of-the-rewrite); the matrix's `Owning phase` column names the **next substantive change**, not every subsequent touch.
