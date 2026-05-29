# Methodology

How we do the work. Read once; refer to during execution.

This plan is executed by Claude Code, sequentially, across multiple persona invocations. The calendar-week estimates retained in each phase file are wall-clock *upper* bounds for content volume; actual execution is paced by container-test runtime, CI wait time, and human-gate latency — not by writer fatigue.

---

## 1. The TDD analogue for documentation

The classic RED → GREEN → REFACTOR → CLEANUP loop applies, with documentation-specific definitions.

### RED — Write the failing reproduction

Before writing a single line of prose, produce the artifact that proves the page is *needed* and proves the current state is *wrong*:

- **For a missing page**: write the reader's intent in one sentence ("I want to enable WASM functions and see one fire") and confirm that the docs site has no current path to satisfy it. Capture the would-be URL as a 404 screenshot.
- **For a stale page**: open a Docker container, follow the existing docs verbatim, and capture the failure point — wrong CLI flag, missing config key, type error, runtime panic. Save the transcript as `_internal/.plan/red-evidence/<page>.transcript`.
- **For a missing reference entry**: grep the actual Rust source for the symbol (`crates/fraiseql-cli/src/commands/<x>.rs`, etc.) and capture its real surface. Diff against what the reference page lists today.

Every factual claim the Writer intends to place on the page is captured during RED as a **source citation** — an annotation of the form `<!-- source: crates/foo/src/bar.rs:L42-L68 -->` placed next to the prose that references it. Citations are the Writer's contract with the Reviewer and the Source-Citation Verifier personas that the claim is not hallucinated. See § 4.

A phase that has not produced RED evidence cannot proceed to GREEN.

### GREEN — Make it pass

Write the minimum docs content that:

1. Renders cleanly on the local Starlight dev server.
2. Passes the page's `*.docs-test.sh` companion **as observed in CI**, not as observed by the Writer locally (see § 6.1).
3. Resolves all internal links.
4. Survives the 15-point adversarial checklist (§ 5) at the structural level.
5. Has a source citation against every non-trivial factual claim.

"Minimum" means: every claim is in there, every claim is verified, and the page is navigable. It does **not** mean: prose is great, examples are charming, or screenshots are pixel-perfect. Those are REFACTOR concerns.

### REFACTOR — Improve the prose

With behaviour locked in by GREEN:

- Tighten copy. Cut adjectives. Replace "easily" / "simply" / "just" with concrete claims.
- Audit voice consistency. FraiseQL docs are written declarative, second-person where applicable, no exclamation marks, no marketing register.
- Promote shared patterns to includes / partials if Starlight supports it for the construct.
- Re-order sections to match the reader's likely path (most-common task first, edge cases later).
- Verify GREEN still passes after every prose change.

### CLEANUP — Lint, format, wire, strip citations

Every page ends its cycle with:

```bash
bun run lint
bun run typecheck
bun run check       # if defined; falls back to astro check
bun run build       # full static build must succeed
```

Plus:

- Sidebar entry updated in `astro.config.mjs` if the page is new.
- Frontmatter (`title`, `description`) reviewed for SEO snippet quality.
- Cross-links from related pages added — at least one inbound link per new page.
- `git grep -i "TODO\|FIXME\|XXX\|Phase " src/content/docs/` returns nothing on the touched files.
- Source citations stripped from rendered output by the Source-Citation Verifier persona — and only after every citation has been validated.
- Page is added to its phase's `## Pages completed` list.

A cycle is not done until CLEANUP is done. A page that ships with broken lint propagates the broken state to every future writer who copy-pastes from it.

---

## 2. Execution model: personas, handoffs, gates

Each phase advances through a sequence of distinct persona invocations. A persona is a Claude Code session with its own system prompt, tool allowance, and forbidden actions. Personas do not share context windows; the only durable handoff is the artifacts they leave in the repository.

### Personas (summary)

