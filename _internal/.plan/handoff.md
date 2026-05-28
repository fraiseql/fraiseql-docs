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
