# Phase index — FraiseQL docs overhaul

Live status board. Update this file as phases progress.

---

## Frozen FraiseQL SHA

**`d0a4ed4ec1770c70707f68fd9019f2b561d87461`**

Frozen by Phase 00 close on 2026-05-28. This is the FraiseQL framework
commit that every documentation page in the overhaul validates against:
source citations, docs-test reproductions, the CI workflow's build
context, and the operator CLI's drift check all consult this SHA.

The single source of truth is `scripts/docs-test/FRAISEQL_SHA` (40
bytes, no trailing whitespace). The CI workflow and the operator CLI
prefer the file and fall back to a hard-coded constant only when the
file is absent (pre-Cycle-9 history).

**Bumping the SHA is human gate G2.** The Writer persona never bumps
it; if a bump becomes necessary mid-plan, the Writer surfaces a
`**G2 (SHA bump proposed)**` bullet in `_internal/.plan/handoff.md`
and stops. Default policy at Phase 00 close: hold to the frozen SHA;
the bump decision belongs to Phase 09 or Phase 10. See
`scripts/docs-test/FRAISEQL_SHA.README.md` for the full procedure.

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
| 00 | `phase-00-foundation.md`                   | Container harness, CI gating, style guide, SHA freeze, plan-into-repo move | 2.0 | `[x]`  | G2 (contingent) |
| 01 | `phase-01-triage-and-ia.md`                | Stale-fact sweep, sidebar IA (G1), link audit, sweep matrix    | 1.0 | `[x]`  | G1 (resolved 2026-05-29 → Option A) |
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

- **Phase 00** — 2026-05-28 — container harness (Compose + Dockerfile + storage sidecars + operator CLI + smoke + CI), style guide check-in, docs-page PR template, frozen FraiseQL SHA. PR #11 (draft until human marks ready-for-review). Final cycle commit: see Phase 00 / Cycle 9 close entry in `_internal/.plan/handoff.md`.
- **Phase 01** — 2026-05-29 — triage and IA. Version-string sweep, stray-syntax sweep, internal link audit (0 dead links), external link audit (66 audited, 22 must-fix mechanically applied, 4 deferral groups to Phase 02/03), Homebrew claim verified absent and removed, sidebar redrawn to **Option A** (10 audience-grouped top-levels + Examples as 11th visible — G1 resolved), 76 page moves with 76 Astro `redirects` entries, sweep matrix authored at `src/content/docs/_internal/_sweep-matrix.md` (172 page rows + 2 framework-bug rows + 9 cross-phase rows + 4 deferral-class rows). Methodology § 4 amended to accept the `{/* source: ... */}` JSX comment form for `.mdx` (MDX 3 incompatibility). PR #12 (draft until human marks ready-for-review). Final cycle commit: see Phase 01 / Cycle 7 close entry in `_internal/.plan/handoff.md`.

## Filed framework bugs

*(append issue references as they're filed during doc work — phase 09 walks this list)*

- **FW-1** — https://github.com/fraiseql/fraiseql/issues/326 — `storage(azure,gcs): expose endpoint override so emulators (Azurite, fake-gcs-server) are reachable via config`. Severity `qol`. Filed during Phase 00 / Cycle 3 (storage sidecars). Tracked in `_internal/.plan/framework-qa-triage.md`.
- **FW-2** — https://github.com/fraiseql/fraiseql/issues/327 — `server: fraiseql-server binary hardcodes PostgresAdapter — quickstart's multi-DB tabs are unreachable`. Severity `regression-or-doc-bug`. Filed during Phase 00 / Cycle 5 (smoke). Tracked in `_internal/.plan/framework-qa-triage.md`.

## Snapshot SHAs

- Codebase SHA at plan open: `d0a4ed4ec1770c70707f68fd9019f2b561d87461` (frozen 2026-05-28 by Phase 00 close — see "Frozen FraiseQL SHA" section above)
- Codebase SHA at code-freeze (phase 00 exit): `d0a4ed4ec1770c70707f68fd9019f2b561d87461` (same — Phase 00 froze it as the initial baseline)
- Codebase SHA at finalize: *(filled during phase 10)*

## Cross-phase risks register

| ID | Risk | Affects phases | Mitigation owner | Status |
|----|------|----------------|------------------|--------|
| R1 | Framework lands v2.4 mid-plan | 04–08 | Plan owner | open |
| R2 | MSSQL container instability | 03, 04, 06, 07 | Phase 00 | open |
| R3 | Sidebar IA decision blocks new pages | 04–06 | Phase 01 | open |
| R4 | Single-writer team forces 24h reviewer delay | all | Plan owner | open |
| R5 | Bug count exceeds phase 09 capacity | 09 | Phase 00 (triage criteria) | open |
