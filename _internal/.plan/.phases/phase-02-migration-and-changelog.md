# Phase 02: Release notes + migration guides

## Objective

Make the docs site the canonical source for "what shipped in each release" and "how do I upgrade." Today, both stories live only in the framework repo (`CHANGELOG.md`, `docs/migration/v2.2-to-v2.3.md`); the docs site has no entry point.

## Why this exists

A reader pinned at v2.1.6 has no path on the public docs site to learn:
- That v2.2.0 introduced the Apollo Federation 2 full directive set and multi-tenancy.
- That v2.3.0 added Studio, Functions, Realtime, Storage, Auth Extensions, Hierarchies, and ~20 breaking changes in the Rust core.
- How to migrate their pinned version forward.

Without this phase, every other phase ships content that assumes a hypothetical "current reader" who has been following the GitHub repo. That assumption is wrong.

## Success criteria

- [ ] `/release-notes/` section in the sidebar with one page per shipped minor (`v2.0`, `v2.1`, `v2.2`, `v2.3`) summarising what shipped, with deep links into the relevant feature pages.
- [ ] `/migrations/upgrading/` section (separate from the existing `/migrations/from-*` which is for *other tools*) with one page per `vA.B → vC.D` jump.
- [ ] `v2.2-to-v2.3.md` mirrored from the framework repo (rewritten in docs-site voice, not a verbatim copy).
- [ ] Breaking-change matrix table on the v2.3 migration page: change → effort → mechanical?
- [ ] Every breaking change listed has at least one before / after code block.
- [ ] Every migration sed line is reproducible in a container.
- [ ] `index.mdx` "Enterprise Features" card grid links into the new release notes.
- [ ] Cross-links: every feature page introduced in 04–06 links back to its release-notes entry.

## Scope (in)

- `src/content/docs/release-notes/index.md`
- `src/content/docs/release-notes/v2.0.md`
- `src/content/docs/release-notes/v2.1.md`
- `src/content/docs/release-notes/v2.2.md`
- `src/content/docs/release-notes/v2.3.md`
- `src/content/docs/migrations/upgrading/index.md`
- `src/content/docs/migrations/upgrading/v2.1-to-v2.2.md`
- `src/content/docs/migrations/upgrading/v2.2-to-v2.3.md`
- (optional) `src/content/docs/migrations/upgrading/v2.0-to-v2.1.md` if there are non-trivial breaking changes
- Sidebar additions.
- Cross-links from `index.mdx`.

## Scope (out)

- Feature pages themselves — those are 03–06.
- Migrations *from other tools* (`/migrations/from-apollo`, etc.) — those are touched in phase 08's sweep.
- Future v2.4 release notes — out of scope; this plan freezes at v2.3.2.

## Dependencies

- **Requires:** Phase 01 sidebar IA decision (G1 resolved) so we know whether `release-notes/` is a top-level sidebar entry or nested.
- **Blocks:** Phase 03+ (which want to deep-link into release notes from the rewritten feature pages).

## Personas involved

| Cycle | Personas |
|-------|----------|
| 1–5 | Writer (Opus 4.7) → Source-Citation Verifier (Sonnet 4.6) → Reviewer (Opus 4.7) → Cleanup (Sonnet 4.6) |
| 6 (Cross-link integration) | Cleanup |
| 7 (Style audit) | Style Auditor (Sonnet 4.6) → Cleanup |

## TDD cycles

### Cycle 1: Release-notes index + v2.0 / v2.1

- **RED:** `/release-notes` returns 404 on the live site.
- **GREEN:** create the four release-notes pages. For each:
  - One paragraph summary.
  - Headline features (3–5 bullets, each linking to its feature page if one exists yet — otherwise to a placeholder slug owned by the relevant later phase).
  - Breaking changes (table).
  - Security fixes (list with CVE / advisory link if any).
  - Deprecations.
- **REFACTOR:** ensure tone matches CHANGELOG.md (terse, factual). No marketing.
- **CLEANUP:** v2.0 + v2.1 pages container-verified — every `cargo install fraiseql@2.0.0` style claim either runs or is dropped.

### Cycle 2: v2.2 release notes

