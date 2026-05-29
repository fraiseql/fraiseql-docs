# Adversarial review checklist — `<page-slug>`

**Page:** `src/content/docs/<path>.md(x)`
**Branch / PR:** `<link>`
**Writer persona session:** `<link to writer transcript or invocation ID>`
**Reviewer persona session:** `<this session — must be fresh context, no scroll-back from Writer>`
**Review date:** `<YYYY-MM-DD>`
**FraiseQL SHA reviewed against:** `<sha>` (must match phase SHA in `_internal/.plan/handoff.md`)

---

## Reviewer note

You are the Reviewer persona invoked with the prompt in `personas.md`. Your context is fresh. You have not seen the Writer's reasoning. Assume every claim is suspect. Your success metric is *the number of falsifiable items you catch*, not the number of pages you pass.

---

## Setup

```bash
# Reviewer commands — run fresh, do NOT trust writer's CI
git checkout <branch>
cd ~/code/fraiseql-docs
bun install
bun run dev          # smoke test render
# In another shell:
cd scripts/docs-test
docker compose -f docker-compose.docs-test.yml down -v
./pages/<page-slug>.docs-test.sh
```

The script must return 0. If it does not: **STOP — back to Writer**.

The page's CI docs-test run must also be green at HEAD. Confirm via the PR's checks tab — do not take the Writer's word for it.

---

## 15-point checklist

| # | Item | ✅/❌ | Notes |
|---|------|-------|-------|
| 1 | **Version drift** — claims match `~/code/fraiseql@<sha>` |       |       |
| 2 | **Wrong-DB paths** — all four DBs handled, or unsupported DBs flagged |       |       |
| 3 | **Feature-flag omissions** — Cargo features named where required |       |       |
| 4 | **Security-default regressions** — no insecure defaults shown without warning |       |       |
| 5 | **SDK divergence** — every SDK shown is "Functional" in roadmap |       |       |
| 6 | **Dead links** — `astro check` clean; manual click-through of every link |       |       |
| 7 | **Undefined symbols** — every symbol greps in `~/code/fraiseql` source |       |       |
| 8 | **Copy-paste from prior version** — `git log -p` shows no stale carryover |       |       |
| 9 | **Conditional caveats** — "works only when X" caveats stated |       |       |
| 10 | **RLS / security interactions** — implications of `set_config`, JWT claims, tenant context explicit |       |       |
| 11 | **Error-path coverage** — at least one failure mode shown with exact message |       |       |
| 12 | **Archaeology-free** — no `Phase N` / `TODO` / `FIXME` / `(coming soon)` |       |       |
| 13 | **Source citations resolve** — re-grep ≥3 random `<!-- source: ... -->` annotations at frozen SHA; each found |       |       |
| 14 | **No persona self-reference** — no "as an AI" / "as a documentation agent" / leaked prompt artifacts |       |       |
| 15 | **Dark mode** — code blocks, callouts, tables, inline links all readable in dark theme |       |       |

## Counter-claims to test

What I tried in order to break the page:

1. <e.g. "Ran the same example against MySQL — section 'inject_params with native columns' produced wrong SQL because the doc assumed JSONB extraction"> — outcome: <fixed / filed bug #NNN / blocked>
2. ...

## Bugs filed during this review

| Issue # | Title | Severity | Status |
|---------|-------|----------|--------|
|         |       |          |        |

## Verdict

- [ ] ✅ Merge — 15/15 green
- [ ] ❌ Back to Writer — items `<list>` failed

## Handoff

This review's outcome is logged in `_internal/.plan/handoff.md` with a one-line summary. The next persona reads it on invocation.

## Sign-off

Reviewer persona — `<date>`