| Persona | Role | Model |
|---------|------|-------|
| **Writer** | Produces RED evidence, drafts the page, opens the PR | Opus 4.7 |
| **Reviewer** | Adversarial review against the 15-point checklist | Opus 4.7 |
| **Bug-Finder** | RED-phase framework breakage; files framework issues | Opus 4.7 |
| **Style Auditor** | Reads every page produced in a phase; flags voice and terminology drift | Sonnet 4.6 |
| **Cleanup** | Mechanical fixes: linters, sidebar wiring, cross-link patching | Sonnet 4.6 |
| **Source-Citation Verifier** | Confirms every `<!-- source: ... -->` resolves; strips citations | Sonnet 4.6 |
| **Link Auditor** | External link audits | Haiku 4.5 |
| **Framework Bug-Fixer** | Phase 09 only — writes Rust fixes against `~/code/fraiseql` | Opus 4.7 |
| **Final Reviewer** | Phase 10 end-to-end sign-off | Opus 4.7 |

Detailed prompts, tools, and forbidden actions per persona are in `personas.md`. Personas must be invoked using their documented prompt — improvising defeats the adversarial property.

### Why personas, not "writer + reviewer roles"

Writer-Claude and Reviewer-Claude are the same model with the same priors. Fresh context windows give separation of *scrollback*, not separation of *judgement*. The adversarial property only materialises if the persona prompts engineer different objectives: the Writer prompt optimises for completeness; the Reviewer prompt optimises for finding falsity. Without that engineering, the 15-point checklist becomes a rubber stamp.

### Handoff protocol

Every phase concludes by appending to `_internal/.plan/handoff.md`:

1. What was decided this phase (IA choices, bug-triage classifications, deferred items).
2. Current state of the docs-test suite: passing / failing / skipped counts.
3. Open framework issues filed during the phase, with status.
4. Anything the next persona must know that is not already in the phase file.

The first instruction in every persona prompt is: read `_internal/.plan/handoff.md` and the relevant phase file before doing anything else.

### Human gates

Some decisions pause Claude execution. The persona writes its proposed answer to `_internal/.plan/handoff.md`, marks the phase status `[?]` (awaiting human), and stops. The human reads the proposal, replies in the handoff file, and the next persona resumes.

Current register of human gates:

- **G1** — Sidebar IA decision (phase 01 cycle 6): choose Option A / B / C.
- **G2** — SHA bump if v2.4 lands mid-plan (phase 00 risk register): accept or hold.
- **G3** — Phase 09 ship-readiness threshold: which severity blocks phase 10.
- **G4** — Each framework PR merge in phase 09 is one gate, by default. Auto-merge requires explicit human override in the plan README.
- **G5** — Phase 10 final sign-off before tagging.

Personas are required to surface novel gates rather than guess.

---

## 3. Model allocation

Opus 4.7 is used where the work requires high-quality reasoning, adversarial judgement, or non-trivial code changes:

- **Writer** — generates content, reads framework source, makes design judgement on page structure.
- **Reviewer** — must find falsity the Writer missed; requires adversarial reasoning, not pattern matching.
- **Bug-Finder** — creative breakage attempts against the framework.
- **Framework Bug-Fixer** — writes Rust in a strict-clippy environment.
- **Final Reviewer** — end-to-end gestalt judgement.

Sonnet 4.6 is used where the work is mostly mechanical pattern application:

- **Style Auditor** — reads pages, applies style-guide rules, lists specific edits. Faster and cheaper than Opus at the same accuracy.
- **Cleanup** — runs linters, patches sidebar entries, applies suggested edits.
- **Source-Citation Verifier** — greps source, confirms ranges, strips annotations. Mechanical.

Haiku 4.5 is used for the cheapest mechanical work:

- **Link Auditor** — HTTPS GET every external link, classify status codes, report.

The Bash + Read tools backing these personas are model-agnostic; the model choice concerns the cognitive judgement layered on top.

### Escalation

If a Sonnet persona produces output that fails its quality bar (e.g., Style Auditor misses a clear style violation that the Reviewer later catches), the next invocation on the same artifact escalates to Opus. Escalations are logged in `_internal/.plan/handoff.md`. A persona that escalates twice within the same phase prompts a model-allocation review at phase close.

---

## 4. Source citations

While drafting, every non-trivial factual claim is annotated:

