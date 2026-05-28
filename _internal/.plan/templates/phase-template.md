# Phase NN: <Title>

## Objective

<One-sentence goal.>

## Success criteria

- [ ] <Concrete, verifiable outcome 1>
- [ ] <Concrete, verifiable outcome 2>
- [ ] All pages in this phase pass the 15-point adversarial-review checklist
- [ ] CI docs-test workflow green for every page on declared DB matrix
- [ ] All source citations resolved at the frozen FraiseQL SHA
- [ ] No framework bug surfaced during the phase remains unfiled
- [ ] Sidebar updated; cross-links present; build clean
- [ ] Handoff file (`_internal/.plan/handoff.md`) updated at phase close

## Scope (in)

- <File or feature 1>
- <File or feature 2>

## Scope (out)

- <Explicitly excluded>

## Dependencies

- **Requires:** Phase <N−1> complete (specifically: <what artifact>)
- **Blocks:** Phase <N+1> (specifically: <what they need from us>)

## Personas involved

| Cycle | Personas (in order) |
|-------|---------------------|
| 1 | Writer → Bug-Finder (if framework-touching) → Writer → Reviewer / Verifier (parallel) → Cleanup |
| 2 | ... |
| N (last) | Style Auditor → Cleanup |

## Human gates

- **G?** — <which gate(s) fire in this phase, if any>. Cycle: `<N>`. Proposal written to handoff; phase status `[?]` until resolved.

## TDD cycles

### Cycle 1: <slug>

- **RED:** <failing reproduction — page is 404, snippet errors, link is dead>. Persona: Writer (+ Bug-Finder if framework-touching).
- **GREEN:** <minimum docs content that makes it pass, including `<!-- source: ... -->` annotations>. Persona: Writer.
- **REFACTOR:** <prose polish, structural improvements>. Persona: Writer.
- **CLEANUP:** <lint, format, sidebar, cross-links, build, citation strip>. Personas: Source-Citation Verifier → Cleanup.
- **Review:** 15-point checklist. Persona: Reviewer (fresh context).

### Cycle 2: <slug>

...

### Cycle <last>: Style audit & phase close

- **RED:** style guide may not have been uniformly applied across all pages produced this phase.
- **GREEN:** Style Auditor reads every page in `## Pages completed`; produces edit list at `_internal/.plan/style-audits/phase-NN.md`.
- **CLEANUP:** Cleanup persona applies the edit list; build clean.
- **Handoff:** append phase outcome to `_internal/.plan/handoff.md`; flip status to `[x]`.

## Adversarial review protocol

Each page in this phase:

1. Writer persona completes CLEANUP and opens PR with `CI docs-test green: <run URL>` in the description.
2. Reviewer persona (fresh context, no scroll-back from Writer) checks out the branch.
3. Reviewer re-runs the page's `*.docs-test.sh` from a clean docker state and reads the CI output independently.
4. Reviewer re-greps ≥3 random source citations against the frozen FraiseQL SHA.
5. Reviewer fills the 15-point checklist on the PR.
6. Source-Citation Verifier runs in parallel; strips citations only after each resolves.
7. Blocking issues kick the page back to Writer; non-blocking → inline comments.
8. PR merges only at 15/15 green.

## Container verification matrix

| Page | PG | MySQL | SQLite | MSSQL | Other (Redis/NATS/MinIO/...) |
|------|----|----|----|----|-----|
| `<page>` | ✅ | ✅ | ✅ | ✅ | <list> |

## Risks specific to this phase

| Risk | Mitigation |
|------|------------|
|      |            |

## Estimated effort

<Effort proxy in weeks-equivalent. Persona-mix: which personas dominate. Expected escalations from Sonnet to Opus.>

## Status

- [ ] Not started
- [ ] RED in progress
- [ ] GREEN in progress
- [ ] REFACTOR in progress
- [ ] CLEANUP in progress
- [ ] `[?]` Awaiting human gate
- [ ] Complete

## Owner

*(unclaimed)*

## Pages completed

*(append slugs as cycles close)*

## Framework bugs filed

*(append issue references as they're filed)*
