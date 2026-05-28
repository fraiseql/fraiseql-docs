# Phase index — FraiseQL docs overhaul

Live status board. Update this file as phases progress.

---

## Status legend

- `[ ]` Not started
- `[~]` In progress (a persona is currently active on a cycle)
- `[?]` Awaiting human gate (proposal in `_internal/.plan/handoff.md`)
- `[x]` Complete (PR merged, CI docs-test green, Reviewer 15/15, all citations resolved)
- `[!]` Blocked on framework bug or external dependency (note the blocker on the phase file)

## Phases

| #  | File                                       | Theme                                                          | Effort | Status | Gates |
|----|--------------------------------------------|----------------------------------------------------------------|-------:|--------|-------|
| 00 | `phase-00-foundation.md`                   | Container harness, CI gating, style guide, SHA freeze, plan-into-repo move | 2.0 | `[ ]`  | G2 (contingent) |
| 01 | `phase-01-triage-and-ia.md`                | Stale-fact sweep, sidebar IA (G1), link audit, sweep matrix    | 1.0 | `[ ]`  | **G1** |
| 02 | `phase-02-migration-and-changelog.md`      | Release-notes hub, v2.0→v2.3 migration pages, breaking matrix  | 1.0 | `[ ]`  | — |
| 03 | `phase-03-critical-rewrites.md`            | multi-tenancy, file-storage, observers, authentication         | 2.0 | `[ ]`  | — |
| 04 | `phase-04-new-features-part1.md`           | Studio, Functions (WASM), Realtime subsystem                   | 2.0 | `[ ]`  | — |
| 05 | `phase-05-new-features-part2.md`           | Auth extensions, LTree, partial-period, native aggregations    | 2.0 | `[ ]`  | — |
| 06 | `phase-06-transport-and-protocol.md`       | REST, MCP, federation mTLS, schema integrity, trusted docs     | 1.5 | `[ ]`  | — |
| 07 | `phase-07-reference-rebuild.md`            | CLI, TOML, operators                                           | 2.0 | `[ ]`  | — |
| 08 | `phase-08-sweep-and-link-audit.md`         | Remaining feature pages, SDK reconciliation, screenshots       | 1.5 | `[ ]`  | — |
| 09 | `phase-09-framework-qa-pass.md`            | Close/accept every framework bug surfaced during phases 00–08  | 1.0 | `[ ]`  | **G3, G4** |
| 10 | `phase-10-finalize.md`                     | Archaeology removal, build perf, redirect map, launch          | 1.0 | `[ ]`  | **G5** |

**Effort total:** ~17 (content-volume proxy; not wall-clock).

See `methodology.md § 2` for the gate definitions and `personas.md § Human gates register` for the resolution protocol.

## Dependency graph

```
00 ──► 01 ──► 02 ──► 03 ──► 04 ──► 05 ──► 06 ──► 07 ──► 08 ──► 09 ──► 10
                       │       │       │
                       └───────┴───────┴── may proceed in parallel after 03 ships
                                           (different files, different reviewers)
```

Phases 04, 05, 06 can run in parallel if multiple writers are available — they touch disjoint sets of pages. Phase 07 (reference rebuild) is independent of 03–06 in principle but its examples lean on the rewritten / new pages, so it lands **after** them.

## Completed phases

*(append one line per phase as it merges)*

- *(none yet)*

## Filed framework bugs

*(append issue references as they're filed during doc work — phase 09 walks this list)*

- *(none yet)*

## Snapshot SHAs

- Codebase SHA at plan open: *(filled during phase 00)*
- Codebase SHA at code-freeze (phase 00 exit): *(filled during phase 00)*
- Codebase SHA at finalize: *(filled during phase 10)*

## Cross-phase risks register

| ID | Risk | Affects phases | Mitigation owner | Status |
|----|------|----------------|------------------|--------|
| R1 | Framework lands v2.4 mid-plan | 04–08 | Plan owner | open |
| R2 | MSSQL container instability | 03, 04, 06, 07 | Phase 00 | open |
| R3 | Sidebar IA decision blocks new pages | 04–06 | Phase 01 | open |
| R4 | Single-writer team forces 24h reviewer delay | all | Plan owner | open |
| R5 | Bug count exceeds phase 09 capacity | 09 | Phase 00 (triage criteria) | open |