```
<!-- source: crates/fraiseql-tenancy/src/dispatch.rs:L142-L168 -->
```

**MDX 3 / Astro 5 / Starlight 0.37 incompatibility (amended Phase 01 close, 2026-05-29):** in `.mdx` files, the HTML-comment form is rejected when it appears in expression position. Use the JSX-comment form instead, which is equivalently invisible in rendered HTML and equivalently greppable on the `source:` token:

```
{/* source: crates/fraiseql-tenancy/src/dispatch.rs:L142-L168 */}
```

The Source-Citation Verifier persona accepts either form — its scan keys on the literal `source:` token, not on the comment delimiters. Plain `.md` files keep the HTML form. The amendment was driven by the Phase 01 Cycle 1 Writer's MDX-3 finding (confirmed by `bun run build` failure on the HTML form inside `.mdx` and clean pass on the JSX form) and re-flagged by the Cycle 1, Cycle 5, and Cycle 6 Reviewers as a methodology gap to close at phase end.

The Source-Citation Verifier persona runs before the page leaves CLEANUP. It:

1. Greps the cited file:line range at the frozen FraiseQL SHA.
2. Confirms the symbol or behaviour referenced in the surrounding prose actually appears there.
3. Strips the annotation from the rendered output once verified.

A claim without a source citation does not ship. A citation that does not resolve sends the page back to the Writer.

Citations are not required for:

- Prose about Astro/Starlight (the docs-site framework itself).
- Purely structural prose ("This page covers X.").
- Quoted CHANGELOG entries (which cite the CHANGELOG implicitly).
- Style-guide-mandated boilerplate (e.g., `## Next steps` cross-link blocks).

---

## 5. Adversarial review checklist

Fifteen items. Every page. No exceptions.

```
[ ] 1.  VERSION DRIFT — does the page mention version numbers, feature-flag names, or CLI flags that exist *today* in `~/code/fraiseql@<frozen-SHA>`? Cross-check at least three claims against the source.
[ ] 2.  WRONG-DB PATHS — for any multi-DB feature, does the example work as written on PostgreSQL, MySQL, SQLite, AND SQL Server, or does it silently assume PostgreSQL? Mark explicitly which DBs are supported.
[ ] 3.  FEATURE-FLAG OMISSIONS — does the documented behaviour require a Cargo feature flag (`arrow`, `rest`, `observers-nats`, `observers-enterprise`, `redis-pkce`, `redis-apq`, `redis-rate-limiting`) that the page fails to mention?
[ ] 4.  SECURITY-DEFAULT REGRESSIONS — does the example set defaults that are insecure (e.g. `require_auth = false` shown without warning, `cors.origins = "*"`)?
[ ] 5.  SDK DIVERGENCE — if the page shows SDK code, is that SDK marked "Functional" in `roadmap.md`'s SDK status table?
[ ] 6.  DEAD LINKS — every internal and external link resolves. Run `astro check` and visit each in dev mode.
[ ] 7.  UNDEFINED SYMBOLS — every type name, function name, config key, env var, GraphQL directive, and SQL function referenced in text appears verbatim somewhere in `~/code/fraiseql` source at the frozen SHA.
[ ] 8.  COPY-PASTE FROM PRIOR VERSION — does the page contain blocks verbatim from an old version that no longer apply? Check `git log -p src/content/docs/<page>` for stale carryover.
[ ] 9.  CONDITIONAL CAVEATS — "this works only when X" caveats explicitly stated? Multi-tenant + federation + RLS interactions are particularly prone.
[ ] 10. RLS / SECURITY INTERACTIONS — does the page interact with `set_config()`, JWT claims, or any auth context? If yes, is the RLS-policy implication called out?
[ ] 11. ERROR-PATH COVERAGE — when X fails, what does the user see? Page must show at least one failure mode with its exact error message (copy-pasted from a container reproduction).
[ ] 12. ARCHAEOLOGY-FREE — no `Phase N`, `TODO`, `FIXME`, `XXX`, `// old code`, `(coming soon)`, or `(WIP)` in the rendered output.
[ ] 13. SOURCE CITATIONS RESOLVE — every `<!-- source: ... -->` annotation in the draft points to a file:line in `~/code/fraiseql@<frozen-SHA>` and contains the cited symbol. Re-grep at least three random citations.
[ ] 14. NO PERSONA SELF-REFERENCE — no "as an AI," "as a documentation agent," or leaked persona-prompt artifacts in the rendered output.
[ ] 15. DARK MODE — page renders in dark mode without contrast regression. Code blocks, callouts, tables, and inline links all readable.
```

A page that fails any item goes back to the Writer. The Reviewer does **not** fix it themselves — the Writer learns the gap.

---

## 6. Container harness

A reusable Docker-Compose stack lives under `~/code/fraiseql-docs/scripts/docs-test/` (created in phase 00). It is the only authoritative reproduction surface.

### Layout

```
scripts/docs-test/
├── docker-compose.docs-test.yml      # the stack
├── Dockerfile.fraiseql               # builds fraiseql-server from sibling ~/code/fraiseql
├── fixtures/
│   ├── postgres/init.sql             # minimal blog schema + tb_/v_/fn_ trio
│   ├── mysql/init.sql                # same shape, MySQL dialect
│   ├── sqlite/init.sql
│   └── sqlserver/init.sql
├── configs/
│   ├── baseline.toml                 # minimal valid fraiseql.toml
│   └── overlays/                     # per-feature overlay snippets
├── docs-test.sh                      # entry point; spins stack, runs page test, tears down
└── pages/
    └── <page-slug>.docs-test.sh      # one per documented page
