# FraiseQL Documentation Overhaul — Multi-Month Plan

**Target codebase:** `~/code/fraiseql` (currently `v2.3.2`, `main`)
**Target docs site:** `~/code/fraiseql-docs` (Astro / Starlight, branch `main`)
**Plan opened:** 2026-05-28
**Execution model:** Claude Code, sequentially, across multiple persona invocations. See `methodology.md § 2` and `personas.md`.
**Effort sizing:** The "Effort" column in the phase index below is a rough proxy for content volume, retained as a planning unit. Wall-clock execution time is paced by container-test runtime, CI wait, and human-gate latency — not by writer fatigue.

---

## What this is

The FraiseQL documentation site has fallen ~3 minor versions behind the framework. Roughly half of the published pages describe an older Python-decorator-flavoured product. Several pages — `guides/multi-tenancy.md`, `features/file-storage.md`, parts of `concepts/observers.mdx` — describe a *different* product than what the Rust code actually ships. Entire flagship subsystems (Studio, Functions/WASM, Realtime internals, Auth Extensions, LTree, Schema Migrations CLI, REST transport, MCP, Trusted Documents) have **zero** coverage on the site despite shipping in v2.2.0 / v2.3.0.

This plan does not just "update the docs." It treats the docs overhaul as a **framework QA exercise**: every documented claim must be reproduced against a fresh, containerized FraiseQL deployment. If the docs say something the framework doesn't actually do, that is either a doc bug *or* a framework bug — and in either case, it gets filed and fixed before the page is allowed to ship.

## Why a multi-month plan

The scope is large enough that ad-hoc work guarantees inconsistency:

- **>18 missing top-level features.** Each needs a coherent reference page + at least one verified worked example.
- **4 actively misleading pages** to rewrite. These cannot be left in place while new work proceeds — they're shipping wrong information today.
- **Reference rebuild.** CLI doc covers 6 subcommands; the binary has ~24. TOML doc covers ~30% of the actual config surface.
- **18-week steady cadence at ~1 phase/week** is what produces documentation that survives the next two minor releases. Shorter timelines compress out the verification phases — which is exactly the thing we cannot compress out, because the gap exists *because* verification was compressed out last time.
- **Framework bugs will surface.** Any docs effort that takes the codebase seriously as ground truth will find them. We budget for that explicitly rather than treating it as scope creep.

## Operating principles

These are non-negotiable. Each phase plan restates them.

1. **Code is ground truth.** The framework's behaviour at the current commit defines reality. Docs that contradict the code are wrong, full stop — never the other way around.
2. **No future-state documentation.** If a feature exists in `roadmap.md` but not in `CHANGELOG.md` for a released version, it does not get a doc page. We document what shipped, not what's planned.
3. **Every claim is reproducible.** Every config example, every CLI invocation, every GraphQL query, every SQL view must run end-to-end against a fresh Docker-spun stack on at least one supported database. Snippets that cannot be exercised are deleted, not "fixed up to look plausible."
4. **Adversarial pairing on every page.** A "writer" produces the page; a "reviewer" attempts to break it: edge cases, wrong-database paths, missing config, version drift. The reviewer is **not** the writer.
5. **Bugs surfaced during doc work are framework issues, not doc issues.** They get filed against `~/code/fraiseql` and either fixed (preferred) or explicitly documented as known limitations with an issue link. Papering over a real bug in prose is forbidden.
6. **Phased delivery, not big bang.** Each phase ships a reviewable, self-contained PR. The docs site stays consistent at every point — never half-old / half-new.
7. **TDD discipline applies to docs.** RED = write the failing reproduction (page renders broken, link is 404, code snippet fails in container). GREEN = make it pass. REFACTOR = improve prose. CLEANUP = lint, format, sidebar wiring.
8. **No phase markers ship.** Per the project methodology, the `.phases/` tree, `<!-- Phase N -->` comments, `TODO`/`FIXME` breadcrumbs, and any other archaeology are scrubbed during the Finalize phase before the docs ever go live.

