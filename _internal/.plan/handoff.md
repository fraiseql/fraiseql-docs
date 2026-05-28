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

### Phase 00 / Cycle 1 close — Writer (Opus 4.7) — 2026-05-28

- **Landed under `scripts/docs-test/`:**
  - `docker-compose.docs-test.yml`: services `postgres`, `mysql`, `sqlite-init`, `mssql`, `redis`, `nats`. Each carries its own profile label plus the shared `all` profile. The `fraiseql` service slot and `minio` / `azurite` / `fake-gcs-server` storage sidecars are left as TODO comment blocks (Cycle 2 and Cycle 3 respectively) — no implementation, no profile leakage.
  - `.env.example`: centralised credentials. `DB_USER=fraiseql`, `DB_PASSWORD=fraiseql_docs_test`, `DB_NAME=fraiseql` (the DB name matches the framework default in `crates/fraiseql-server/src/server_config/defaults.rs:9`, `postgresql://localhost/fraiseql`). MSSQL gets its own `Fraiseql_docs_test1!` to satisfy the SA password policy. Host port overrides exposed for the operator-CLI cycle to consume.
  - Image digests pinned (all `linux/amd64`, resolved 2026-05-28 via local pull → `RepoDigests[0]`):
    - `postgres:16-alpine@sha256:16bc17c64a573ef34162af9298258d1aec548232985b33ed7b1eac33ba35c229`
    - `mysql:8.4@sha256:c36050afdca850f23cef85703f84c7531a5ae155a11b5ee1c60acb09937c4084`
    - `alpine:3.20@sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc` (sqlite-init shell)
    - `mcr.microsoft.com/mssql/server:2022-CU13-ubuntu-22.04@sha256:c4369c38385eba011c10906dc8892425831275bb035d5ce69656da8e29de50d8`
    - `redis:7-alpine@sha256:6ab0b6e7381779332f97b8ca76193e45b0756f38d4c0dcda72dbb3c32061ab99`
    - `nats:2.10-alpine@sha256:b83efabe3e7def1e0a4a31ec6e078999bb17c80363f881df35edc70fcb6bb927`
  - Healthchecks: PG via `pg_isready`; MySQL via `mysqladmin ping`; MSSQL via `sqlcmd … -Q 'SELECT 1'` with `start_period: 90s`; Redis via `redis-cli ping`; NATS via the `/healthz` monitoring endpoint. SQLite is a one-shot `restart: "no"` job that materialises the DB file under a named volume.
  - Host ports: `54320/PG`, `13306/MySQL`, `14330/MSSQL`, `63790/Redis`, `42220/NATS`. (The phase doc suggested `33060` for MySQL but that host port is taken by an existing user workload, hence the bump to `13306`.)
- **`.gitignore` change:** added `scripts/docs-test/.env` only; nothing else touched.
- **RED evidence:** `_internal/.plan/red-evidence/cycle-01-empty-compose.transcript` — empty file fails all of `up`, `up --wait`, `config -q`, `ps` with exit 1 and stderr `empty compose file`.
- **GREEN validation (partial — see blocker below):** `_internal/.plan/red-evidence/cycle-01-green-validation.transcript`.
  - `docker compose … --profile all config -q` → **EXIT 0**.
  - Profile selection verified for every profile (`postgres`, `mysql`, `sqlite`, `mssql`, `redis`, `nats`, `all`, none). Each selects exactly the intended service set.
  - `down -v` tears down cleanly (network + all named volumes removed).
