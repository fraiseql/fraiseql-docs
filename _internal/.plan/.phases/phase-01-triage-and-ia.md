# Phase 01: Triage and information architecture

## Objective

Land all the quick-win stale-fact fixes, take the dead-link inventory, and make the sidebar / IA decision that every subsequent phase depends on.

## Why this exists

Two unrelated concerns share this phase because they're both *cheap*, both *blocking*, and both *don't fit in a content phase*:

1. **Stale facts** — wrong version strings, broken Homebrew claim, the `# fraiseql 2.0.0` output in `installation.md`. These are 5-minute fixes that shouldn't gate a 2-week content rewrite.
2. **IA / sidebar** — phases 04–06 add Studio, Functions, Realtime, Auth Extensions, LTree, Schema Migrations, REST, MCP, Trusted Documents. Where does each one live? `features/` is already crowded. `concepts/` and `guides/` are sometimes redundant. Settling this once means no phase has to revisit it.

## Success criteria

- [ ] Every stale version reference in `src/content/docs/` corrected (audit-driven, not eyeball-driven).
- [ ] Every dead internal link resolved.
- [ ] Every external link verified live (at least HTTP 200 at audit time).
- [ ] Sidebar IA decision documented and merged.
- [ ] `src/content/docs/_internal/sweep-matrix.md` lists every page with its phase assignment, status (`needs-rewrite | needs-update | needs-verification | OK`), DB matrix, and any cross-phase dependencies.
- [ ] `astro.config.mjs` sidebar structure matches the new IA.
- [ ] Build clean. Lighthouse score not regressed.
- [ ] Adversarial reviewer signs off.

## Scope (in)

