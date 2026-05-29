# Phase 00: Foundation

## Objective

Build the infrastructure that every subsequent phase depends on: a containerised reproduction harness, a CI gate that runs it, a style guide, and a frozen FraiseQL SHA that the entire overhaul targets.

## Why this exists

Every other phase verifies its claims against a running FraiseQL stack. If that stack is set up ad-hoc per page, we get drift, false greens, and "works on my laptop" outcomes that are exactly what got us into the v2.0→v2.3 documentation gap in the first place. Phase 00 commits the harness to the docs repo so that **every page that ships from this point forward has an executable companion that someone else can re-run**.

## Success criteria

- [ ] `scripts/docs-test/docker-compose.docs-test.yml` boots PG 16, MySQL 8, SQLite (mounted), MSSQL 2022, Redis 7, NATS 2.10, MinIO, Azurite, fake-gcs-server, and a `fraiseql-server` container built from sibling `~/code/fraiseql`.
- [ ] `scripts/docs-test/docs-test.sh up|down|exec|status|reset` covers the operator surface.
- [ ] At least one **smoke** `pages/_smoke.docs-test.sh` proves a documented quickstart end-to-end across all four DB targets.
- [ ] `.github/workflows/docs-test.yml` runs every `*.docs-test.sh` on every PR touching `src/content/docs/` or `scripts/docs-test/`.
- [ ] `templates/style-guide.md` content is copied to `src/content/docs/_internal/style-guide.md` (gitignored from search, used by contributors).
- [ ] Phase-00 commit captures the codebase SHA snapshot — written into `.phases/README.md` and `scripts/docs-test/FRAISEQL_SHA`.
- [ ] An "adversarial reviewer" cheat-sheet PR template lands in `.github/PULL_REQUEST_TEMPLATE/docs-page.md`.

## Scope (in)

- Docker-Compose harness, image dockerfiles, fixtures, baseline config overlays.
- CI workflow definition.
- Style guide checked into the repo (so contributors can read it; the `/tmp/` copy is just a planning artefact).
- SHA freeze.
- PR template.
- One smoke reproduction script proving the harness works end-to-end.

## Scope (out)

- Any actual documentation page work. Phase 01 starts that.
- Per-page reproduction scripts beyond the smoke test.
- SDK testing infra (separate plan).
- Performance benchmarking infra (separate plan).

## Dependencies

- **Requires:** read access to `~/code/fraiseql` at a stable SHA.
- **Blocks:** all subsequent phases. Cannot start phase 01 until at least `docs-test.sh up` works locally.

## Personas involved

| Cycle | Personas |
|-------|----------|
| 0 | Cleanup (move) |
| 1–6 | Writer (Opus 4.7) for compose/Dockerfile/CI plumbing → Cleanup (Sonnet 4.6) for lint/format |
| 7 | Writer → Cleanup |
| 8 | Writer (PR template) |
| 9 | Writer (SHA freeze) → handoff |

Phase 00 is mostly mechanical infrastructure; Opus for the design judgement (Dockerfile multi-stage, CI matrix shape), Sonnet for the iteration loops. The harness itself is reviewed in CI on a fresh runner (see adversarial-review protocol below) rather than by a separate Reviewer persona.

## Human gates

- **G2 (contingent)** — if v2.4 lands during the plan window, the SHA-bump decision is a human gate. Default policy at phase 00 close: hold to the frozen SHA; bump is a phase 09 or phase 10 decision.

## TDD cycles

### Cycle 0: Move plan into the docs repo

- **RED:** the plan currently lives only in `/tmp/fraiseql-docs-overhaul/`. A reboot or `/tmp/` cleanup loses 17 weeks of planning. The plan also needs to be visible to every persona invoked from the docs repo without crossing filesystem boundaries.
- **GREEN:** copy `/tmp/fraiseql-docs-overhaul/` to `~/code/fraiseql-docs/_internal/.plan/`. Add `_internal/` to `astro.config.mjs` exclusions (so it never reaches the build output or the search index). Track `_internal/.plan/` in git. Create empty `_internal/.plan/handoff.md`, `_internal/.plan/style-audits/`, `_internal/.plan/audits/`, `_internal/.plan/red-evidence/`, `_internal/.plan/framework-qa-triage.md`.
- **REFACTOR:** verify Astro build excludes the directory — visit `bun run build` output; the `_internal/` URLs must not appear.
- **CLEANUP:** the `/tmp/` copy is no longer authoritative; all personas read from `_internal/.plan/`. Phase 10 still deletes `_internal/.plan/` as part of finalisation.

### Cycle 1: Compose stack boots

- **RED:** create empty `docker-compose.docs-test.yml`; running `docker compose up` fails on missing services. Capture the failure.
- **GREEN:** add services for `postgres`, `mysql`, `sqlite-init`, `mssql`, `redis`, `nats` with healthchecks. `docker compose up --wait` returns 0.
- **REFACTOR:** profile labels (`postgres`, `mysql`, etc.) so single-DB tests don't boot the full stack. Add `--profile <name>` shortcut to `docs-test.sh`.
- **CLEANUP:** lint with `docker compose config -q`; pin every image to a digest; commit.

