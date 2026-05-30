# Phase 04: New feature docs (part 1) — Studio, Functions, Realtime

> **PAUSED 2026-05-30 at Phase 03 close.** This phase is blocked on the framework team shipping the 54-issue roadmap (29 FW-bug fixes #326-#361 + 25 enhancements #366-#391). See `_internal/.plan/framework-roadmap-mapping.md` for the per-phase dependency table + the new pages this phase will absorb when the framework state settles. Resume entry condition: the framework SHA bump (G2) completes + the per-phase dependencies in the mapping doc are shipped.


## Objective

Document three flagship v2.3 subsystems that have **zero** current coverage: the Studio admin dashboard, the `fraiseql-functions` WASM trigger system, and the Realtime subsystem internals (beyond the existing subscriptions protocol page).

## Why this exists

These are the headline features of v2.3.0. A potential adopter scanning the docs site today would not learn that any of them exist. Each is large enough that a single phase per subsystem would be cleaner, but they cluster well: they're all "operator-visible new surfaces shipped in v2.3.0," and they touch different subsystems so writers can work in parallel without conflict.

## Success criteria

- [ ] Studio admin dashboard documented: layout, endpoints, auth model, metrics surface, data browser, all admin API mounts.
- [ ] Functions (WASM) documented: trigger types, lifecycle, hosting model, secrets, sandbox semantics, security model, configuration, worked examples.
- [ ] Realtime subsystem documented end-to-end: WebSocket subscription protocol with RLS, broadcast observer, CronScheduler, presence manager, broadcast REST publish, CDC ObserverRuntime + EventBridge integration, tenant-aware CDC filtering.
- [ ] Each page passes the 12-point adversarial review.
- [ ] Each page has a passing `*.docs-test.sh` (containers, real wire calls, real WASM execution).
- [ ] Studio page has at least three screenshots (auth, data browser, metrics).
- [ ] Realtime page distinguishes "subscriptions" (the protocol — existing page) from "realtime subsystem" (this page — internals + ops).

## Scope (in)

- New page: `src/content/docs/features/studio.md` (or under a new `studio/` group if phase 01 IA picked one).
- New page: `src/content/docs/features/functions.md`.
- New subpage: `src/content/docs/features/functions/triggers.md` (trigger types deep dive).
- New subpage: `src/content/docs/features/functions/secrets.md` (function secrets API).
- New subpage: `src/content/docs/features/functions/sandbox.md` (security model).
- New page: `src/content/docs/features/realtime.md` (subsystem overview).
- New subpage: `src/content/docs/features/realtime/broadcast.md` (broadcast channels + REST publish).
- New subpage: `src/content/docs/features/realtime/presence.md` (presence manager).
- New subpage: `src/content/docs/features/realtime/cdc.md` (CDC ObserverRuntime + EventBridge).
- New subpage: `src/content/docs/features/realtime/cron.md` (CronScheduler).

## Scope (out)

- The existing `features/subscriptions.md` page — touched only to cross-link, not rewritten.
- Auth Extensions — phase 05.
- Federation realtime passthrough — phase 06 (federation page touches it briefly).

## Dependencies

- **Requires:** Phase 03 complete (observers and authentication pages, which Functions and Realtime cross-link).
- **Blocks:** None within this overhaul; phase 08's sweep depends on these pages existing.

## Personas involved

Phase 04 documents three subsystems with **zero** current docs. Hallucination risk is at its highest because Claude has no prior to anchor against — source-grep discipline must be ironclad.

| Cycle | Personas |
|-------|----------|
| 1–3 (Studio) | Writer (Opus 4.7) → Bug-Finder (Opus 4.7, try unauth'd admin endpoints, click every UI button) → Writer → Reviewer + Verifier → Cleanup |
| 4–7 (Functions) | Writer → Bug-Finder (sandbox escape, secret exfiltration, forbidden syscalls) → Writer → Reviewer + Verifier → Cleanup |
| 8–11 (Realtime) | Writer → Bug-Finder (cross-tenant subscription leak, broadcast injection, presence eviction races) → Writer → Reviewer + Verifier → Cleanup |
| 12 (style audit) | Style Auditor → Cleanup |

The Bug-Finder persona is especially valuable here. The Studio admin endpoints, Functions sandbox, and Realtime tenant filtering are exactly the kind of surfaces that look correct in a happy-path test but have subtle holes under adversarial input. Budget Bug-Finder time generously.

## TDD cycles

### Cycle 1: Studio dashboard overview

- **RED:** boot FraiseQL in a container; visit `http://localhost:8080/studio`. Capture the actual SPA's structure (auth dialog, page list, navigation).
- **GREEN:** `features/studio.md` covers:
  - What Studio is: embedded SPA at `/studio`, ships with `fraiseql-server`.
  - Auth model: same JWT/cookie auth as the GraphQL API; admin scope required.
  - Pages: data browser, schema explorer, auth admin, storage admin, realtime monitor, functions registry, metrics dashboard.
  - Endpoints under `/admin/v1/*` that Studio relies on.
  - Disabling Studio in production (Cargo feature / TOML toggle).
  - Build-time embedding semantics (`build.rs` stages to `$OUT_DIR` — v2.3.2 fix, in passing).
- **REFACTOR:** lead with a screenshot of the dashboard at first login.
- **CLEANUP:** `studio.docs-test.sh`:
  - Boot FraiseQL with `[server.admin].enabled = true`.
  - `curl -fsS http://localhost:8080/studio/` — must return HTML (not 404).
  - For each admin endpoint listed (`/admin/v1/metrics/summary`, `/admin/v1/usage`, `/admin/v1/query-stats`, `/admin/v1/federation/plan`, etc.), assert HTTP 200 with a valid bearer token, and 401/403 without.
  - With Studio disabled by config, `/studio/` returns 404 — verify.

### Cycle 2: Studio data browser deep dive

- **RED:** boot Studio against a fixture schema with three types and one mutation. Open the data browser. Capture what's actually rendered.
- **GREEN:** subsection of `studio.md` or a `studio/data-browser.md` page covering:
  - Listing types.
  - Filtering rows.
  - Detail view.
  - RBAC: which fields appear vs. which require admin scope.
- **REFACTOR:** screenshots tightly cropped to the relevant UI.
- **CLEANUP:** the test asserts the API endpoints the browser calls return the documented shape.

### Cycle 3: Studio metrics, query-stats, usage

- **RED:** `GET /admin/v1/metrics/summary` — capture its actual JSON. Compare against the v2.3.0 release-notes claim ("real-time latency percentiles and cache hit rate").
- **GREEN:** document each admin endpoint:
  - `/admin/v1/metrics/summary` — fields, refresh semantics.
  - `/admin/v1/usage?tenant_id=…&period=…` — per-tenant aggregation.
  - `/admin/v1/query-stats`, `/admin/v1/query-stats/{queryid}`, `POST .../reset` — backed by `pg_stat_statements` / `performance_schema` / `sys.dm_exec_query_stats`.
  - `/admin/v1/federation/plan?query=…` — plan visualisation (forward-link to phase 06).
- **REFACTOR:** add an "Endpoint reference" table at the bottom.
- **CLEANUP:** every endpoint is hit by the test; shape matches doc.

### Cycle 4: Functions — overview + lifecycle

- **RED:** there is no Functions page today. Without it, an adopter cannot use the WASM trigger subsystem at all.
- **GREEN:** `features/functions.md`:
  - What Functions are: WASM modules registered against trigger types.
  - Trigger types: `after:mutation`, `before:mutation`, `after:storage`, `cron`, `http`.
  - Hosting model: WASI sandbox; `SqlExecutor` injected; cold-start cache.
  - Configuration in TOML.
  - Function registry CRUD via admin API.
  - Pointer to triggers / secrets / sandbox subpages.
- **REFACTOR:** decision matrix: "Use Functions for X; don't use them for Y." (Y = anything in the hot request path; Y = anything that needs raw network access without allowlisting.)
- **CLEANUP:** `functions.docs-test.sh`:
  - Compile a trivial WASM module (`cargo build --target wasm32-wasi` of a tiny example).
  - Register it via admin API.
  - Trigger via mutation; verify the function ran (side-effect = a row inserted in `tb_function_audit`).
  - Disable the function; verify it does not run.

### Cycle 5: Functions — triggers deep dive

- **RED:** each trigger type behaves differently. A single overview page can't cover them all without becoming a wall of text.
- **GREEN:** `features/functions/triggers.md`:
  - `before:mutation` — can reject the mutation (return error); mutation rolls back.
  - `after:mutation` — runs after commit; failure does not roll back.
  - `after:storage` — runs after a storage write; useful for thumbnail generation.
  - `cron` — scheduled, no input; uses `CronScheduler`.
  - `http` — exposed as an HTTP endpoint mounted by the server.
- **REFACTOR:** per-trigger worked example.
- **CLEANUP:** test exercises all five trigger types end-to-end.

### Cycle 6: Functions — secrets API

- **RED:** without secrets management, functions cannot call external APIs safely.
- **GREEN:** `features/functions/secrets.md`:
  - AES-256-GCM at rest.
  - Storage backends: env, postgres, Vault.
  - Function-scoped access (a function declares which secret names it needs).
  - Rotation procedure.
- **REFACTOR:** worked example: a webhook-calling function fetches a secret to sign the request.
- **CLEANUP:** test stores a secret, runs the function, asserts the outbound HTTP carried the signed header.

### Cycle 7: Functions — sandbox + security model

- **RED:** WASM is sandboxed but the surface is not obvious. Adopters need to know what their functions can and cannot do.
- **GREEN:** `features/functions/sandbox.md`:
  - WASI capabilities granted (filesystem? no — by default; network? allowlisted only).
  - HTTP allowlist (default-deny; explicit hosts).
  - Concurrency limiter.
  - Module cache (cold-start optimization).
  - Memory + CPU limits.
- **REFACTOR:** security checklist for production.
- **CLEANUP:** test attempts forbidden operations from inside a function and verifies they fail closed.

### Cycle 8: Realtime — subsystem overview

- **RED:** the existing `subscriptions.md` covers the protocol (`graphql-ws`) but says nothing about how the subsystem actually works internally or what other realtime surfaces FraiseQL exposes.
- **GREEN:** `features/realtime.md`:
  - Components: WebSocket subscription server, broadcast observer, presence manager, CronScheduler, CDC ObserverRuntime, EventBridge.
  - RLS in subscriptions: subscriptions inherit the subscriber's security context; events filtered server-side per tenant.
  - Tenant-aware CDC filtering (via `fk_customer_org`).
- **REFACTOR:** architecture diagram (D2) showing event flow from DB write → CDC → ObserverRuntime → EventBridge → subscription fan-out.
- **CLEANUP:** `realtime.docs-test.sh`:
  - Two tenants connect via WebSocket subscriptions.
  - Tenant A mutates a row.
  - Tenant A's subscription receives the event.
  - Tenant B's subscription does not.

### Cycle 9: Realtime — broadcast channels + REST publish

- **RED:** the broadcast channel + REST publish endpoint is undocumented. Test reveals it exists and works.
- **GREEN:** `features/realtime/broadcast.md`:
  - Broadcast channels (named topics).
  - Subscription via WebSocket.
  - Publish via REST (`POST /broadcast/{channel}`).
  - Auth model on both ends.
- **REFACTOR:** worked example: chat room.
- **CLEANUP:** test verifies fan-out and tenant isolation on broadcast.

### Cycle 10: Realtime — presence manager

- **RED:** presence (room tracking + heartbeat eviction) is a discrete feature.
- **GREEN:** `features/realtime/presence.md`:
  - Joining a room.
  - Heartbeat semantics.
  - Eviction on missed heartbeat.
  - Querying presence.
- **REFACTOR:** decision: client-driven heartbeat vs. server-driven (server-driven is the v2.3 model — confirm by reading source).
- **CLEANUP:** test simulates two clients joining; one drops; eviction triggers; presence query reflects it.

### Cycle 11: Realtime — CDC / EventBridge / cron

- **RED:** the CDC ObserverRuntime wired into `EventBridge` is the substrate that makes subscriptions work without the application explicitly publishing events. Adopters need a mental model.
- **GREEN:** `features/realtime/cdc.md` + `features/realtime/cron.md`:
  - CDC: how the runtime listens for row changes (PostgreSQL LISTEN/NOTIFY by default; MySQL binlog where applicable).
  - EventBridge: the bus that fans events to subscribers / observers / functions.
  - CronScheduler: periodic task scheduling; one-shot vs. recurring.
- **REFACTOR:** the CDC page links to the observers page (phase 03) for handler ergonomics.
- **CLEANUP:** test triggers a row update; CDC propagates; both a subscription and an observer receive it.

### Cycle 12: Phase-close style audit

Persona: Style Auditor → Cleanup.

- **RED:** ~10 new pages across three subsystems, written across many Writer invocations. Terminology consistency is especially at risk: "function" vs. "WASM module" vs. "trigger handler" all refer to overlapping concepts; "subscription" vs. "broadcast channel" vs. "observer dispatch" describe different but related event flows.
- **GREEN:** Style Auditor produces `_internal/.plan/style-audits/phase-04.md`. Cross-page terminology table required. Page-template uniformity: every page in the Studio / Functions / Realtime groups has the same section order.
- **CLEANUP:** Cleanup applies. Handoff updated.

## Adversarial review protocol

Each subsystem gets its own reviewer:

1. Reviewer treats the page as "I have never used this feature." Follows the page from cold start.
2. Reviewer breaks one assumption per page: wrong auth header on the admin API; WASM module with a forbidden syscall; subscription to another tenant's data.
3. For Studio: reviewer clicks every UI element shown in screenshots; the documented behaviour is what happens.
4. For Functions: reviewer reads the sandbox page, then attempts to write a function that exfiltrates data via DNS. Page must call this out as forbidden and the runtime must actually forbid it.
5. For Realtime: reviewer kills the database mid-subscription; documented reconnection behaviour matches reality.

## Container verification matrix

| Page | PG | MySQL | SQLite | MSSQL | Other |
|------|----|----|----|----|-----|
| studio | ✅ | ✅ | ✅ | ✅ | (chromium for screenshots; not in CI by default) |
| functions | ✅ | ✅ | ✅ | ✅ | Vault (for secrets); WASM toolchain |
| functions/triggers | ✅ | ✅ | ⚠️ | ✅ | NATS (if `after:mutation` fans out) |
| functions/secrets | ✅ | n/a | n/a | n/a | Vault |
| functions/sandbox | ✅ | n/a | n/a | n/a | WASM toolchain |
| realtime | ✅ | ⚠️ | n/a | ⚠️ | NATS, Redis |
| realtime/broadcast | ✅ | n/a | n/a | n/a | (none additional) |
| realtime/presence | ✅ | n/a | n/a | n/a | (none additional) |
| realtime/cdc | ✅ | ⚠️ binlog requires MySQL config | n/a | ⚠️ | NATS |
| realtime/cron | ✅ | ✅ | ✅ | ✅ | (none additional) |

## Risks specific to this phase

| Risk | Mitigation |
|------|------------|
| WASM toolchain is not part of phase 00's harness | Add WASM build sidecar in this phase; install `wasm32-wasi` target in the FraiseQL image |
| Studio SPA is opaque without screenshots; screenshots rot fast | Limit screenshots to three high-value ones; rely on text + endpoint reference for the rest |
| Realtime CDC needs PG `LISTEN/NOTIFY` configured; not all DB configurations have it | The fixtures in phase 00 enable it; document the prerequisite up top |
| Presence subsystem may have race conditions only visible under load | The test exercises happy path; load testing is out of scope and noted explicitly |
| Functions sandbox claims are difficult to verify exhaustively | We document declared guarantees; bugs surfaced during attempts file issues against the framework |

## Estimated effort

**Effort proxy: 2.** Highest hallucination risk in the overhaul because Claude has no prior on these subsystems. Writer-Opus is the dominant cost. Bug-Finder-Opus is also expensive here (substantial breakage attempts across three subsystems). Source-Citation Verifier-Sonnet load is high (many new symbols to verify). Studio + Functions + Realtime cycles can run concurrently via subagent fan-out — they touch disjoint files. Style Auditor at close, likely with cross-subsystem terminology table.

## Status

- [ ] Not started
- [ ] RED in progress
- [ ] GREEN in progress
- [ ] REFACTOR in progress
- [ ] CLEANUP in progress
- [ ] Complete

## Owner

*(unclaimed)*

## Pages completed

*(append slugs as cycles close)*

## Framework bugs filed

*(realtime tenant filtering, Functions sandbox escape attempts, Studio admin endpoints behaviour edge cases — likely several per subsystem)*
