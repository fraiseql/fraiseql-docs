<!--
HOW TO USE THIS TEMPLATE
========================

This template is the persona-handoff contract for the FraiseQL docs
overhaul, in PR form. It mirrors the 15-point adversarial-review
checklist from _internal/.plan/methodology.md § 5 and the four
mandatory cross-persona fields named below.

Reference: _internal/.plan/personas.md § Writer.

To open a PR pre-populated with this template, either:

  - Use the GitHub web UI's "Pick a template" picker (visible when
    the repo has more than one PR template under
    .github/PULL_REQUEST_TEMPLATE/), or
  - Append `?template=docs-page.md` to the PR-create URL, e.g.
    https://github.com/fraiseql/fraiseql-docs/compare/main...your-branch?template=docs-page.md
  - From the CLI: `gh pr create --template docs-page.md ...`

Once the PR is open, the Writer fills the Writer-owned fields below
(everything except `Reviewer persona session:` and
`Source-Citation Verifier outcome:`). Empty Writer-owned fields are
treated as merge-blocking by the Reviewer persona.

Strip these HTML comments AFTER you have filled the body — leaving
them in is fine (GitHub does not render them); removing them is fine
too. The 15-point checklist itself MUST remain in the rendered PR
body so the Reviewer has a visible artifact to check off.
-->

## Summary

<!-- One or two sentences. What page changed and why. -->

## Mandatory cross-persona fields

These four fields are the handoff contract. Empty or stale values block merge.

- **CI docs-test run URL:** <!-- Writer fills. Paste the URL of the GREEN docs-test workflow run on this PR's head commit. Empty blocks merge. -->
- **Reviewer persona session:** <!-- Reviewer fills after their pass. Reference (transcript URL or session ID) to the Reviewer's review against this PR. -->
- **Source-Citation Verifier outcome:** <!-- Verifier fills. One of: PASS / PASS-WITH-FIXES / FAIL. If PASS-WITH-FIXES or FAIL, link the issues filed. -->
- **Frozen FraiseQL SHA:** <!-- Writer fills. Must match `scripts/docs-test/FRAISEQL_SHA` exactly (40-char hex). Mismatch blocks merge. -->

## 15-point adversarial-review checklist

<!--
Verbatim from _internal/.plan/methodology.md § 5. A page that fails
any item goes back to the Writer. The Reviewer does not fix the page;
the Writer learns the gap.
-->

- [ ] 1.  VERSION DRIFT — does the page mention version numbers, feature-flag names, or CLI flags that exist *today* in `~/code/fraiseql@<frozen-SHA>`? Cross-check at least three claims against the source.
- [ ] 2.  WRONG-DB PATHS — for any multi-DB feature, does the example work as written on PostgreSQL, MySQL, SQLite, AND SQL Server, or does it silently assume PostgreSQL? Mark explicitly which DBs are supported.
- [ ] 3.  FEATURE-FLAG OMISSIONS — does the documented behaviour require a Cargo feature flag (`arrow`, `rest`, `observers-nats`, `observers-enterprise`, `redis-pkce`, `redis-apq`, `redis-rate-limiting`) that the page fails to mention?
- [ ] 4.  SECURITY-DEFAULT REGRESSIONS — does the example set defaults that are insecure (e.g. `require_auth = false` shown without warning, `cors.origins = "*"`)?
- [ ] 5.  SDK DIVERGENCE — if the page shows SDK code, is that SDK marked "Functional" in `roadmap.md`'s SDK status table?
- [ ] 6.  DEAD LINKS — every internal and external link resolves. Run `astro check` and visit each in dev mode.
- [ ] 7.  UNDEFINED SYMBOLS — every type name, function name, config key, env var, GraphQL directive, and SQL function referenced in text appears verbatim somewhere in `~/code/fraiseql` source at the frozen SHA.
- [ ] 8.  COPY-PASTE FROM PRIOR VERSION — does the page contain blocks verbatim from an old version that no longer apply? Check `git log -p src/content/docs/<page>` for stale carryover.
- [ ] 9.  CONDITIONAL CAVEATS — "this works only when X" caveats explicitly stated? Multi-tenant + federation + RLS interactions are particularly prone.
- [ ] 10. RLS / SECURITY INTERACTIONS — does the page interact with `set_config()`, JWT claims, or any auth context? If yes, is the RLS-policy implication called out?
- [ ] 11. ERROR-PATH COVERAGE — when X fails, what does the user see? Page must show at least one failure mode with its exact error message (copy-pasted from a container reproduction).
- [ ] 12. ARCHAEOLOGY-FREE — no `Phase N`, `TODO`, `FIXME`, `XXX`, `// old code`, `(coming soon)`, or `(WIP)` in the rendered output.
- [ ] 13. SOURCE CITATIONS RESOLVE — every `<!-- source: ... -->` annotation in the draft points to a file:line in `~/code/fraiseql@<frozen-SHA>` and contains the cited symbol. Re-grep at least three random citations.
- [ ] 14. NO PERSONA SELF-REFERENCE — no "as an AI," "as a documentation agent," or leaked persona-prompt artifacts in the rendered output.
- [ ] 15. DARK MODE — page renders in dark mode without contrast regression. Code blocks, callouts, tables, and inline links all readable.