## Methodology summary

See `methodology.md` for the full version and `personas.md` for the execution roles. Compressed form:

- **Persona-based execution.** Each phase advances through distinct Claude Code sessions: Writer, Reviewer, Bug-Finder, Style Auditor, Cleanup, Source-Citation Verifier, Link Auditor, Framework Bug-Fixer, Final Reviewer. Personas do not share context; handoff is via `_internal/.plan/handoff.md`. The adversarial property requires each persona to be invoked with its documented prompt, not improvised.
- **Model split.** Opus 4.7 for judgement-heavy roles (Writer, Reviewer, Bug-Finder, Framework Bug-Fixer, Final Reviewer). Sonnet 4.6 for mechanical pattern work (Style Auditor, Cleanup, Source-Citation Verifier). Haiku 4.5 for the cheapest checks (Link Auditor).
- **Container harness.** A `docker-compose.docs-test.yml` under `/scripts/docs-test/` spins up: PostgreSQL 16, MySQL 8, SQLite (volume-mounted), SQL Server 2022, Redis 7, NATS, optionally MinIO / Azurite / fake-GCS, plus a freshly built `fraiseql-server` from the current `~/code/fraiseql` checkout. Every page's snippets get a `.docs-test.sh` companion that runs in CI.
- **CI is the only GREEN gate.** Writer-persona declarations of "I ran it locally and it passed" are not evidence. A page advances only when the docs-test workflow has passed on a fresh CI runner against the Writer's branch HEAD. See `methodology.md § 6.1`.
- **Source-citation discipline.** Every factual claim in a draft is annotated with `<!-- source: path:Lstart-Lend -->`. The Source-Citation Verifier persona confirms each citation against the frozen FraiseQL SHA before stripping; failed citations kick the page back to the Writer.
- **Adversarial-review checklist.** A 15-point checklist (see `templates/adversarial-review-template.md`) covering: version drift, wrong-DB code paths, missing-feature-flag paths, security-sensitive defaults, SDK divergence, dead links, undefined symbols, copy-paste from prior version, conditional caveats, RLS interactions, error-path coverage, archaeology check, source-citation resolution, persona self-reference, dark-mode rendering.
- **Per-page exit gate.** A page does not merge until:
  1. CI docs-test green on at least one DB (PostgreSQL minimum; multi-DB pages green on all claimed DBs).
  2. Reviewer persona signs off 15/15 in a fresh context.
  3. Source-Citation Verifier reports all citations resolved.
  4. Any framework bug uncovered has an issue filed and either (a) fixed or (b) called out on the page with the issue link.
  5. Sidebar entry, frontmatter, and cross-links updated.
- **Human gates.** Five planned gates pause Claude execution for human decision: G1 sidebar IA, G2 SHA-bump policy, G3 ship-readiness threshold, G4 per-framework-PR merge, G5 final sign-off. See `methodology.md § 2`.

## Phase index

See `.phases/README.md` for the live status board. High-level shape:

| # | Phase | Theme | Effort |
|---|-------|-------|------:|
| 00 | Foundation | Doc-test harness, container compose, CI gating, sidebar IA prep, plan-into-repo move | 2 |
| 01 | Triage & IA | Stale-fact sweep, version sweep, sidebar restructure decision (G1), dead-link audit | 1 |
| 02 | Migration & changelog | Release-notes index, v2.0→v2.3 migration pages, breaking-change matrix | 1 |
| 03 | Critical rewrites | multi-tenancy, file-storage, observers, authentication (the four misleading pages) | 2 |
| 04 | New feature docs (part 1) | Studio admin dashboard, fraiseql-functions (WASM), Realtime subsystem internals | 2 |
| 05 | New feature docs (part 2) | Auth extensions (magic links, TOTP, social, MFA, SMS OTP), LTree hierarchies, partial-period aggregates, native aggregation columns | 2 |
| 06 | Transport & protocol | REST transport, MCP, federation mTLS + plan viz, schema integrity, trusted documents | 1.5 |
| 07 | Reference rebuild | CLI (24 subcommands), TOML (full surface), operators (network + camelCase + ltree) | 2 |
| 08 | Cross-doc sweep & link audit | All other feature pages reviewed for v2.3.2 correctness; broken links; SDK status reconciliation; screenshots regenerated | 1.5 |
| 09 | Framework QA pass | All framework bugs surfaced during phases 01–08 triaged, fixed (G4 per PR), or explicitly noted | 1 |
| 10 | Finalize | Archaeology removal, sidebar polish, perf check on the static build, end-to-end Lighthouse, redirect map, announcement post draft, G5 sign-off | 1 |