- Mechanical version-string sweep across all 134 pages.
- Link audit (internal + external).
- Sidebar IA proposal, decision, and implementation.
- Sweep matrix (the master tracking doc the rest of the overhaul reads).
- `index.mdx` version-string correction (`v2.0.0-alpha is production-ready` → `v2.3.2`).
- `getting-started/installation.md` corrections (`# fraiseql 2.0.0` → current; verify Homebrew claim; fix stray ```` ```python ```` fence after Homebrew block).
- `getting-started/quickstart.mdx` version sweep.

## Scope (out)

- Any content rewrite beyond version strings and stray syntax. Real rewrites are phase 03.
- New pages — phases 04–06.
- Reference rebuild — phase 07.

## Dependencies

- **Requires:** Phase 00 complete (container harness available for the rare claim worth verifying during triage; `_internal/.plan/` populated; FRAISEQL_SHA frozen).
- **Blocks:** Phases 02–08. Sidebar shape is needed before phase 04 wires in the first new feature page.

## Personas involved

| Cycle | Personas |
|-------|----------|
| 1 (Version sweep) | Writer (Opus 4.7) for the diff-against-CHANGELOG judgement → Cleanup |
| 2 (Stray syntax) | Cleanup (Sonnet 4.6) |
| 3 (Internal link audit) | Cleanup; escalate to Writer if a link target requires structural decision |
| 4 (External link audit) | Link Auditor (Haiku 4.5) → Cleanup |
| 5 (Homebrew verification) | Writer (judgement call: keep section, remove, or file release-tooling issue) |
| 6 (Sidebar IA proposal) | Writer drafts proposal; **G1 human gate** |
| 7 (Sweep matrix) | Writer (initial authoring) → Cleanup |

## Human gates

- **G1** — Sidebar IA decision. Cycle 6. The Writer persona drafts Options A / B / C with rationale and writes them to `_internal/.plan/handoff.md`. The human picks one. Cycles 1–5 may proceed in parallel with the gate (they don't depend on the IA outcome); cycle 7 (sweep matrix) and downstream phases 02–08 depend on G1's resolution.

## TDD cycles

### Cycle 1: Audit-driven version sweep

- **RED:** run `grep -rE '\bv?(2\.[0-2]\.[0-9]+|2\.0\.0-(alpha|beta))\b' src/content/docs/` and capture every hit. Compare each line against `~/code/fraiseql/CHANGELOG.md` to determine whether it's stale.
- **GREEN:** edit each stale reference. Where a page makes a "FraiseQL is at version X" claim that will drift again, replace it with an "as of v2.3.2" parenthetical or remove the version anchor entirely.
- **REFACTOR:** consolidate "current version" mentions to a single source — either a Starlight global or a partial. Decide and commit.
- **CLEANUP:** the same grep returns zero hits or returns only intentional historical references (e.g. CHANGELOG mirror in phase 02). Commit.

### Cycle 2: Stray-syntax sweep

- **RED:** run `astro check` and capture every warning. Run `bun run lint` and capture every error.
- **GREEN:** fix:
  - `installation.md:38` stray ```` ```python ```` fence after the Homebrew block.
  - Any other code-fence imbalance.
  - Any frontmatter where `description` exceeds 155 chars (would clip in search snippets).
  - Any `import` statement in `.md` files (should be `.mdx`).
- **REFACTOR:** add `bun run lint` to `pre-commit` hook config so future drift doesn't reaccumulate.
- **CLEANUP:** lint clean. `astro check` clean.

### Cycle 3: Internal link audit

- **RED:** `astro check` will surface most dead internal links; supplement with a script that recursively follows every `[text](/path)` against the rendered site map.
- **GREEN:** fix every broken internal link. For links to pages that don't exist yet (Studio, Functions, etc. — phases 04–06), add the *target* slug to the sweep matrix as a forward dependency rather than leaving a dead link.
- **REFACTOR:** if a page is referenced from 5+ places under different slugs (e.g. `/concepts/observers` vs `/features/observers`), standardise on one.
- **CLEANUP:** zero dead internal links.

### Cycle 4: External link audit

- **RED:** script that GETs every external URL, captures HTTP status + redirect chain. Save as `_internal/external-link-audit.json` (gitignored).
- **GREEN:** for each non-200:
  - 404: replace with archive.org snapshot or remove.
  - 3xx redirect chain ≥3 hops: update to the final URL.
  - 200 but content changed: case-by-case (likely most are fine).
- **REFACTOR:** prefer GitHub permalinks (`/blob/SHA/...`) over `main`-tracking links where the content is version-sensitive.
- **CLEANUP:** all external links return 200 at audit time; document the audit date in `_internal/external-link-audit.md` so phase 08 knows when to redo it.

### Cycle 5: Homebrew claim verification

- **RED:** the `installation.md` page claims `brew install fraiseql` works. Verify:
  - `brew search fraiseql`
  - `gh search repos --owner Homebrew --topic fraiseql` (or whatever the official tap is)
  - Cross-check `~/code/fraiseql/releasing.md` for any Homebrew tap mention.
- **GREEN:** if no tap exists, remove the Homebrew section. If a tap exists but isn't in the install matrix, add it. If a tap exists but isn't current, fix and file a release tooling issue.
- **REFACTOR:** consolidate install paths under one decision table (Cargo / install script / pre-built binaries / Docker).
- **CLEANUP:** every install path documented is one a reader can actually use today.

### Cycle 6: Sidebar IA proposal — human gate G1

Persona: Writer drafts the proposal; the human decides. The Writer does NOT pick one.

- **RED:** the current sidebar groups `concepts/`, `features/`, `guides/`, `reference/` but the boundary is blurry. Phase 04's three new pages (Studio, Functions, Realtime) could each plausibly land in two of those groups.
- **GREEN:** write the proposal to `_internal/.plan/handoff.md` with all three options stated, the default proposal called out, and a one-line cost/benefit per option. Mark phase status `[?]`. Stop. The human resolves G1 by writing their pick into the handoff.

  **Option A — by audience:**
  - Getting Started
  - Core Concepts (philosophy + architecture)
  - Building (guides: how do I X)
  - Features (one page per subsystem)
  - Reference (CLI, TOML, GraphQL API, scalars, operators)
  - Operations (deployment, observability, troubleshooting)
  - Databases (one per supported DB)
  - SDK
  - Community

  **Option B — by lifecycle stage:**
  - Quick Start
  - Building
  - Running
  - Scaling
  - Reference

  **Option C — keep current shape, just add a `Subsystems` group** under which Studio / Functions / Realtime live.

  Default proposal: **Option A**. Rationale: a feature like "Functions (WASM)" naturally belongs in `Features`, while "How do I trigger a Slack notification?" naturally belongs in `Guides`, and "What's the philosophy here?" belongs in `Concepts`. The trichotomy already exists; we just sharpen it.

- **REFACTOR:** redraw `astro.config.mjs` sidebar. Add redirect rules in `astro.config.mjs` for any URL that moves (e.g. `/concepts/observers` → `/features/observers` if observers move from concepts to features).
- **CLEANUP:** every existing page still resolves either at its old URL (via redirect) or has been moved with the redirect in place. Document the moves in `_internal/sidebar-decision.md`.

### Cycle 7: Sweep matrix authored

- **RED:** there's no master plan of which page each phase touches. Without it, phases 03–08 don't know what's in their scope.
- **GREEN:** author `src/content/docs/_internal/sweep-matrix.md` (or a markdown table inside `.phases/`) with one row per page:
  - Slug
  - Current state (`OK | stale-version | broken-snippet | wrong-content | missing`)
  - Phase that owns the next change
  - DB matrix (which DBs the page claims, which it actually works on)
  - Cross-phase deps ("waits on phase 03 rewrite before phase 08 sweeps")
- **REFACTOR:** sort by phase, then by sidebar order, so phases can read their slice quickly.
- **CLEANUP:** committed; every page accounted for.

## Adversarial review protocol

1. Reviewer runs `bun run build` from a fresh clone. Build is clean.
2. Reviewer runs `astro check`. Clean.
3. Reviewer runs the external-link audit script. Reports match Cycle 4 snapshot.
4. Reviewer browses 10 pages picked at random in dev mode. No version drift, no dead links.
5. Reviewer inspects the sidebar IA: every entry resolves, every redirect works.
6. Reviewer reviews the sweep matrix for omissions — every page in `src/content/docs/` has a row.
7. Reviewer signs off on `## Status`.

## Container verification matrix

This phase doesn't usually need containers. Two exceptions:

| Claim audited | Verification |
|---------------|--------------|
| `brew install fraiseql` | macOS Homebrew (out-of-container; manual check) |
| `cargo install fraiseql` printed version | Container: `docker compose run --rm fraiseql fraiseql --version` |

## Risks specific to this phase

| Risk | Mitigation |
|------|------------|
| Sidebar move breaks deep links from external sites | Aggressive redirect-rule additions; redirect-map regression test in CI |
| Version-string anchor creates new drift point | Cycle 1's REFACTOR step decides between "no anchor" and "single source"; the decision is logged |
| Sweep matrix becomes stale during overhaul | Each phase touches its rows on close-out; phase 09 reviews the whole matrix |

## Estimated effort

**Effort proxy: 1.** Cycles 1–5 are mechanical (Sonnet-heavy) and run while G1 is pending. Cycle 6 stops at G1 — wall-clock depends entirely on human turnaround on the IA decision. Cycle 7 (sweep matrix) is Writer-Opus on a substantial table; budget for it accordingly. External link audit (Haiku) is cheap.

## Status

- [ ] Not started
- [ ] RED in progress
- [ ] GREEN in progress
- [~] REFACTOR in progress (Cycle 6 — Option A implementation: sidebar redraw, ~40 page moves, redirects, sidebar-decision.md)
- [ ] CLEANUP in progress
- [ ] Complete
- G1 resolved 2026-05-29: **Option A** (no modifications). Cycles 1–5 closed and approved by Reviewer. Cycle 6 GREEN/G1 proposal landed (commit `5ac2593`). Cycle 6 REFACTOR/CLEANUP now driving the Option A implementation; Cycle 7 (sweep matrix) authored against the new shape; Phase 01 close after.

## Owner

*(unclaimed)*

## Pages completed

*(append as cycles close — for this phase, "completed" means the audit row in the sweep matrix is signed off, not that the page is fully overhauled)*

## Framework bugs filed

*(unlikely from this phase; possible from the Homebrew claim if it surfaces a release-tooling regression)*
