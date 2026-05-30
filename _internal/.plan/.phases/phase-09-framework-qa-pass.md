# Phase 09: Framework QA pass

> **RESCOPED 2026-05-30 at Phase 03 close.** The framework team is addressing the 54-issue roadmap (29 FW-bug fixes #326-#361 + 25 enhancements #366-#391) upstream during the docs-overhaul pause. Phase 09 was originally the "Framework Bug-Fixer persona" phase where docs work surfaced bugs that got fixed inside Phase 09 itself. With the bug-fix work happening upstream, Phase 09 shrinks from a fix-the-framework phase to a **reconcile-against-the-fixed-framework** phase. The original text below is preserved for context; the **Reconciliation rescope** section at the bottom is operative when the docs-overhaul resumes.

## Objective

Close out — fix, accept, or formally document — every framework issue surfaced by the documentation overhaul in phases 00–08. This is the phase where the docs effort pays its full dividend: the docs site becomes the QA mirror of the framework, not just a passive description.

## Why this exists

A serious documentation effort against a real codebase invariably finds bugs. Throughout phases 00–08, the methodology requires every surfaced issue to be filed against `~/code/fraiseql`. By phase 08's exit, there's a backlog. Phase 09 is for triaging, fixing, or formally accepting every item in it.

If we skip this phase, the docs ship with `## Known issues` blocks scattered across feature pages, and those issues never get closed. That's the worst of both worlds: the docs are honest about the gap, but the gap never closes.

## Success criteria

- [ ] Every framework issue filed during phases 00–08 is in one of three terminal states:
  1. **Fixed** — PR merged in `~/code/fraiseql`; the corresponding `## Known issues` block removed from the docs page.
  2. **Accepted limitation** — issue stays open; docs page retains the `## Known issues` block with the issue link; CHANGELOG note in the next FraiseQL release.
  3. **Closed as wrong** — turns out it wasn't a real bug; docs page prose corrected if it implied otherwise; issue closed with a clear "not a bug" comment.
- [ ] A `framework-qa-report.md` in the docs repo's `_internal/` summarises:
  - Bugs filed.
  - Bugs fixed (with FraiseQL PR links).
  - Accepted limitations (with reasoning).
  - Closed-as-wrong (with explanation).
- [ ] `## Known issues` blocks on docs pages are reduced to only those backing accepted limitations.
- [ ] Any deferred docs rewrites from phase 08's follow-on backlog are either picked up here (if they were blocked by framework bugs now fixed) or formally re-confirmed as deferred.
- [ ] At least one regression test added to FraiseQL for each fixed bug.

## Scope (in)

- Triage of every filed issue.
- Bug fixes that fit within the phase's effort budget.
- CHANGELOG-Unreleased updates in `~/code/fraiseql` for each fix and each accepted limitation.
- Docs page updates to reflect either-fixed or accepted-and-documented.
- Cross-link sweep: every `## Known issues` block links to an open or closed issue.

## Scope (out)

- Major framework refactors that surface from docs work but exceed the budget — those become their own follow-on plan.
- New features.
- Performance work unless the issue is a documented regression.

## Dependencies

- **Requires:** Phases 03–08 complete; the issue backlog is closed (no new issues being filed after phase 08 exits, except by review-of-phase-09 itself).
- **Blocks:** Phase 10 finalize.

## Personas involved

| Cycle | Personas |
|-------|----------|
| 1 (Triage) | Bug-Finder re-walks each filed issue; categorises as fix-now / accept / wrong |
| 2 (Fix-now) | Framework Bug-Fixer (Opus 4.7) — one fix per PR, regression test, clippy clean, nextest clean |
| 3 (Docs page updates after fix) | Cleanup persona on the docs side |
| 4 (Accept) | Writer persona patches `## Known issues` blocks; Cleanup commits |
| 5 (Wrong) | Writer persona corrects docs prose if it caused the confusion; Cleanup commits |
| 6 (Regression-test backstop) | Framework Bug-Fixer |
| 7 (Final reconciliation) | Cleanup; handoff |

## Human gates

- **G3** — ship-readiness threshold. Before phase 09 begins fixing, the human must declare which severity level (`blocker` / `regression` / `quality-of-life`) blocks phase 10 ship. The Framework Bug-Fixer persona prioritises accordingly.
- **G4** — every framework PR merge. The Framework Bug-Fixer persona opens the PR; the human reviews and merges. Auto-merge requires explicit override in `_internal/.plan/handoff.md` (e.g., for trivial CHANGELOG-only fixes), set per-PR.

## TDD cycles

### Cycle 1: Triage

- **RED:** the issue backlog is a list of ~N items (will know N at phase 09 entry; estimate based on phase 03–06 expected discovery is 20–40).
- **GREEN:** for each issue:
  - Read the reproduction.
  - Assign one of: **fix now**, **accept**, **wrong**.
  - Severity tag (`blocker / regression / quality-of-life`).
  - Estimate fix effort.
- **REFACTOR:** group fixes by file/crate so they batch efficiently.
- **CLEANUP:** triage table committed to `_internal/framework-qa-triage.md`.

### Cycle 2: Fix-now path (priority by severity)

Persona: Framework Bug-Fixer (Opus 4.7). Each PR is gate **G4**.

- **RED:** each "fix now" issue has a reproduction; the fix doesn't exist yet.
- **GREEN:** in `~/code/fraiseql`:
  - Write a failing test reproducing the bug (or convert the docs-test reproduction into a unit / integration test in the appropriate crate).
  - Implement the fix.
  - Test passes.
  - All adjacent tests still pass.
  - `cargo clippy --workspace --all-targets --all-features -- -D warnings` clean.
  - `cargo nextest run --workspace --all-features` clean.
- **REFACTOR:** the fix follows the project's style (matches the v2.3 work — typed errors, no `unwrap`, etc.).
- **CLEANUP:** open PR against `~/code/fraiseql`; CHANGELOG-Unreleased updated; cross-reference the docs page in the PR description. **The Framework Bug-Fixer persona does not merge.** It writes the PR URL to `_internal/.plan/handoff.md`, marks the issue status `[?]` pending G4, and proceeds to the next fix. The human reviews and merges (or rejects) each PR.

### Cycle 3: Docs page updates after fixes

- **RED:** the docs page still has the `## Known issues` block referencing the now-fixed issue.
- **GREEN:** remove the block; commit to docs repo.
- **REFACTOR:** if the prose mentions the bug, refactor to current behaviour.
- **CLEANUP:** the page's `*.docs-test.sh` test now exercises the previously broken path; the test passes against the FraiseQL commit containing the fix.

### Cycle 4: Accept path

- **RED:** an issue can't be fixed in this phase (too large, architectural, out of scope).
- **GREEN:**
  - Issue stays open in `~/code/fraiseql`.
  - The docs page's `## Known issues` block stays.
  - The block links to the open issue + describes a workaround if any.
  - The issue gets a `docs-overhaul-accepted` label.
  - A CHANGELOG-Unreleased "Known limitations" entry is added (so future readers see the limitation in the next release notes).
- **CLEANUP:** every accepted issue is reflected in the `framework-qa-report.md`.

### Cycle 5: Wrong path

- **RED:** an issue turned out to be a misread of the framework, not a real bug.
- **GREEN:**
  - Close the issue with a "not a bug — clarified by [link to docs page section]" comment.
  - If the docs page caused the confusion, fix the page.
  - If the issue was speculative, no docs change needed.
- **CLEANUP:** the issue is closed; the docs page reflects the truth.

### Cycle 6: Regression test backstop

- **RED:** even when fixed, the bug could regress.
- **GREEN:** for each fixed bug, ensure FraiseQL has at least one durable test (unit, integration, property, or fuzz) that would catch the regression. If the existing test suite already covered it, note the test in the bug's PR description.
- **CLEANUP:** the next FraiseQL CI run is clean and includes the new regression tests.

### Cycle 7: Final reconciliation

- **RED:** the docs site and the framework now drift only at the points explicitly accepted as limitations.
- **GREEN:** `framework-qa-report.md` captures every triaged item with status, links, severity. Committed.
- **REFACTOR:** the report becomes the "what did the docs overhaul deliver?" artefact (referenced from phase 10 finalize and from a post-launch announcement).
- **CLEANUP:** every docs page that touched a known-issue block has been re-reviewed.

## Adversarial review protocol

1. Reviewer reads the `framework-qa-report.md` end-to-end.
2. For each "fixed" item, reviewer confirms the FraiseQL PR is merged and the docs page reflects the fix.
3. For each "accepted" item, reviewer reads the docs page's `## Known issues` block; verifies it accurately describes the limitation and links the correct issue.
4. For each "wrong" item, reviewer confirms the docs page now matches the truth.
5. Reviewer attempts to trigger any closed bug from the docs reproduction; expect it to no longer fire (or to fire and exit gracefully, in the case of "wrong" classifications).
6. 12-point checklist applied to any docs page significantly rewritten in this phase.

## Container verification matrix

This phase exercises the harness heavily — every fix has a docs-test reproduction:

| Activity | Matrix |
|----------|--------|
| Each fixed bug's reproduction | per the original bug's matrix |
| Full `_smoke` regression | full matrix |
| `reference-parity.sh` from phase 07 | clean |

## Risks specific to this phase

| Risk | Mitigation |
|------|------------|
| Issue backlog exceeds 1-week capacity | Triage prioritises blockers/regressions; quality-of-life items defer to a follow-on plan |
| A fix introduces a new bug | New bugs land back in the backlog; phase loops cycle 2 until clean (worst case extends phase by a few days) |
| Some fixes require coordinated docs + framework PR | Use sibling PRs; merge framework first, docs second |
| The framework owner is unavailable / not the same person as the docs writer | The plan's owner should align with the framework owner for this phase; bug filing during 00–08 is acceptable without immediate engagement |
| Accepted limitations are unbounded in number | Hard cap: accept up to N (e.g. 15) limitations; beyond that, prioritise more fixes |

## Estimated effort

**Effort proxy: 1.** Highly dependent on actual bug count and G3 severity threshold. Framework Bug-Fixer-Opus dominates per fix (Rust authoring + clippy/nextest); each PR is also a G4 human gate, so wall-clock is bounded by human-review bandwidth, not Claude bandwidth. The phase has a hard Claude-side cap: at 25 fix-now items processed, remaining issues defer to a follow-on plan, regardless of Claude's continued availability — the human review surface is what saturates.

## Status

- [ ] Not started
- [ ] RED in progress
- [ ] GREEN in progress
- [ ] REFACTOR in progress
- [ ] CLEANUP in progress
- [ ] Complete

## Owner

*(unclaimed)*

## Issues triaged

*(append issue references as triage proceeds)*

## Framework PRs merged

*(append PR links as fixes land)*

## Accepted limitations

*(append per the report)*

---

## Reconciliation rescope (2026-05-30 — operative when the docs-overhaul resumes)

The original Phase 09 shape (Framework Bug-Fixer persona writing Rust fixes inside the docs-overhaul plan) is **superseded**. The framework team is fixing the 29 FW-bugs + landing the 25 roadmap enhancements upstream during the docs-overhaul pause. When Phase 09 runs, the framework state is already settled.

### New objective

For each of the 54 framework issues catalogued in `framework-roadmap-mapping.md`:
1. **Verify the fix / feature landed** as the framework team's release notes claim.
2. **Reconcile the docs**: remove `## Known issues` blocks for closed bugs; add prose for newly-shipped features that didn't get covered in their owning phase.
3. **Close the audit trail** — every docs page that referenced an FW-N issue either (a) no longer references it because the bug closed + the row was removed, or (b) explicitly cites it as an accepted limitation with the issue's current status.

### Revised success criteria

- [ ] For each of FW-1..FW-29:
  - If closed by framework PR: corresponding `## Known issues` block removed from the affected docs page(s). Verified by `git grep "<issue-link>" src/content/docs/`.
  - If still open as accepted limitation: the `## Known issues` block restated against the issue's current status; the linked GH issue includes a comment confirming the accept-and-document decision.
  - If closed as wrong: docs page prose corrected, issue closed with rationale.
- [ ] For each of #366..#391 (25 roadmap enhancements):
  - If shipped: covered in the owning phase's docs (per `framework-roadmap-mapping.md` per-phase tables). Phase 09 verifies coverage; doesn't write the coverage itself.
  - If deferred / dropped by the framework team: removed from the per-phase tables; docs page expectations updated to match.
- [ ] `framework-qa-report.md` produced summarising:
  - Bugs fixed (FraiseQL PR links).
  - Bugs that became accepted limitations (with rationale).
  - Enhancements that shipped (with coverage page links).
  - Enhancements that deferred (with disposition).
- [ ] Docs build is clean (no broken cross-links to closed issues; no leftover citation drift).
- [ ] Cycle 5 Reviewer Item-11 carry-forward (exact `rustc` error quote in `migrations/upgrading/v2-2-to-v2-3.mdx`) — addressed against the current framework toolchain.

### Personas

The original "Framework Bug-Fixer (Opus 4.7)" persona is **retired** for this phase. The work fits the **Cleanup (Sonnet 4.6)** + **Verifier (Sonnet 4.6)** scope:

- **Cleanup** removes / updates `## Known issues` blocks and applies the per-page reconciliation edits.
- **Verifier** confirms the framework state matches the docs' claims (re-grep framework source at the new frozen SHA for every cited line range that's still in the docs).
- **Reviewer (Opus 4.7)** does the 15-point pass on any page that received a substantive edit.