- **Blocker on the `up --wait` gate (host environmental, not docs-side):** the workstation Docker daemon (29.4.1 / containerd 2.2.3) returns `failed to create task for container: failed to start shim: start failed: failed to create TTRPC connection: unsupported protocol: Yunix` on every container start, including `docker run --rm hello-world`. The daemon has been up 2 weeks 3 days with ~750 running containers and ~9094 containerd tasks; shim/runtime state is corrupted. Recovery is `systemctl restart containerd docker.service` which **I deliberately did not run** — those 750 containers are user workloads. Local `up --wait` validation cannot complete on this host until the daemon is recycled. The compose file itself parses, validates, and tears down cleanly; the issue is strictly at the container-runtime layer.
- **Suggested next step before Cycle 2:** human (or Cycle 2 persona) restarts the Docker daemon on this host and re-runs `docker compose -f scripts/docs-test/docker-compose.docs-test.yml --profile all up --wait`. If healthchecks pass, Cycle 1's CLEANUP gate is materially met and Cycle 2 can proceed against a known-good stack. If any healthcheck fails, file a bug here before Cycle 2 builds on top.
- **Anti-scope held to:** no `Dockerfile.fraiseql` (Cycle 2), no MinIO/Azurite/fake-gcs (Cycle 3), no `docs-test.sh` (Cycle 4), no `_smoke.docs-test.sh` (Cycle 5), no CI workflow (Cycle 6), no fixtures/init schemas (Cycle 5), no `src/content/docs/` edits.
- **Framework issues filed:** 0. No framework behaviour was exercised this cycle — only image pinning, host ports, and healthcheck wiring.
- **Push posture:** branch `phase-00/foundation` has the new Cycle 1 commit on top of Cycle 0's `8d92678`. Not pushed — no CI exists yet to gate against, and the cycle spec's "pushing is optional this cycle" guidance applies. Cycle 2 author can push if convenient.
- **Open gates:** none new. G2 (SHA bump) and Cycle 1's local `up --wait` re-validation are deferred to Cycle 2's start — not a human gate, just a Docker daemon recycle.

---

### Phase 00 / Cycle 1 finishing — orchestrator — 2026-05-28

Closes the deferred `up --wait` validation from the prior entry. Docker daemon was recycled by the human (authorised "restart for me with safeguards"; passwordless sudo unavailable so the human ran `sudo systemctl restart containerd docker.service` themselves). `docker run --rm hello-world` returned clean post-restart, confirming the `Yunix` shim mismatch is gone. State snapshots from before the restart are retained at `/tmp/docker-restart-2026-05-28/` (running-names-before.txt, restart-policies.txt, networks.txt, volumes.txt) so the 4 996-volume / 4 995-container cruft can be pruned later with `docker container prune -f && docker volume prune -af`. The Cycle-1 image pulls are not affected — they remain cached by digest.