### Cycle 2: FraiseQL container

- **RED:** the smoke script tries to query `http://fraiseql:8080/health` and fails (no FraiseQL container yet).
- **GREEN:** `Dockerfile.fraiseql` multi-stage build: `cargo build --release --features "arrow,observers,observers-nats,observers-enterprise,rest,redis-pkce,redis-apq,redis-rate-limiting"` then a slim runtime image. Compose entry mounts `configs/baseline.toml` as `/etc/fraiseql/fraiseql.toml`. `/health` returns 200.
- **REFACTOR:** cache the build layer with a bind mount over `~/code/fraiseql/target` so iteration takes ~30s, not 8 min.
- **CLEANUP:** image-size budget (≤300 MB compressed); commit.

### Cycle 3: Storage-backend sidecars

- **RED:** future storage page tests will need S3-compatible / Azure / GCS endpoints. Without them, those tests can't run.
- **GREEN:** add MinIO, Azurite, fake-gcs-server containers behind `--profile storage`. Each preloaded with one bucket named `fraiseql-docs-test`.
- **REFACTOR:** environment-variable overrides in `baseline.toml` overlays so the same FraiseQL container points at any backend.
- **CLEANUP:** smoke check: write a 1 KB blob via each backend, read it back.

### Cycle 4: Operator CLI

- **RED:** every page reproduction would otherwise duplicate ~30 lines of docker plumbing.
- **GREEN:** `docs-test.sh` with subcommands:
  - `up [--profile X,Y,Z]`
  - `down [--volumes]`
  - `reset` (down -v && up)
  - `exec <service> -- <cmd>`
  - `status`
  - `logs <service>`
  - `sha` (prints `~/code/fraiseql` HEAD vs. the frozen SHA; warns on drift)
- **REFACTOR:** completion script for bash/zsh.
- **CLEANUP:** shellcheck clean; `--help` for every subcommand.

### Cycle 5: Smoke reproduction

- **RED:** no page has a reproduction yet, so we can't prove the harness works as designed.
- **GREEN:** `pages/_smoke.docs-test.sh` follows the `getting-started/quickstart.mdx` happy path end-to-end on PostgreSQL: install schema, compile, boot server, run one query, assert shape. Then runs the same on MySQL with the MySQL-flavoured fixture. Then SQLite. Then MSSQL.
- **REFACTOR:** factor out the common assertion helpers into `scripts/docs-test/lib/assert.sh`.
- **CLEANUP:** smoke runs end-to-end in <4 minutes on a developer laptop.

### Cycle 6: CI gating

- **RED:** create a deliberately broken `_smoke.docs-test.sh` (assertion that fails). CI must catch it. This proves that the methodology's "CI is the only GREEN gate" rule (`methodology.md § 6.1`) is enforced by infrastructure, not by Writer-persona discipline alone.
- **GREEN:** `.github/workflows/docs-test.yml`:
  - Triggers: PR opens, push to default, manual dispatch.
  - Matrix: per-page (each `*.docs-test.sh` is one job).
  - Concurrency: cancel-in-progress on the same PR.
  - Hardware: `ubuntu-latest` with Docker; bumps to a large runner if needed.
  - Caches: `~/.cargo`, `~/code/fraiseql/target`, Bun deps.
  - **Output:** the run URL must be machine-readable so the Writer persona can paste it into the PR description and the handoff file without confabulation.
- **REFACTOR:** add the docs-test workflow as a required check on the repo's branch protection (out-of-band — human action).
- **CLEANUP:** wipe the deliberately broken script; verify CI flips back to green.

### Cycle 7: Style guide checked in

- **RED:** style guide lives in `/tmp/`. Writers in later phases will not see it.
- **GREEN:** copy `/tmp/fraiseql-docs-overhaul/templates/style-guide.md` to `src/content/docs/_internal/style-guide.md`. Configure Astro to exclude `_internal/` from build output and search index.
- **REFACTOR:** add a `STYLE.md` symlink at repo root for contributors.
- **CLEANUP:** confirm the live build excludes `_internal/`.

### Cycle 8: PR template

- **RED:** Writer personas will forget the checklist without one in their face. The CI-as-only-GREEN-gate rule is easy to violate without a structural prompt at PR time.
- **GREEN:** `.github/PULL_REQUEST_TEMPLATE/docs-page.md` mirrors the 15-point adversarial-review checklist and includes mandatory fields:
  - `CI docs-test run URL:` (Writer fills; empty blocks merge)
  - `Reviewer persona session:` (Reviewer fills)
  - `Source-Citation Verifier outcome:` (Verifier fills)
  - `Frozen FraiseQL SHA:` (Writer fills; mismatch blocks merge)
- **REFACTOR:** the template is the persona handoff contract in miniature — what each downstream persona expects from the upstream one.
- **CLEANUP:** ship.

### Cycle 9: SHA freeze