### Gates

- **G3** (Phase 09 ship-readiness severity threshold) — preserved. The human decides whether any remaining accepted limitations are severe enough to block Phase 10. With most bugs fixed upstream, G3 is expected to be low-friction.
- **G4** (each framework PR merge as a human gate) — preserved but **retrospective**: the gate fires when the framework team merges each PR upstream, not when the docs-overhaul produces it. Docs records the merge in `framework-qa-report.md` rather than originating it.

### Cycles

Reconciliation has natural cycle granularity per **Phase 03 page** (since Phase 03 is the dense origin of FW-bugs):

- Cycle 1: multi-tenancy reconciliation (FW-3..FW-6).
- Cycle 2: file-storage reconciliation (FW-1, FW-7..FW-12).
- Cycle 3: observers reconciliation (FW-13..FW-23).
- Cycle 4: authentication reconciliation (FW-24..FW-29).
- Cycle 5: phase-02 / phase-04-08 page reconciliation (any framework changes that hit non-Phase-03 pages).
- Cycle 6: enhancement-coverage audit + `framework-qa-report.md` + phase close.

Per-cycle effort is low — these are typed-out cross-link + Known-Issues-block removals, not substantive rewrites. Estimate: 0.5 effort proxy total (down from the original 1.0).

### Carry-forwards into Phase 09 from Phase 03

- INFRA-1 (`demo.fraiseql.dev` TLS SAN) — actually Phase 10, not 09; documented here for traceability.
- Cycle 5 Reviewer item 11 (`v2-2-to-v2-3.mdx` exact rustc error quote) — Phase 09 work.

### Resume entry condition

Phase 09 starts after Phases 04-08 close + the framework team has shipped the v2.4 (or whichever) release with the 54-issue roadmap resolved. See `framework-roadmap-mapping.md § Re-triage protocol when resuming` for the step-by-step.
