# Handoff log

Durable cross-persona communication channel. Every persona's first action is to read this file. Every persona's last action is to append to it.

Entry format: a level-3 heading per cycle close, in chronological order. **Newest at the bottom.**

```
### Phase NN / Cycle M close — <persona> — <UTC timestamp>
- What was decided / produced.
- State of docs-test suite at cycle close (pass / fail / skipped counts).
- Open framework issues filed this cycle (with URLs / IDs).
- Anything the next persona must know that is not already in the phase file.
- Human gates surfaced (G1–G5): one bullet per gate, ending with `[?]`.
```

Human responses to gates are appended *inline under the gate bullet* by the human, prefixed `> human:`. The next persona resumes from there.

---

### Phase 00 / Cycle 0 close — orchestrator — 2026-05-28

- Plan tree moved from `/tmp/fraiseql-docs-overhaul/` → `_internal/.plan/`.
- Runtime subdirs created: `style-audits/`, `audits/`, `red-evidence/`.
- `framework-qa-triage.md` scaffolded (empty triage list).
- This `handoff.md` scaffolded.
- `astro.config.mjs`: `_internal/` is at repo root, outside `src/`, so Astro/Starlight does not index it by construction. A clarifying comment was added at the top of the config. Build output verified clean (cycle CLEANUP step).
- Frozen FraiseQL SHA candidate captured for Cycle 9: `d0a4ed4ec1770c70707f68fd9019f2b561d87461` (merge of PR #322, `fix/server-publish-studio-exclude`). Do not promote until Cycle 9.
- Docs-test suite: not yet wired (phase 00 cycle 6).
- Framework issues filed: 0.
- Human gates surfaced:
  - **G6 (novel — not in original register) — divergent history vs. canonical docs remote.** Background:
    - Located canonical docs repo: `fraiseql/fraiseql-docs` (`git@github.com:fraiseql/fraiseql-docs.git`), description "FraiseQL documentation and marketing site (Astro + Starlight)". Single branch `main`, last pushed 2026-03-25.
    - Added it as `origin` (fetch only — no push performed) to inspect history. Findings:
      - Local `main` (51 commits, all "Claude") and `origin/main` (64 commits, all "Claude Code") share **no common ancestor**. `git merge-base main origin/main` returns empty.
      - Local root commit: `9cdc9e1 docs: Complete FraiseQL database and analytics documentation` (2026-02-08).
      - Remote root commit: `482e8db chore(init): Initialize fraiseql_marketing project with phase structure` (2026-02-16).
      - `git diff --stat main origin/main`: 397 files, +77 379 / −54 314 lines.
    - **Implication:** these are two parallel docs efforts. Methodology § 6.1 (CI is the only GREEN gate) and Phase 00 cycles 6/8 (CI workflow, PR template) cannot land cleanly without first resolving which `main` is canonical.
    - **Push authority confirmed by human:** feature branches only (not `main`). But pushing a feature branch off a disjoint local `main` would create an orphan branch on the remote; PR merge semantics are degraded against unrelated histories.
    - Proposal — needs human choice (see ask-the-user response): one of (a) treat local v2.dev as canonical and replace `fraiseql-docs/main` (destructive — needs explicit override of "never force-push to main"); (b) create a new repo `fraiseql-docs-v2` (or similar) and push there cleanly; (c) rebase / cherry-pick the local 51 commits onto `origin/main` so we converge before phase 00 closes; (d) accept the orphan-branch posture and proceed with PRs against unrelated history.
    - Cycles 1–5 are local-only infrastructure (Compose, Dockerfile, storage sidecars, operator CLI, smoke). They can proceed during G6 deliberation. Cycles 6, 8 are blocked until G6 resolves.
    - **Live-site evidence (added after WebFetch on https://fraiseql.dev/):**
      - Live hero title: `Any DB. Any Language. Any Transport. One Binary.`
      - Live tagline: `Define your schema. Compile. Serve. No resolvers. No ORM. One query per request.`
      - Remote `fraiseql-docs/src/content/docs/index.mdx`: hero `Compiled API Server.`; tagline pivots on "Author once. Serve everywhere. Python/TypeScript/Go/+10 SDKs. GraphQL + REST + gRPC, one binary." → **matches the live site**.
      - Local `src/content/docs/index.mdx`: hero `Own Your SQL. Serve as GraphQL.`; tagline pivots on "Database-first GraphQL, JSONB views" → **does not match the live site**.
    - **Conclusion:** `fraiseql/fraiseql-docs` is canonical for the deployed site. The other local tree at `~/code/fraiseql_v2.dev` is older, parallel "database-first" framing that was not shipped. Resolution: option C — pivot the overhaul to operate on a clean `fraiseql-docs` checkout at `~/code/fraiseql-docs/`; replay phase-00 cycle 0 there; the `~/code/fraiseql_v2.dev` tree remains as historical context but is no longer the basis for ongoing work.
    - **Resolution (human, 2026-05-28):** chose option C — pivot to `~/code/fraiseql-docs`, feature branches only. Gate G6 closed. See next entry. ✅

---

### Phase 00 / Cycle 0 close (post-pivot) — orchestrator — 2026-05-28

- **Working tree pivot:** all subsequent work happens in `~/code/fraiseql-docs/` (cloned from `git@github.com:fraiseql/fraiseql-docs.git`, branch `main` at `4e3dbdb`). The `~/code/fraiseql_v2.dev` tree retains the pre-pivot Cycle 0 artefacts as historical context but receives no further commits.
- `_internal/.plan/` tree copied into the new working tree at `~/code/fraiseql-docs/_internal/.plan/`. Path references in plan files rewritten `fraiseql_v2.dev` → `fraiseql-docs`.
- Branch posture: I will create `phase-00/foundation` from `origin/main` for all phase-00 work and commit per cycle on that branch. Single PR at phase close, per human's "feature branches only" authorisation. CI does not yet exist (it is wired in Cycle 6).
- `astro.config.mjs` (new tree) has the `_internal/` documentation comment added.
- Next persona: Writer (Opus 4.7) for Cycle 1 — Compose stack. Then Cleanup (Sonnet 4.6).
- Docs-test suite: not yet wired (Cycle 6).
- Framework issues filed: 0.
- Open gates: none. (G6 resolved.)

---
