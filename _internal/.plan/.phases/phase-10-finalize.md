# Phase 10: Finalize

## Objective

Apply the Eternal Sunshine Principle to the entire overhaul. Remove all archaeology, ship a coherent docs release, and leave behind a repository that looks like it was written in one perfect session.

## Why this exists

Per the project methodology, every plan ends in Finalize. Without it, `Phase N` comments leak into shipped pages, `TODO: revisit` markers accumulate, the `.phases/` tree clutters the repo, and the docs read like a patchwork. With it, the docs ship as if every page were authored fresh by the same hand.

This is also where we measure: build time, Lighthouse, search coverage, redirect-map completeness, and announcement-readiness.

## Success criteria

- [ ] No `Phase N`, `TODO`, `FIXME`, `XXX`, `(coming soon)`, `(WIP)`, `(deprecated — see below)`, `<!-- old -->` anywhere in shipped output. `git grep -i ...` returns nothing.
- [ ] `/tmp/fraiseql-docs-overhaul/` is deleted; `.phases/` is removed from the docs repo (if it ever lived there); planning artifacts are wiped.
- [ ] `_internal/` directory exists in source but is excluded from build output and search index (verified by visiting the built site).
- [ ] Build time on the static export is ≤180s on a clean clone (regression budget: +20% over phase 00 baseline).
- [ ] Lighthouse score ≥95 across Performance / Accessibility / Best Practices / SEO on a representative page sample (homepage + one of each: getting-started, feature, guide, reference).
- [ ] Redirect map: every page that moved sidebar location during the overhaul has a redirect; every URL that ever appeared in the live site map still resolves (302 or 200).
- [ ] `astro check` clean; `bun run lint` clean; `bun run build` clean; `bun run typecheck` clean.
- [ ] Every page passes its `*.docs-test.sh` reproduction in CI.
- [ ] A `release-announcement.md` draft exists for the team to publish (blog post, changelog, or social).
- [ ] Snapshot SHA written into `.phases/README.md` (then deleted with the rest of `.phases/`).

## Scope (in)

- Archaeology sweep across every shipped page.
- Plan-artifact deletion (the entire `/tmp/fraiseql-docs-overhaul/` tree).
- Build-perf measurement and remediation if regressed.
- Lighthouse audit and remediation.
- Redirect map verification.
- Final tests / lints clean.
- Release announcement draft.
- Final reviewer sign-off across the entire overhaul.

## Scope (out)