```

### Per-page test script

A `*.docs-test.sh` typically does:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../"
./docs-test.sh up --profile postgres,redis
trap './docs-test.sh down' EXIT

# Reproduce the page's setup steps from a fresh state
./docs-test.sh exec fraiseql -- fraiseql-cli compile
./docs-test.sh exec fraiseql -- fraiseql-server &
SERVER_PID=$!

# Issue the documented query
curl --fail-with-body -sS http://localhost:8080/graphql \
  -H 'Content-Type: application/json' \
  -d '{"query":"{ posts { id title } }"}' \
  | jq -e '.data.posts | length > 0' >/dev/null

kill "$SERVER_PID"
```

The script **must** fail loudly if any step does not match the page's claim. A script that returns 0 while quietly skipping the assertion is worse than no script.

### Database matrix

| Feature class | Required DBs |
|---------------|--------------|
| Core (schema, queries, mutations) | All four (PG, MySQL, SQLite, MSSQL) |
| LTree hierarchies | PG only (page must say "PostgreSQL only") |
| Native aggregation columns | PG / MySQL / MSSQL (SQLite must be explicitly listed as fallback) |
| Storage backends | PG primary, plus one MinIO/Azurite/fake-GCS per backend |
| Federation | PG primary; multi-DB federation page must exercise PG+MySQL together |
| Realtime / subscriptions | PG primary |
| Functions (WASM) | PG primary |

### Resource constraints

The full stack at peak takes ~3 GB RAM and 4 CPU. Plan accordingly. Page tests run sequentially in CI by default; parallel local runs require operator discretion.

### Skip rules

A test can skip a DB only if the page itself **explicitly** documents the DB as unsupported for that feature. "I couldn't get MSSQL to work today" is not a skip rule.

### 6.1 CI is the only GREEN gate

A Writer persona declaring "I ran `docs-test.sh` and it passed" is not evidence. Claude is prone to confabulating bash output, mis-reading exit codes, and overlooking `|| true` swallowing in its own scripts.

Therefore:

- The Writer may run docs-test scripts locally during iteration.
- The Writer may **not** declare GREEN until the docs-test workflow has passed in CI on a fresh runner, against the Writer's branch, at HEAD.
- The Reviewer re-runs the docs-test in CI from their own fresh checkout — not from the Writer's CI run — and reads the actual CI output, not the Writer's claim about it.
- The CI run URL is captured in the PR description and in the handoff file.

This rule has no exceptions. A green local run with a red CI run is not GREEN. A "should-be-green" without a CI run is not GREEN.

---

## 7. Bug-finding protocol