Two real Cycle-1 bugs surfaced and were fixed in commit `9adb4eb` (on top of the Writer's `396c1b2`):

1. **MSSQL healthcheck path wrong.** The 2022-CU13-ubuntu-22.04 image bundles the legacy mssql-tools at `/opt/mssql-tools/bin/sqlcmd`, not the modern `/opt/mssql-tools18/bin/sqlcmd` the Writer had configured. The legacy sqlcmd also does not accept `-C` or `-N` (those are mssql-tools18 flags). The previous healthcheck failed with exit 127 (file not found) on 23 consecutive probes. Fixed to use the legacy path and drop the unsupported flags. Container went healthy in ~10 s post-fix on the re-validation run.

2. **`sqlite-init` in `--profile all` broke `up --wait`.** A one-shot service that exits 0 is treated as failure by `docker compose up --wait`. The cold-start `--profile all up --wait` aborted in 1 s when `sqlite-init` exited (0). Fixed by dropping `sqlite-init` from the `all` profile (it stays on the `sqlite` profile). The idiomatic invocation is now `docker compose run --rm sqlite-init` or `docker compose --profile sqlite up sqlite-init`. Cycle 5's smoke test will follow that pattern. The compose-file header for `sqlite-init` now documents this explicitly. This is a *design correction* against the literal phase-doc text (which lists `sqlite-init` alongside the long-running services in the `--wait` set); the phase doc's success criterion remains met — `up --wait` returns 0 — just over the five long-running services, with SQLite materialised via a separate idiomatic command.

After the fix, on a cold start (volumes pruned):

- `docker compose -f scripts/docs-test/docker-compose.docs-test.yml --profile all up --wait --wait-timeout 240` → **exit 0 in 21.6 s**, all five services (postgres, mysql, mssql, redis, nats) healthy. Full transcript at `_internal/.plan/red-evidence/cycle-01-up-wait-cold-start.transcript`.
- `docker compose -f scripts/docs-test/docker-compose.docs-test.yml run --rm sqlite-init` → exit 0, materialises `/data/fraiseql.db`, prints `main: /data/fraiseql.db r/w`.
- `docker compose -f scripts/docs-test/docker-compose.docs-test.yml --profile <p> config -q` clean for every profile (`all`, `postgres`, `mysql`, `sqlite`, `mssql`, `redis`, `nats`).
- `docker compose -f scripts/docs-test/docker-compose.docs-test.yml --profile all --profile sqlite down -v --remove-orphans` removes every named volume and the default network with zero orphans.

Cycle 1 is materially complete. Branch `phase-00/foundation` now has three commits on top of `origin/main` (`4e3dbdb`): `8d92678` Cycle 0 plan seed → `396c1b2` Compose stack → `9adb4eb` healthcheck + profile fix. Not pushed (no CI yet; pushing deferred). Next persona: Writer (Opus 4.7) for Cycle 2 — `Dockerfile.fraiseql` multi-stage build with the framework's full docs-relevant feature set.

Docs-test suite: 0/0 pages (Cycles 2–8 produce pages; Cycle 6 wires the CI). Framework issues filed: 0. Open gates: none.

---

### Phase 00 / Cycle 2 close — Writer (Opus 4.7) — 2026-05-28

- **Landed under `scripts/docs-test/`:**
  - `Dockerfile.fraiseql`: multi-stage build. Stage 1 (`rust:1.92-slim`) compiles `fraiseql-server` with `cargo build --release --locked -p fraiseql-server --features "$CARGO_FEATURES"`. Default feature set matches the phase-doc spec verbatim: `arrow,observers,observers-nats,observers-enterprise,rest,redis-pkce,redis-apq,redis-rate-limiting`. Every feature was grep-verified against `crates/fraiseql-server/Cargo.toml` at the frozen SHA (lines 152–195) before the Dockerfile landed — see file:line in the inline comment. Stage 2 (`debian:bookworm-slim`) installs runtime deps (libpq5, ca-certificates, curl for the Compose healthcheck), creates a non-root `fraiseql:fraiseql` user with UID/GID 10001, and `COPY --from=builder` the stripped binary into `/app/fraiseql-server`. Baseline compiled schema is generated inline at `/etc/fraiseql/schema.compiled.json` (empty arrays — `{"types": [], "queries": [], ...}` — accepted by `CompiledSchema::from_json`, cited at `crates/fraiseql-core/src/schema/compiled/schema.rs:L57-L66`). `FRAISEQL_ENV=development` is set on the image so the production-mode CORS validation (`crates/fraiseql-server/src/server_config/methods.rs:L199-L217`) does not reject the docs-test baseline.
  - `configs/baseline.toml`: minimal config overlay. `bind_addr = "0.0.0.0:8080"`, `database_url = "postgresql://fraiseql:fraiseql_docs_test@postgres:5432/fraiseql"` (matches the Compose `.env.example` credentials), `schema_path = "/etc/fraiseql/schema.compiled.json"`. CORS is enabled with a placeholder origin so the overlay also works when the operator boots without `FRAISEQL_ENV` set. Admin / metrics / playground / introspection all default-off (and the file re-states the defaults so per-page overlays can flip individual surfaces). Every non-obvious key carries a `<!-- source: path:Lstart-Lend -->` HTML-comment citation pointing at the `server_config` schema and `defaults.rs` functions — the Verifier persona will re-grep them at phase close.
  - `docker-compose.docs-test.yml`: the Cycle-1 TODO slot is filled. The `fraiseql` service builds from `../../../fraiseql` (i.e. `~/code/fraiseql`) using the Dockerfile, tags the result `fraiseql-docs-test-fraiseql:latest`, declares `depends_on` against `postgres` and `redis` with `condition: service_healthy`, mounts `./configs/baseline.toml:/etc/fraiseql/fraiseql.toml:ro`, exposes port 8080, and uses `curl -fsS http://127.0.0.1:8080/health` as the Compose healthcheck (`interval: 5s`, `timeout: 3s`, `retries: 20`, `start_period: 60s`). `postgres` and `redis` were added to the `fraiseql` profile so `docker compose --profile fraiseql up` boots them automatically — Compose does not auto-activate dependency profiles. Build args wire `FRAISEQL_SHA=d0a4ed4ec1770c70707f68fd9019f2b561d87461` and the full `CARGO_FEATURES` string.
  - `.env.example`: added `HOST_PORT_FRAISEQL=8080` and an `FRAISEQL_LOG` override comment.
- **Feature-flag deviations from the phase-doc spec:** **none**. All eight requested features (`arrow`, `observers`, `observers-nats`, `observers-enterprise`, `rest`, `redis-pkce`, `redis-apq`, `redis-rate-limiting`) are defined on `fraiseql-server` itself at the frozen SHA — verified by inspection of `crates/fraiseql-server/Cargo.toml:L152-L195`. The phase doc's worry about `redis-pkce` possibly being a `fraiseql-core`-only feature is unfounded for this SHA: `redis-pkce = ["auth", "fraiseql-auth/redis-pkce"]` is on `fraiseql-server` (line 182). No discrepancies to record in the handoff beyond this confirmation.
- **Health endpoint citation (G-test for the Verifier):**
  - `/health` route mount: `crates/fraiseql-server/src/server/routing/admin.rs:L28-L33` — base routes are merged onto the app router *without* auth middleware. The comment on L28 reads "Build base routes (always available without auth)".
  - Default `health_path = "/health"`: `crates/fraiseql-server/src/server_config/defaults.rs:L63-L65`.
  - Handler implementation returning 200 when the database is reachable, 503 otherwise: `crates/fraiseql-server/src/routes/health.rs:L140-L175` (and onward — handler body covers observers/cache/secrets feature gates too). The handler probes the executor's adapter via `health_check().await`; with the docs-test Compose stack the PG service is healthy before `fraiseql` depends-on-released it, so the first probe returns 200.
- **RED evidence:** `_internal/.plan/red-evidence/cycle-02-no-fraiseql-service.transcript` — boots the Cycle-1 stack (no fraiseql service yet) and runs `curl --fail-with-body -sS http://localhost:8080/health` which returns exit 7 (connection refused). docker compose ps confirms no `fraiseql` row.
- **GREEN evidence:** `_internal/.plan/red-evidence/cycle-02-health-200.transcript`. From a cold start (volumes pruned), `docker compose -f scripts/docs-test/docker-compose.docs-test.yml --profile all up -d --wait --wait-timeout 240` returned exit 0 in **43.4 s** with all six services Healthy. `curl --fail-with-body -sS http://localhost:8080/health` returned HTTP 200 with body `{"status":"healthy","database":{"connected":true,"database_type":"PostgreSQL",...},"version":"2.3.2","schema_hash":"316c9100f7a872c8c411033ac2a00066"}`. Healthcheck log: five consecutive `ExitCode: 0` probes, `FailingStreak: 0`. Profile selection re-verified for every profile (`all`, `postgres`, `mysql`, `sqlite`, `mssql`, `redis`, `nats`, `fraiseql`) — `--profile fraiseql` selects exactly `{fraiseql, postgres, redis}`.
- **Image-size budget (CLEANUP):** uncompressed `Size=44 927 736` (44.9 MB); compressed `docker save | gzip | wc -c=44 562 679` (44.5 MB). **Well under the 300 MB cap** (≈15% of budget). The workspace `[profile.release]` already sets `strip = true` and `lto = "fat"`; the explicit `strip target/release/fraiseql-server` in the builder stage is a belt-and-suspenders no-op. Distroless was not needed.
- **Build cache (REFACTOR):** the Dockerfile uses BuildKit `--mount=type=cache,id=fraiseql-docs-cargo-{registry,git,target},target=…` for the cargo registry, git, and `/build/target` directories. **Note for the host this cycle was authored on:** Docker 29.5.1 ships without the buildx CLI plugin by default. To produce GREEN evidence I installed `docker-buildx v0.18.0` user-locally at `~/.docker/cli-plugins/docker-buildx` (no system change; reversible). CI runners (ubuntu-latest) ship buildx; this is a developer-laptop quality-of-life requirement Cycle 6 will document in the CI workflow's pre-flight checks. Cold cargo build was **4m 39s**; warm rebuilds will be seconds via the cache mount IDs (which survive `docker compose build` cycles but not `docker builder prune -a`). The host-target bind-mount strategy is **described as a future optimisation** in the Dockerfile inline comment but **not wired into the default RUN** — it requires `docker buildx build --build-context fraiseql-target=$HOME/code/fraiseql/target …` which is incompatible with `docker compose build`'s current invocation surface. Cycle 5's smoke script can opt in by building outside compose first; Cycle 6's CI workflow will rely on the cache mount.
- **Worktree note:** the user's `~/code/fraiseql` working tree was dirty during Cycle 2 (an in-progress `feat/deps-sha1-hmac-joint-bump` branch that does not compile at HEAD). I worked around this by adding a git worktree at `/tmp/fraiseql-frozen` pinned to the frozen SHA, building from there, and removing the worktree after capture (`git worktree remove /tmp/fraiseql-frozen`). CI (Cycle 6) will start from a clean clone at exactly `FRAISEQL_SHA`, so this is not an upstream concern; documented here for the next persona's situational awareness.
- **Anti-scope held to:** no MinIO/Azurite/fake-gcs (Cycle 3 still has its TODO block), no `docs-test.sh` (Cycle 4), no `_smoke.docs-test.sh` or page test scripts (Cycle 5), no `.github/workflows/docs-test.yml` (Cycle 6), no fixtures or init schemas under `fixtures/*` (still empty per Cycle 1), no edits under `src/content/docs/`, no `Makefile`, no `FRAISEQL_SHA` file (Cycle 9 owns that — Cycle 2 ARG defaults are inline).
- **Framework issues filed:** 0. Server logged three "expected" defence-in-depth warnings on boot (`subscription_require_auth is true but no OIDC configured — subscriptions disabled`, `design_api_require_auth is true but no OIDC configured — design API endpoints are DISABLED`, `RBAC Management API disabled — admin_token is not set`). These match the framework's intentional security-by-default posture and are documented surface in `server_config/mod.rs`. The docs-test baseline accepts them; per-page overlays (Cycle 5+) enable individual surfaces as needed.
- **Known issues for Cycle 3+ to be aware of:**
  - On low-memory developer hosts (this one has ~600 simultaneous containers historically), MSSQL has shown occasional cold-boot flakiness when the stack is brought up with stale volumes from an aborted previous run. The Cycle-1 fix path (`down -v` between runs) resolves it. Documented for Cycle 5's smoke script: always pair `down -v` with `up --wait` to avoid stale-volume MSSQL crashes.
  - The image's healthcheck depends on `curl` being present in the runtime stage. Cycle 3's storage sidecars may want to use the same healthcheck pattern; their Dockerfiles will need to install curl too (or use the framework's `/health` via `docker exec fraiseql curl ...` if they sit behind it).
  - Docker daemon 29.5.1 + containerd snapshotter consumes ~172 MB disk usage for this image (per `docker image ls` "DISK USAGE" column) despite a 44.9 MB content size — the inflation is the OCI attestation manifest BuildKit generates. CI image-pull bandwidth is bounded by the 44.5 MB compressed save, not the disk usage figure.
- **Push posture:** branch `phase-00/foundation` will gain one Cycle 2 commit on top of `043034d` (Cycle 1 finishing). Not pushed (no CI yet; the phase doc says "CI is the only GREEN gate" activates Cycle 6 onward). Cycle 3 author can push if convenient.
- **Open gates:** none new. The G2 SHA-bump policy continues to hold to `d0a4ed4ec1770c70707f68fd9019f2b561d87461`.

---
