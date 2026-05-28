# `FRAISEQL_SHA` — frozen framework SHA

The sibling file `FRAISEQL_SHA` in this directory pins the FraiseQL framework
commit that every docs-test reproduction validates against. It is the
single source of truth consulted by:

- `scripts/docs-test/Dockerfile.fraiseql` — passed as a build `ARG`; the
  build verifies the build-context HEAD matches and aborts on hard
  mismatches in CI.
- `.github/workflows/docs-test.yml` — `discover` job's `resolve-sha`
  step reads the file (preferred) or falls back to an in-workflow
  constant if the file is absent. Trailing whitespace is stripped via
  `tr -d '[:space:]'`.
- `scripts/docs-test/docs-test.sh sha` — operator CLI subcommand. Three
  paths:
  - file present + matches `~/code/fraiseql` HEAD → prints "OK
    (matched)" and exits 0.
  - file present + diverges from `~/code/fraiseql` HEAD → prints a
    loud SHA-DRIFT warning to stderr and exits 1. The operator must
    either check out the frozen SHA in `~/code/fraiseql` or open a G2
    bump proposal.
  - file absent → prints `~/code/fraiseql` HEAD and a note that the
    frozen SHA was not set yet (pre-Cycle-9 history); exits 0.

## File format

- Exactly 40 hex characters (`[0-9a-f]{40}`).
- No leading or trailing whitespace.
- No trailing newline (the file is exactly 40 bytes on disk).
- No comment lines, no metadata. The file is read as raw content by
  the CI workflow and the operator CLI; any decoration breaks the
  resolver.

If you need to read it manually:

```bash
sha=$(tr -d '[:space:]' < scripts/docs-test/FRAISEQL_SHA)
echo "frozen SHA = $sha"
```

## Bumping the frozen SHA is human gate G2

The Writer persona does **not** bump this file. Ever.

Bumping the frozen SHA is a deliberate, audited decision that affects
every documentation page in the overhaul: each page's source citations
reference line numbers that are stable only at the frozen SHA, and
every page's docs-test reproduction is validated against the framework
behaviour at the frozen SHA.

The default policy at the close of Phase 00 is:

> **Hold to the frozen SHA. Bumping is a Phase 09 or Phase 10
> decision.**

This means even if FraiseQL v2.4 (or any later release) lands during
the documentation overhaul, the docs continue to target the SHA
captured at the start of Phase 00.

### When the bump becomes necessary

A bump is warranted when *any* of the following is true:

- A framework bug that blocks a page lands a fix that the docs need to
  document (rare — most page bugs can be worked around or noted).
- A new framework feature lands that an explicitly-planned phase must
  document (e.g. Phase 03 adds an Arrow-specific page that depends on
  framework behaviour not present at the original frozen SHA).
- A security advisory or CVE-class regression in the frozen SHA makes
  it irresponsible to keep documenting against it.

### How a Writer surfaces a bump proposal (G2)

When the Writer encounters a situation that calls for a bump:

1. **Do not bump the file.** The Writer never edits `FRAISEQL_SHA`.
2. In the current cycle's handoff entry in
   `_internal/.plan/handoff.md`, append a `**G2 (SHA bump proposed)**`
   bullet ending with `[?]`. The bullet includes:
   - The new candidate SHA (40-char hex).
   - The rationale: which framework PR / release motivates the bump,
     and which docs page or phase requires it.
   - The blast radius: which already-shipped pages may need
     re-validation against the new SHA, and which docs-test
     reproductions may need updating.
3. **Stop work on the cycle.** The Writer waits for the human's
   inline `> human:` response under the gate bullet.
4. **Resume only on a `> human: bump approved`-style response.** The
   human (not the Writer) edits this file. The Writer then resumes,
   typically with a Cycle 0-style re-validation of the existing
   reproductions against the new SHA before any new content lands.

A bump approved during Phase 09 (final framework reconciliation) is
the expected path. A bump approved earlier than that is exceptional
and should carry a written justification in the handoff.

## Initial freeze rationale

The value in the sibling `FRAISEQL_SHA` file (`d0a4ed4ec1770c70707f68fd9019f2b561d87461`)
is the FraiseQL `main` HEAD at the start of Phase 00, captured by the
Cycle 0 author on 2026-05-28. It is the merge commit of PR #322
(`fix/server-publish-studio-exclude`) into `main`. The full
provenance is recorded in `_internal/.plan/handoff.md` under the
"Phase 00 / Cycle 0 close — orchestrator" entry and in
`_internal/.plan/.phases/README.md`.

This was the first SHA against which the Cycle 2 `Dockerfile.fraiseql`
build succeeded with the full eight-feature `CARGO_FEATURES` set, and
the first SHA at which all four Cycle 5 smoke-target DBs were
exercised end-to-end (with the FW-2 caveat — see
`_internal/.plan/framework-qa-triage.md`).

## Related

- `_internal/.plan/.phases/README.md` — phase tree overview; lists the
  frozen SHA in its top section.
- `_internal/.plan/framework-qa-triage.md` — open FraiseQL framework
  issues filed during the overhaul (currently FW-1 #326, FW-2 #327).
- `_internal/.plan/handoff.md` — durable cross-persona log; G2 bump
  proposals land here.
- `_internal/.plan/methodology.md` § 6.1 — "CI is the only GREEN gate"
  rule. SHA drift invalidates CI's authority over a page's GREEN
  status, which is why drift exits 1 in the operator CLI.