"Effort" totals **~17** — a content-volume proxy, not a wall-clock estimate.

## Status & ownership

- **Status board:** `.phases/README.md` (kept current as work proceeds).
- **Per-phase status:** the `## Status` line at the bottom of each phase file.
- **Phase ownership:** add an `## Owner` line to a phase file when claimed.
- **Daily log (optional):** if useful, append decision notes to `.phases/decision-log.md` (not created until first decision needs recording).

## Out of scope

- **SDK content.** SDK pages (`src/content/docs/sdk/*`) are touched only in phase 08 to reconcile the status table with `roadmap.md`. Deep SDK rewrites are a separate plan.
- **Marketing pages.** `index.mdx`, `vs/*`, and `concepts/why-fraiseql.md` get a version + truthfulness sweep, not a rewrite.
- **i18n.** The docs site is English-only. Any localization is a separate future plan.
- **Search tuning.** Algolia / Pagefind setup tweaks beyond what falls naturally out of phase 10 polish.

## Risks & known unknowns

| Risk | Mitigation |
|------|------------|
| Framework keeps shipping during the plan window (v2.4 lands mid-plan) | Phase 00 ends with a "code freeze" snapshot — we document the SHA. Anything that lands after that is queued for a follow-on patch plan, not folded in. Bump policy is human gate G2. |
| Container harness is brittle on some hardware (MSSQL is famously fussy) | Phase 00 includes a "skip MSSQL if unavailable" mode; the CI matrix runs the full stack. |
| Bugs surfaced are too numerous to fix in phase 09 window | Phase 09 has explicit triage criteria; non-blockers ship as documented limitations with linked issues. Ship-readiness threshold is human gate G3. |
| Writer-Claude and Reviewer-Claude hallucinate in the same way | The persona prompts in `personas.md` are engineered for opposing objectives (Writer: completeness; Reviewer: falsity). Source-citation discipline plus CI-as-only-GREEN-gate are the structural safeguards. |
| Style drift across persona invocations | Style Auditor persona (Sonnet 4.6) reads every page produced in a phase in one context window and produces an edit list for Cleanup. |
| Sonnet personas under-perform on the work assigned | Escalation rule: if a Sonnet output fails its quality bar, the next invocation on the same artifact runs Opus, logged in handoff. Two escalations in one phase triggers a model-allocation review. |
| The Astro/Starlight build slows down as new pages are added | Phase 10 includes a build-time budget; if exceeded, refactor Starlight config or break into multi-package monorepo. |
| Compute cost runs higher than expected | Per-phase persona budgets logged in handoff. If phase 04 burns disproportionate spend, phase 05/06 compresses to compensate. |

## How to use this plan

1. Read `methodology.md` once.
2. Open `.phases/README.md` to see what's claimable.
3. Read the phase file end-to-end before claiming it.
4. Update the `## Status` line on the phase file as you progress through cycles.
5. After CLEANUP on each cycle, commit with the message format from `methodology.md`.
6. When a phase completes, append a one-line entry to `.phases/README.md` under "Completed phases" and move on.

---

*This plan is itself archaeology. Per the Eternal Sunshine principle, this entire directory is deleted in the Finalize phase. Nothing in `~/code/fraiseql-docs` should reference `.phases/` once the work ships.*