- New content.
- Framework changes (those were phase 09's window).
- Long-term maintenance plan (separate document, drafted as part of the announcement).

## Dependencies

- **Requires:** Phase 09 complete.
- **Blocks:** Nothing in this plan. Ships.

## Personas involved

| Cycle | Personas |
|-------|----------|
| 1 (Archaeology sweep) | Cleanup (Sonnet 4.6) |
| 2 (Plan-artifact deletion) | Cleanup |
| 3 (Build perf) | Cleanup |
| 4 (Lighthouse) | Cleanup (Sonnet 4.6) escalating to Writer (Opus 4.7) if remediation requires content judgement |
| 5 (Redirect map) | Link Auditor (Haiku 4.5) → Cleanup |
| 6 (Final lint / test / build) | Cleanup |
| 7 (Release announcement draft) | Writer (Opus 4.7) |
| 8 (Final reviewer sign-off) | **Final Reviewer (Opus 4.7)** — substantial end-to-end read |
| 9 (Snapshot SHA + tag) | Cleanup |
| 10 (Plan artifact final deletion) | Cleanup |

## Human gates

- **G5** — final sign-off before tagging. The Final Reviewer persona produces a punch-list and sign-off note; the human reviews both and approves the tag. Blocking findings return to Writer for one final patch round before re-review. Non-blockers are deferred to a follow-on plan and logged in `_internal/.plan/follow-on-backlog.md` (which itself ships nowhere; the backlog is preserved only if useful, in `community/quality/` per cycle 2).

## TDD cycles

### Cycle 1: Archaeology sweep

- **RED:** `git grep -iE '(Phase [0-9]|TODO|FIXME|XXX|coming soon|WIP|stay tuned|to be added)' src/content/docs/` returns nonzero hits.
- **GREEN:** walk each hit:
  - If it's a deliberate "do-not-ship" leftover from earlier phases, delete it.
  - If it's a legitimate `## Known issues` block from phase 09 (links to an accepted limitation), it stays.
  - If it's a quotation from an external doc, it stays only if quoted with attribution.
- **REFACTOR:** consider whether any prose that *describes* development phases (e.g. on a release-notes page) reads OK. Most should — but check.
- **CLEANUP:** rerun the grep; result is empty (or has only quoted/inside-codeblock matches).

### Cycle 2: Plan-artifact deletion

- **RED:** `/tmp/fraiseql-docs-overhaul/` still exists; any `_internal/.phases/`, `_internal/sweep-matrix.md`, `_internal/framework-qa-triage.md` etc. in the repo still ship.
- **GREEN:**
  - Delete `/tmp/fraiseql-docs-overhaul/`.
  - Decide for each `_internal/` file: ship as a permanent contributor-facing doc (e.g. `_internal/style-guide.md` → `community/contributing/style-guide.md`) or delete.
  - Verify Astro build excludes `_internal/` from output (settings in `astro.config.mjs`).
- **REFACTOR:** consider preserving the `framework-qa-report.md` as a permanent record under `community/quality/` — it's a useful historical artifact.
- **CLEANUP:** the live build's URL list does not contain any planning-artifact URL.

### Cycle 3: Build performance check

- **RED:** measure `bun run build` time on a clean clone with cold caches.
- **GREEN:** if >180s:
  - Profile the build (`astro build --verbose`).
  - Identify slow pages or plugins.
  - Optimise: split large MDX pages, defer heavy components, prune unused remark/rehype plugins.
- **REFACTOR:** the budget is a long-term target; if the regression is within 20% of phase 00, it's acceptable.
- **CLEANUP:** measured time recorded in the report.

### Cycle 4: Lighthouse audit

- **RED:** run Lighthouse against the homepage, one getting-started page, one feature page (e.g. Studio), one guide page (e.g. multi-tenancy), one reference page (TOML).
- **GREEN:** any score <95:
  - Performance: image optimisation, lazy-load heavy embeds, defer non-critical CSS.
  - Accessibility: add missing alt text, fix landmark structure, contrast issues.
  - Best Practices: HTTPS-only links, no console errors, modern image formats.
  - SEO: meta description present, title length, semantic structure.
- **REFACTOR:** if a fix would compromise content quality, document the trade-off and accept the lower score with reasoning.
- **CLEANUP:** scores recorded in the report.

### Cycle 5: Redirect-map verification

- **RED:** during phase 01 IA work, several pages moved (e.g. `/concepts/observers` → `/features/observers`). The redirect map exists but is unverified.
- **GREEN:** script that:
  - Lists every URL ever live on the docs site (from past sitemaps / git history).
  - Issues GET against the current site; expects 200 or 302.
  - 404s fail the build.
- **REFACTOR:** any forward-link from a third-party source (Stack Overflow, GitHub issue comments) that we know about — verify those URLs still resolve.
- **CLEANUP:** the redirect map is fully verified.

### Cycle 6: Final lint / test / build

- **RED:** any leftover non-clean state.
- **GREEN:**
  - `astro check` clean.
  - `bun run lint` clean.
  - `bun run typecheck` clean.
  - `bun run build` clean.
  - CI green on the merge candidate branch.
- **CLEANUP:** the green run's URL is captured in the release announcement.

### Cycle 7: Release announcement draft

- **RED:** the overhaul has shipped a lot of content; nobody knows.
- **GREEN:** `release-announcement.md` (committed to the docs repo's root or wherever announcements live), structured as:
  - **What changed**: a one-paragraph summary.
  - **New pages**: Studio, Functions, Realtime, Auth Extensions, LTree, REST, MCP, Trusted Documents, Schema Integrity, Federation mTLS.
  - **Rewritten pages**: multi-tenancy, file-storage, observers, authentication.
  - **Reference rebuild**: CLI, TOML, operators.
  - **Migration guides**: v2.0→v2.3 chain.
  - **Framework QA**: bugs filed, fixed, accepted (linked to the report).
  - **How to read it**: the recommended entry points by audience (new user / existing user upgrading / operator / framework contributor).
- **REFACTOR:** keep it to one page; cross-link liberally to the actual content.
- **CLEANUP:** the announcement is ready for publish; the team has reviewed it.

### Cycle 8: Final reviewer sign-off

Persona: **Final Reviewer (Opus 4.7)**, invoked with the prompt in `personas.md`. Fresh context, no scroll-back from any prior persona. This is **human gate G5** at conclusion.

- **RED:** the overhaul has had per-phase Reviewer personas but no end-to-end reviewer covering cross-page consistency.
- **GREEN:** the Final Reviewer reads:
  - The release announcement.
  - 10 pages picked at random across sidebar groups.
  - 3 migration pages.
  - 1 random `*.docs-test.sh` and tries to break it from a fully reset Docker state.
  - The full handoff log (`_internal/.plan/handoff.md`) — including every escalation, every gate decision, and every accepted limitation.
- **REFACTOR:** any blocker findings go to Writer for one final patch round; non-blocking findings → follow-on backlog.
- **CLEANUP:** sign-off note committed; G5 proposal written to handoff; phase status `[?]` pending the human's tag-and-launch decision.

### Cycle 9: Snapshot SHA + tag

- **RED:** future writers won't know which FraiseQL SHA the docs were validated against.
- **GREEN:**
  - Final FraiseQL SHA written to a `_internal/validated-against.md` (or directly into the release announcement).
  - Docs repo tagged at the merge SHA (e.g. `docs-v2.3.2-launch`).
- **CLEANUP:** the snapshot is canonical; future drift is measurable from it.

### Cycle 10: Plan artifact final deletion

- **RED:** if anything from `/tmp/fraiseql-docs-overhaul/` survived previous cycles.
- **GREEN:** `rm -rf /tmp/fraiseql-docs-overhaul/`.
- **CLEANUP:** the directory is gone. Memory of the plan lives only in the framework-qa-report (if preserved) and the release announcement.

## Adversarial review protocol

The end-to-end reviewer (Cycle 8) is the only "review" this phase has. They:

1. Spend at least 4 hours with the site, reading.
2. Click through 50+ links.
3. Run at least 3 `*.docs-test.sh` from a fresh clone.
4. Note any breaks, ambiguities, or "I thought X but the page says Y."
5. Sign off only when they would themselves recommend this site to a friend asking about FraiseQL.

## Container verification matrix

| Test | Matrix |
|------|--------|
| All `*.docs-test.sh` | full matrix per page |
| `_smoke.docs-test.sh` from a cold clone | full matrix |
| `reference-parity.sh` | clean |
| External link audit | clean |
| Lighthouse on sampled pages | scores recorded |
| Redirect-map verifier | clean |

## Risks specific to this phase

| Risk | Mitigation |
|------|------------|
| Lighthouse fixes risk content regression | Trade-off documented; reviewer signs off on the trade-off |
| Build perf regression is hard to remedy without major refactor | Accept up to 20% over phase 00; beyond that, file a separate perf plan |
| External link audit re-runs may surface new dead links | Fix what we can; document audit date |
| Last-minute reviewer feedback expands scope | Blocking-only fixes ship; non-blocking → follow-on |
| The plan's `/tmp/` location means a crash could lose it mid-execution | Don't put final-state artefacts in `/tmp/`. Reports preserved in the docs repo go to `_internal/` or `community/` |

## Estimated effort

**Effort proxy: 1.** A genuine final pass — short, but every cycle matters. Cleanup-Sonnet for cycles 1–6. Writer-Opus for the release announcement (cycle 7). Final Reviewer-Opus for cycle 8 (substantial context — budget for a long single-session read). G5 sign-off bounds the wall-clock at the end.

## Status

- [ ] Not started
- [ ] RED in progress
- [ ] GREEN in progress
- [ ] REFACTOR in progress
- [ ] CLEANUP in progress
- [ ] Complete

## Owner

*(unclaimed)*

## Sign-off

Final reviewer: `<name>` — `<date>`
Plan owner: `<name>` — `<date>`

---

*This file is deleted as part of cycle 10. If you are reading this in the shipped repo, the plan failed — please file an issue.*