## Per-persona expectations (handoff contract)

<!--
Each downstream persona's expectations surface here as a checklist
item the upstream persona (typically the Writer) must satisfy. If
any item is unchecked, the downstream persona blocks until it is.
-->

### What the Reviewer expects from the Writer

- [ ] The CI `docs-test` workflow has run against the PR's head commit and is GREEN. (The run URL is pasted above.)
- [ ] The 15-point checklist above has every item checked, or items left unchecked carry a one-line justification next to them.
- [ ] Every factual claim in the page carries a `<!-- source: path:Lstart-Lend -->` HTML-comment citation pointing at the framework source at the frozen SHA.
- [ ] The page contains no Writer-persona artifacts (planning chatter, TDD-cycle markers, "as an AI", `Phase N`, `TODO`, `FIXME`, `(WIP)`).
- [ ] The Writer has not declared GREEN on the page themselves — CI is the only GREEN gate (`_internal/.plan/methodology.md § 6.1`).

### What the Source-Citation Verifier expects from the Writer

- [ ] Every `<!-- source: ... -->` citation resolves to an existing file:line range at the frozen SHA.
- [ ] The cited symbol (function name, struct, config key, etc.) is present verbatim in the cited range.
- [ ] Citations are removed by the Verifier (not by the Writer) after they validate.

### What the next-phase Writer expects from this Writer

- [ ] Page-specific docs-test scripts live under `scripts/docs-test/pages/`, follow the Cycle-5 smoke output format, and use the Cycle-4 operator CLI (`docs-test.sh`) rather than raw `docker compose` plumbing.
- [ ] Any framework bugs surfaced are filed against `fraiseql/fraiseql` via `gh issue create` and registered in `_internal/.plan/framework-qa-triage.md`.
- [ ] Page-level deviations from the framework's documented behaviour are noted in the handoff entry so Phase 02+ IA owners can decide whether to fix the page or the framework.

## Page-specific notes

<!--
Anything the Reviewer needs to know that is not covered by the
checklist above. Examples:
  - "This page depends on the `arrow` Cargo feature; the docs-test
    image's CARGO_FEATURES was bumped to include it."
  - "FW-3 (https://github.com/fraiseql/fraiseql/issues/NNN) blocks
    the multi-tenant example; page documents the workaround."
-->

## Handoff entry

<!--
Confirm the post-cycle handoff entry has been appended to
_internal/.plan/handoff.md. The entry's format is documented at the
top of that file.
-->

- [ ] Cycle-close entry appended to `_internal/.plan/handoff.md` (newest at bottom).