- **RED:** if every phase re-pegs to `main`, phases land on different framework SHAs and behaviour drifts across the overhaul.
- **GREEN:** write the current `~/code/fraiseql` HEAD SHA to `scripts/docs-test/FRAISEQL_SHA` and `_internal/.plan/.phases/README.md`. The Dockerfile pins to this SHA via `git checkout`. Operator CLI's `sha` subcommand warns when the working tree drifts from the frozen SHA. The Source-Citation Verifier persona reads from this SHA, not from `main`.
- **REFACTOR:** SHA bump procedure documented inline — bumping is **human gate G2**. The Writer persona never bumps; if v2.4 lands mid-plan, the persona writes a G2 proposal to `_internal/.plan/handoff.md` and stops.
- **CLEANUP:** PR includes the SHA bump rationale (initial freeze) and the handoff file is updated.

## Adversarial review protocol

The harness itself gets adversarially reviewed by a different person:

1. Reviewer wipes their local Docker state (`docker system prune -a`).
2. Reviewer clones the docs repo fresh.
3. Reviewer runs `./scripts/docs-test/docs-test.sh up` from a cold start. Must succeed.
4. Reviewer runs `./scripts/docs-test/pages/_smoke.docs-test.sh` against PG, MySQL, SQLite, MSSQL. All four must succeed.
5. Reviewer files at least three "tries to break it" cases:
   - Boot with `FRAISEQL_SHA` mismatched. Expect: warning surface.
   - Boot with a port already in use. Expect: clear error, not a hang.
   - Boot with no `~/code/fraiseql` checkout. Expect: clear error pointing to the symlink / clone instructions.
6. Reviewer signs off on `.phases/phase-00-foundation.md` `## Status` block.

## Container verification matrix

| Smoke target | PG | MySQL | SQLite | MSSQL | Redis | NATS | MinIO | Azurite | fake-gcs |
|--------------|----|----|----|----|----|----|----|----|----|
| `_smoke`     | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

## Risks specific to this phase

| Risk | Mitigation |
|------|------------|
| MSSQL container needs ~2 GB RAM and slow boot | Use the `2022-CU13-ubuntu-22.04` image; healthcheck waits up to 90s; document RAM requirement in `docs-test.sh --help` |
| `~/code/fraiseql` is a sibling checkout, not part of the docs repo | The Dockerfile's build context expects a bind-mount; CI clones FraiseQL to a sibling dir explicitly |
| Image digest pinning breaks when registries garbage-collect | Mirror the pinned images to an internal registry **after** phase 00; out of scope here, just noted |
| CI runner can't fit the full stack | Profiles let per-page tests boot only what they need; the smoke test is the only one that boots everything |
| Docker on developer macOS / Windows behaves differently | Pin to Compose v2 syntax only; document a Linux VM fallback for non-Linux hosts |

## Estimated effort

**Effort proxy: 2.** Most of the work is mechanical infrastructure (Compose plumbing, Dockerfile, CI workflow) — Writer-Opus for design decisions (multi-stage build, CI matrix shape), Cleanup-Sonnet for iteration. Expected wall-clock: dominated by Docker image build times and CI debugging cycles, not by content authoring. Cycle 0 (plan-into-repo move) is ~10 minutes of Cleanup-Sonnet time and should run before anything else.

## Status

- [x] Cycle 0 complete (plan tree in `_internal/.plan/`; Astro build verified clean; gate G6 resolved by pivot)
- [x] Cycle 1 (Compose stack) — `396c1b2` + `9adb4eb`
- [x] Cycle 2 (FraiseQL container) — `d8b7e5c`
- [x] Cycle 3 (Storage backend sidecars) — `1356d55`
- [x] Cycle 4 (Operator CLI) — `2a41e5b`
- [x] Cycle 5 (Smoke reproduction) — `14b90c0`
- [x] Cycle 6 (CI workflow gating) — `d251931` + `3aad991` + `379f657` (RED) + `c8b9e62` (CLEANUP revert)
- [x] Cycle 7 (Style guide checked in) — `d166ff1`
- [x] Cycle 8 (docs-page PR template) — `32e4e6f`
- [x] Cycle 9 (FraiseQL SHA freeze) — see commit landing this entry
- [x] **Complete — 2026-05-28**. Final phase-close commit lands with the Cycle-9 handoff entry. PR #11 remains draft until the human flips it ready-for-review.

## Owner

orchestrator (Claude) — through phase close.

## Cycles completed

- **Cycle 0 (original)** — 2026-05-28 — first executed against `~/code/fraiseql_v2.dev`. Voided when post-cycle diligence revealed disjoint history vs. the canonical `fraiseql/fraiseql-docs` remote. Gate G6 raised; human chose option C (pivot to canonical checkout).
- **Cycle 0 (post-pivot)** — 2026-05-28 — replayed in `~/code/fraiseql-docs/` (clone of `fraiseql/fraiseql-docs@4e3dbdb`). Plan tree at `_internal/.plan/`; runtime subdirs scaffolded; `astro.config.mjs` documentation comment added; `bun run build` verification pending in this tree (will run on branch). See handoff.md entry.

## Framework bugs filed

*(if any uncovered while wiring the harness — likely zero this phase, but possible)*