- **RED:** v2.2 is where multi-tenancy, three-state CRUD updates, full Apollo Federation 2 directive set, schema metadata endpoint, mutation audit tracing, usage aggregation, native column support in aggregations land. None of these exist on the docs site yet.
- **GREEN:** the page summarises each, with TBD-link placeholders to the feature pages (phases 04–06 fill them in). For each breaking change, a before / after.
- **REFACTOR:** the multi-tenancy bullet links forward to the phase-03 rewritten page; the federation bullet links to phase-06 federation-mTLS page; the three-state CRUD bullet links to phase-05's mutation-semantics page.
- **CLEANUP:** every cross-link slug is recorded in the sweep matrix as a forward-dep on the relevant phase.

### Cycle 3: v2.3 release notes — the big one

- **RED:** v2.3 has ~20 breaking changes (error taxonomy consolidation, Storage→File error migration, ViewName newtype, `ServerError::RuntimeError`→`Engine`, etc.) plus all the new subsystems. The framework's CHANGELOG-Unreleased + 2.3.0 + 2.3.1 + 2.3.2 sections together run ~700 lines.
- **GREEN:** structure the page as:
  1. **Headline subsystems** (Studio, Functions, Storage, Realtime, Auth Extensions, Schema Migrations CLI, Hierarchies, REST transport) — each one paragraph linking forward.
  2. **Security hardening** (S33–S48 + cache RLS guard + subscription tenant isolation + HTTP allowlist default + Vault hardening + token Debug redaction + Secret zeroize-on-drop).
  3. **Performance** (parsed-query AST cache, response cache, lock-free reads, TCP_NODELAY + gated compression default change, etc.).
  4. **Breaking changes** (the migration table).
  5. **Bug fixes** (top 10 by impact).
- **REFACTOR:** the breaking-change table is the migration guide's TL;DR. Make them line up.
- **CLEANUP:** every claim cross-references the source commit SHA (`cf3a202cd` etc.). Reviewer spot-checks ten.

### Cycle 4: v2.2-to-v2.3 migration guide

- **RED:** the framework's `docs/migration/v2.2-to-v2.3.md` is comprehensive but written for Rust adopters with crate-level customisations. The docs-site version targets a broader audience.
- **GREEN:** rewrite each numbered section from the upstream guide as a docs-site page section:
  1. Error taxonomy consolidation (`RuntimeError` removal) — `sed -i 's/use fraiseql::RuntimeError/use fraiseql::FraiseQLError/g'` style.
  2. `FraiseQLError::Storage` → `FraiseQLError::File(FileError::*)` — table mapping `code` strings to variants.
  3. `ServerError::RuntimeError` → `ServerError::Engine`.
  4. `ViewName` newtype.
  5. `ProjectionRequest` struct argument.
  6. `KeyedRateLimiter<C: Clock>`.
  7. `extract_root_field_names` returning `impl Iterator`.
  8. Lock-free reads (no migration; behaviour note).
  9. `parking_lot::Mutex` swap (drop the `.await`).
  10. `MetricsCollector` flattened.
  11. `ParsedQuery.source: Arc<str>`.
  12. `ValidationRule::Pattern` taking `CompiledPattern`.
  13. Workspace clippy denials.
  14. `CompiledSchema::from_json(json, strict_integrity)`.
  15. `#[non_exhaustive]` rollout to public DTOs.
  16. Removed types (`MeEnrichmentConfig`, schema intermediate dispatch).
- **REFACTOR:** add a "Before you start" preamble (MSRV note, backup branch advice).
- **CLEANUP:** every sed pattern in the page runs against a sample crate in a container and produces the expected diff. If any does not, the page is wrong.

### Cycle 5: v2.1-to-v2.2 migration guide

- **RED:** v2.2 had one big breaking change (mutation response format consolidation) plus the Apollo Federation 2 directive set additions.
- **GREEN:** the mutation response migration is the focus. Walk through:
  - Removing the `schema_version` dispatch in custom apps.
  - The `app.mutation_response` canonical format.
  - Typed `MutationErrorClass` replacing the v1 string-status parser.
- **REFACTOR:** include a "no migration needed if you never used v1" callout up top; most adopters didn't.
- **CLEANUP:** verify the mutation-response shape claim against the actual `crates/fraiseql-core/src/runtime/mutation/...` source.

### Cycle 6: Cross-link integration

- **RED:** the new pages exist but nothing links to them.
- **GREEN:**
  - `index.mdx` "Enterprise Features" card grid → release notes hub.
  - Each "What's new in v2.X" link to its release-notes page.
  - Each feature page placeholder (Studio, Functions, etc.) is marked in the sweep matrix as "links from /release-notes/v2.3".
  - The existing `/migrations/index.md` page distinguishes "Upgrading FraiseQL" from "Migrating from other tools" with two clear paths.