Inevitably, doc work surfaces framework bugs. Driven by the Bug-Finder persona during RED of any cycle that exercises framework behaviour.

### Triage on discovery

When the Writer or Bug-Finder hits behaviour that contradicts the spec / CHANGELOG / their best read of the source:

1. **Reproduce in a single isolated script.** Copy the failing snippet into a `<page>.bug-N.sh` under `scripts/docs-test/bugs/`. Make it a one-paragraph reproduction with the expected vs. actual output annotated.
2. **File against `~/code/fraiseql`.** Use `gh issue create --repo fraiseql/fraiseql`. Title format: `[docs-overhaul] <one-line summary>`. Body includes:
   - Reproduction script path.
   - FraiseQL SHA + DB matrix where it reproduces.
   - Expected behaviour (cite CHANGELOG or roadmap entry).
   - Actual behaviour (include exact error message).
   - Severity: blocker / regression / quality-of-life.
3. **Mark the page.** Add a `## Known issues` section to the page (created if absent) linking the issue and describing the workaround if any. Page does not block on the bug being fixed — but does block on the bug being **filed**.

### Phase 09 reconciliation

Phase 09 is dedicated to closing or formally accepting every issue filed during phases 00–08:

- **Closed-by-fix:** issue is fixed upstream by the Framework Bug-Fixer persona; phase 09 removes the workaround from the page.
- **Accepted limitation:** issue stays open; page keeps the `## Known issues` block.
- **Closed as wrong:** the issue was a doc misread, not a real bug; phase 09 confirms the page's prose is correct.

No issue surfaced during the overhaul leaves phase 09 in an indeterminate state.

---

## 8. Commit message format

```
docs(<area>): <description>

[Phase N, Cycle M: RED|GREEN|REFACTOR|CLEANUP, Persona: <name>]

## Changes
- <change 1>
- <change 2>

## Verification
- ✅ CI docs-test workflow: <run URL>
- ✅ Adversarial review checklist 15/15 (Reviewer: <PR review link>)
- ✅ Source citations: all resolved (Verifier: <link or N/A>)
- ✅ Style audit: clean (Auditor: <link or N/A>)
- ✅ Cross-links updated: <N inbound, M outbound>
```

During the Finalize phase, commits drop the persona and phase markers:

```
docs(<area>): <description>

## Changes
- <change 1>

## Verification
- ✅ CI clean
```

---

## 9. Style guide reference

Detail is in `templates/style-guide.md` (created in phase 00). Highlights:

- **Voice:** declarative, second-person where the reader is the actor. "Configure X" not "We will configure X".
- **No exclamation marks** in body text. None.
- **No "easily" / "simply" / "just".** If something is easy, the example will show it.
- **Code blocks are runnable.** Snippets must execute. Pseudo-code is marked explicitly.
- **Tables for matrices.** Prose for narratives. Headings for structure. Don't reach for prose where a table is shorter.
- **One H1 per page** (from frontmatter `title`). Never a second `#` heading in the body.
- **Internal links** use absolute slugs (`/features/foo`) not relative.
- **Code-block language tags** are mandatory. ` ```sql `, ` ```rust `, ` ```toml `, ` ```bash `, ` ```graphql ` — never bare ` ``` `.
- **No emoji in body text** unless the brand explicitly uses them (e.g. 🍯 Confiture).

---

## 10. When in doubt

Default to:

- **Truth over polish.** A clunky but verified page beats a beautiful but wrong one.
- **Cut over expand.** If you're tempted to write a third paragraph, the first two probably already said it.
- **Block over ship.** A page that fails one checklist item does not ship. Tomorrow's reader assumes everything they read is verified.
- **File the bug.** If the framework misbehaves, the framework gets a ticket. The docs do not silently smooth it over.
- **Surface the gate.** If a decision is bigger than a persona should make alone, mark `[?]` in the handoff and stop. Cheap to ask; expensive to guess.

---

*This document does not ship. Like everything in `/tmp/fraiseql-docs-overhaul/` (and the `_internal/.plan/` copy that will exist post-phase-00), it is deleted during Phase 10.*