- **REFACTOR:** sidebar entries titled to match: `Upgrading` (FraiseQL→FraiseQL) and `Switching tools` (Apollo / Hasura / Prisma / REST → FraiseQL).
- **CLEANUP:** every cross-link verified by clicking from one of three representative pages.

### Cycle 7: Phase-close style audit

Persona: Style Auditor (Sonnet 4.6) → Cleanup (Sonnet 4.6).

- **RED:** five new pages produced this phase by the Writer persona across multiple invocations. Voice and terminology may have drifted.
- **GREEN:** Style Auditor reads every page in `## Pages completed`, produces an edit list at `_internal/.plan/style-audits/phase-02.md` against the style guide. Particular attention to: tone of the migration callouts (must be terse, factual), terminology consistency ("upgrade" vs. "migrate" vs. "switch"), CHANGELOG-citation format.
- **CLEANUP:** Cleanup persona applies every entry from the edit list. Handoff updated.

## Adversarial review protocol

1. Reviewer checks each release-notes page against `~/code/fraiseql/CHANGELOG.md` at the frozen SHA. Any claim not in the CHANGELOG is suspicious.
2. Reviewer runs each sed snippet from the migration guide against a sample v2.2 codebase mounted into the FraiseQL container. The diffs must be exactly what the page claims they will be.
3. For the v2.2-to-v2.3 page: reviewer takes the FraiseQL repo itself at the v2.2.0 tag, applies every migration, and the resulting code must compile (or fail in the way the page predicts).
4. Reviewer fills the 12-point checklist.

## Container verification matrix

| Page | Verification approach |
|------|------------------------|
| `release-notes/v2.X.md` | For each "added X" claim, container test that X is reachable in v2.X.0 |
| `migrations/upgrading/v2.2-to-v2.3.md` | A scripted upgrade: clone FraiseQL at v2.2.0, apply each migration section, `cargo check` succeeds; capture transcript |
| `migrations/upgrading/v2.1-to-v2.2.md` | Similar: v2.1.6 → v2.2.0; mutation response migration runs a query that exercises the new shape |

## Risks specific to this phase

| Risk | Mitigation |
|------|------------|
| The framework's CHANGELOG has minor errors and we propagate them | Reviewer cross-checks at the commit level, not just the CHANGELOG. Errors get filed against the framework. |
| Mirrored migration guide drifts from the upstream version | Both ship; the docs-site version is the canonical reader-facing one; the framework's `docs/migration/` is the adopter-facing one. Discrepancies are reconciled in phase 09. |
| Adopters pin to v2.0 / v2.1 and need a v2.0→v2.3 jump guide | We don't write that explicitly; the v2.0→v2.1, v2.1→v2.2, v2.2→v2.3 chain covers it. If demand surfaces, add it in phase 09. |

## Estimated effort

**Effort proxy: 1.** Most of the content already exists in `~/code/fraiseql/CHANGELOG.md` and `docs/migration/`; this phase is shape + tone + verification. Writer-Opus for the v2.3 page (large, judgement-heavy); Writer-Opus also for the sed-pattern verification (each pattern must run against a sample crate in a container). Style Auditor pass at close.

## Status

- [ ] Not started
- [~] RED in progress (Cycle 1 — release-notes index + v2.0 + v2.1 pages)
- [ ] GREEN in progress
- [ ] REFACTOR in progress
- [ ] CLEANUP in progress
- [ ] Complete

Opened 2026-05-29 against `main@f6d9e1c` (Phase 01 squash). Phase 02 worklist is the sweep matrix's `Owning phase = 02` slice (`src/content/docs/_internal/_sweep-matrix.md`).

## Owner

*(unclaimed)*

## Pages completed

- Cycle 1 (2026-05-29): `release-notes/index.mdx`, `release-notes/v2-0.mdx`, `release-notes/v2-1.mdx`. Reviewer-approved at commit `4280c3c`.
- Cycle 2 (2026-05-29): `release-notes/v2-2.mdx` (new); `release-notes/index.mdx` v2.2 row promoted from forthcoming to released; `astro.config.mjs` v2.2 sidebar entry added.

## Framework bugs filed

*(any CHANGELOG inconsistencies discovered; any migration sed that doesn't produce the predicted diff)*
