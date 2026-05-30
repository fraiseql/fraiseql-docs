# Cycle 7 cluster inventory + partition plan

**Phase:** 03 / Cycle 7
**Persona:** Writer (Opus 4.7) — RED only
**Date:** 2026-05-30
**Branch:** `phase-03/critical-rewrites` @ `b54bd9d` (Cycle 6 close)
**Frozen FraiseQL SHA:** `d0a4ed4ec1770c70707f68fd9019f2b561d87461`

This document is internal. It does not ship. It triages the ~22 sweep-matrix rows that constitute Cycle 7 (auth/security cluster + concepts pass + comparisons), classifies each as REWRITE / POLISH / DEFER, and proposes a 3-sub-cycle partition (7a / 7b / 7c) the orchestrator can drive efficiently. Writer-GREEN follows this plan; this Writer-RED does not edit any docs page.

## Triage buckets

- **REWRITE** — page describes a different product than v2.3.2 ships, or directly contradicts a Cycle 1-4 page that just shipped. Substantive scope similar to Cycles 1-4 (security caveats LEAD, framework citations, docs-test companion where applicable).
- **POLISH** — page is broadly correct at v2.3.2 but has specific staleness (stale cross-link slugs, one or two wrong field names, missing FW-N caveat box, version anchors). Smaller scope; no full rewrite; no Bug-Finder; no fresh docs-test.
- **DEFER** — page is fine at v2.3.2 at the substantive level; move owning phase to Phase 08 (final polish sweep). No Cycle 7 GREEN edit.

---

## Auth/security cluster (7 pages)

### `/features/security` (`src/content/docs/features/security.mdx`, 613 lines)

- **Bucket:** REWRITE.
- **Reason:** This is the security cluster's hub page; it currently overlaps heavily with the just-shipped `/building/authentication` (Cycle 4) AND with the surrounding cluster pages (encryption / oauth-providers / audit-logging / rate-limiting / server-side-injection). After Cycle 4, the hub-vs-detail boundary needs to be decided. The page also mixes correct surfaces (`[security.error_sanitization]`, `[security.rate_limiting]`, `[security.state_encryption]`, `[security.pkce]`) with incorrect cross-links (`/guides/multi-tenancy`, `/guides/authentication` — both moved under Option A IA) and lacks the FW-24/25/26/27/28/29 security-caveats LEAD that `/building/authentication` carries. A reader hitting `/features/security` first sees an "all-clear" tone before discovering the open framework issues from the auth page.
- **Stale-shape examples:**
  - L227: `See [Multi-Tenancy](/guides/multi-tenancy) for the full guide…` — slug moved to `/building/multi-tenancy` per Phase 01 IA.
  - L331: `See [Authentication](/guides/authentication#api-key-authentication) for the database schema and key issuance mutations.` — slug moved to `/building/authentication`.
  - L355: `See [Authentication](/guides/authentication) for the full revocation workflow.` — same.
  - L611: `[Multi-Tenancy](/guides/multi-tenancy)` cross-link card — same.
  - L233-L247 `## Error Sanitization` says "**disabled by default**" — correct, but no FW-N caveat box anywhere on the page despite 6 open framework issues against this cluster.
  - L161-L175 RBAC `admin_token` caveat — correct in shape, but the FW-3 #330 fact (off-the-shelf binary doesn't wire `TenantExecutorRegistry`) is not surfaced here and is highly relevant to the RBAC story.
- **Cycle 1-4 cross-link impact:** YES — links to `/guides/multi-tenancy` (×2) and `/guides/authentication` (×3), all stale per Phase 01 IA Option A. Plus deep-anchor `/guides/authentication#api-key-authentication` which assumed an old page structure that no longer applies to the rewritten `/building/authentication`.

### `/features/encryption` (`src/content/docs/features/encryption.mdx`, 325 lines)

- **Bucket:** POLISH.
- **Reason:** Page describes `fraiseql-secrets` Rust crate + AES-256-GCM + Vault / env / file backends. The frozen SHA has `crates/fraiseql-secrets/` and the surface matches. The "configured in the compiled schema, not the Python decorator" note is correct (matches the compile-step indirection captured in `/building/authentication` caveat 8). Main issues: stale cross-link to `/guides/deployment` (L324), and one cross-link to `/features/security` that will need re-validation after the hub rewrite.
- **Stale-shape examples:**
  - L324: `[Deployment](/guides/deployment) — Production key management` — slug moved to `/operations/deployment` per Phase 01 IA.
  - Otherwise the page is internally consistent and aligned with v2.3.2 architecture.
- **Cycle 1-4 cross-link impact:** one stale `/guides/deployment` slug. No claim that contradicts the Cycle 1-4 rewrites.

### `/features/oauth-providers` (`src/content/docs/features/oauth-providers.mdx`, 335 lines)

- **Bucket:** REWRITE.
- **Reason:** Directly contradicts `/building/authentication`. L26-28 contains the cautionary aside: **"FraiseQL does not have an `[auth]` TOML section — it causes a hard parse error."** This is provably wrong at the frozen SHA: `crates/fraiseql-server/src/server_config/hs256.rs` line 14 documents `[auth_hs256]` as *mutually exclusive with* `[auth]` (OIDC), and `/building/authentication` makes `[auth]` the primary auto-wired OIDC path with `audience` required and `audience` validation refusing to boot when omitted (caveat 9 of the Cycle 4 page). The page also pushes ALL provider config to `OIDC_*` environment variables, which is the *old* configuration shape — at v2.3.2 OIDC issuer/audience/algorithms etc. all live in `[auth]` TOML. The "Endpoints" table (`/auth/login`, `/auth/userinfo`) does not match the actual server routes (`/auth/start`, `/auth/callback`, `/auth/me`) documented in `/building/authentication`.
- **Stale-shape examples:**
  - L26-28: claims `[auth]` causes a hard parse error — wrong at frozen SHA; `[auth]` is the primary OIDC config surface.
  - L31-37: all provider config via `OIDC_DISCOVERY_URL` / `OIDC_CLIENT_ID` / `OIDC_CLIENT_SECRET` env vars only. At v2.3.2 these live in `[auth]` TOML, with secrets via env-var substitution (`client_secret = "${OIDC_CLIENT_SECRET}"`).
  - L131-137: endpoints table lists `/auth/login`, `/auth/userinfo`, `/auth/refresh`, `/auth/logout` — does not match `/auth/start`, `/auth/callback`, `/auth/me` documented in `/building/authentication` and confirmed in `crates/fraiseql-server/src/server/routing/auth.rs`.
  - L151+: heavy Python decorator examples with `inject={"user_id": "jwt:sub"}` — these are *correct* per the converter tests at frozen SHA; this part of the page is fine and reusable.
  - L201: `@fraiseql.type(requires_role="admin")` — `requires_role` is a real surface (confirmed in `crates/fraiseql-cli/src/codegen/tests.rs`).
- **Cycle 1-4 cross-link impact:** directly contradicts Cycle 4's `/building/authentication`. A reader hitting `/features/oauth-providers` first will believe `[auth]` is a parse error; hitting `/building/authentication` after will see `[auth]` as required. The contradiction must be resolved in Writer-GREEN.

### `/features/audit-logging` (`src/content/docs/features/audit-logging.mdx`, 444 lines)

- **Bucket:** POLISH.
- **Reason:** The `[security.enterprise].audit_logging_enabled` + `audit_log_backend` surface is correct at frozen SHA (`crates/fraiseql-cli/src/config/toml_schema/security.rs:L120-L122`). The Cargo feature flags `audit-syslog` / `audit-webhook` are real (`crates/fraiseql-core/Cargo.toml:L125-L127`). The page has correct multi-DB DDL tabs. Main issues: "Schema (**auto-created**)" caption at L33 is misleading — operators create the audit table; FraiseQL does not auto-create it. Also the Python decorator `@fraiseql.query` example at L298-310 needs a slug-fix re: cross-links.
- **Stale-shape examples:**
  - L33: "**Schema (auto-created):**" caption — operators write the DDL themselves; the framework does not run migrations against the user's database.
  - L164: GH link to `production-security-checklist.md` is already pinned to the frozen SHA (per Phase 01 / Cycle 4 audit). OK.
- **Cycle 1-4 cross-link impact:** none observed; page does not link into the four critical-rewrite pages.

### `/features/rate-limiting` (`src/content/docs/features/rate-limiting.mdx`, 348 lines)

- **Bucket:** POLISH.
- **Reason:** The `[security.rate_limiting]` shape is correct (`requests_per_second`, `burst_size`, `trust_proxy_headers`, Redis backend with `redis-rate-limiting` Cargo feature). The page already mentions auth endpoint per-route limits and `trust_proxy_headers` correctly. **CRITICAL FW-24 GAP:** lines L65-L70 and L147-L148 document `failed_login_max_requests` / `failed_login_window_secs` — but the actual field names per the CLI schema are `failed_login_max_attempts` / `failed_login_lockout_secs`, AND those fields are SILENTLY DROPPED by the server runtime (FW-24 [#356] open). The page is technically wrong on field names AND fails to warn readers that brute-force protection is a no-op at v2.3.2. This needs a FW-24 caveat box and a field-name correction. Also stale `/guides/authentication` link at L340.
- **Stale-shape examples:**
  - L65-L70: `failed_login_max_requests = 5` and `failed_login_window_secs = 3600` — wrong field names per the CLI TOML schema (`failed_login_max_attempts`, `failed_login_lockout_secs`) AND fields silently dropped by server runtime per FW-24 #356.
  - L147-L148: Default Values table repeats the wrong names.
  - L340: `[Authentication](/guides/authentication)` — slug moved to `/building/authentication`.
- **Cycle 1-4 cross-link impact:** one stale `/guides/authentication` slug. The page also has DIRECT MISALIGNMENT with `/building/authentication` caveat 6 (FW-24) and needs a matching caveat box.

### `/features/server-side-injection` (`src/content/docs/features/server-side-injection.mdx`, 151 lines)

- **Bucket:** POLISH.
- **Reason:** Page describes `inject={"key": "jwt:claim"}` on `@fraiseql.query` / `@fraiseql.mutation`. This is correct at frozen SHA (`crates/fraiseql-cli/src/schema/converter/queries.rs:L31`, `crates/fraiseql-cli/tests/converter_inject_params_test.rs`). The caution about "Inject params must be last in the SQL function signature" is correct. The "Supported sources" table is accurate. Minor issues: stale `/guides/multi-tenancy` cross-link at L147 (slug now `/building/multi-tenancy`), and the page's claim at L132 that `inject` "is not supported on SQLite connections" needs source verification (may be correct — SQLite path doesn't have JWT injection in same way per multi-tenancy page caveats).
- **Stale-shape examples:**
  - L147: `[Multi-Tenancy](/guides/multi-tenancy)` — slug moved.
  - L132: SQLite caveat — needs spot-verification against `crates/fraiseql-server/src/runtime/executor` or wherever inject_jwt routing lives.
- **Cycle 1-4 cross-link impact:** one stale `/guides/multi-tenancy` slug.

### `/features/mutations` (`src/content/docs/features/mutations.mdx`, 575 lines) — was `/concepts/mutations`, moved per Option A

- **Bucket:** POLISH.
- **Reason:** The page describes `@fraiseql.mutation(sql_source="fn_*", operation="CREATE"|"UPDATE"|"DELETE")` returning `mutation_response`. This is correct at frozen SHA (verified via converter tests). The Mermaid mutation flow diagram is current. Multi-language tabs (Python / TypeScript) exist. Main issues: (1) the page overlaps with `/getting-started/adding-mutations` and the matrix flagged this overlap; needs a clear scope-statement at top OR a consolidation; (2) authentication section (L286-) is the page's weakest part — it references `requires_role` and `requires_scope` correctly but the JWT validation explanation says "configured at the server level via environment variables (`JWT_SECRET`, `JWT_ALGORITHM`)" which is the OLD env-var shape; v2.3.2 uses `[auth]` / `[auth_hs256]` TOML per the Cycle 4 rewrite.
- **Stale-shape examples:**
  - L288: "Authentication token validation is configured at the server level via environment variables (`JWT_SECRET`, `JWT_ALGORITHM`)" — at v2.3.2 this lives in `[auth]` / `[auth_hs256]` TOML; the JWT_SECRET env var is the *legacy* config path only.
  - Overlap-with-`getting-started/adding-mutations`: matrix flagged this; needs a scope line at top of either page disambiguating "intro" vs "reference".
- **Cycle 1-4 cross-link impact:** auth section directly contradicts `/building/authentication`'s `[auth]` / `[auth_hs256]` LEAD framing. Needs a 2-line patch + cross-link to the auth page.

---

## Concepts pass (9 pages)

### `/concepts/why-fraiseql` (`why-fraiseql.mdx`, 218 lines)

- **Bucket:** POLISH.
- **Reason:** Architectural narrative. Doesn't reference specific framework surfaces in a way that ages out at every release. Correct in framing: N+1 problem, DataLoader limits, single-query promise, CQRS. Main issue: stale cross-link to `/guides/performance-benchmarks` at L216 (slug moved to `/operations/performance-benchmarks` per Phase 01 IA).
- **Stale-shape examples:** L216 `/guides/performance-benchmarks` — slug-fix only.
- **Cycle 1-4 cross-link impact:** none direct.

### `/concepts/how-it-works` (`how-it-works.mdx`, 455 lines)

- **Bucket:** POLISH (or DEFER).
- **Reason:** Already audited in Phase 01 / Cycle 3 for cross-links (`/concepts/why-fraiseql` inbound link wired). The "Phase 1/2/3" compilation phrasing at L321/331/342 is pre-existing framework wording (Cycle 3 Reviewer cleared as not docs-overhaul archaeology). The `demo.fraiseql.dev` reference (Cycle 4 deferral C) was meant to land here in Cycle 6 G8c but G8c was rolled into "accept" — the page may still contain the live-demo link to verify.
- **Stale-shape examples:**
  - Need to re-grep for `demo.fraiseql.dev` references — if any remain, they break per INFRA-1 (TLS SAN mismatch).
- **Cycle 1-4 cross-link impact:** none direct.

### `/concepts/cqrs` (`cqrs.mdx`, 1086 lines)

- **Bucket:** POLISH.
- **Reason:** Longest concept page. Architectural deep-dive into CQRS at the DB level. The framing (tb_* + v_* + fn_*) matches v2.3.2 reality exactly. Verified by spot-reading: correct on `mutation_response`, correct on view-on-table separation. Main issue: stale cross-link `/concepts/mutations` at L1085 — slug moved to `/features/mutations` per Phase 01 IA Option A.
- **Stale-shape examples:** L1085 `/concepts/mutations` — slug-fix.
- **Cycle 1-4 cross-link impact:** one stale slug only.

### `/concepts/developer-owned-sql` (`developer-owned-sql.mdx`, 632 lines)

- **Bucket:** POLISH (or DEFER — borderline).
- **Reason:** Argues for hand-written views over abstraction-driven SQL generation. Architectural in tone; no specific framework surface citations to age out. Multi-DB tabs in code blocks. Main risks: stale cross-links to `/guides/*` slugs.
- **Stale-shape examples:**
  - Quick re-grep needed for `/guides/` slugs.
- **Cycle 1-4 cross-link impact:** none direct.

### `/concepts/view-composition` (`view-composition.mdx`, 933 lines)

- **Bucket:** POLISH.
- **Reason:** The `.data` JSONB column pattern and child-view embedding are correct at v2.3.2. The `rv_*` row-shape views for gRPC are mentioned correctly (cross-link to `/features/grpc-transport`). Stale cross-link L933: `/concepts/mutations` — slug moved per Option A. Stale cross-link L934: `/guides/schema-design` — slug moved to `/building/schema-design`.
- **Stale-shape examples:**
  - L933: `/concepts/mutations` slug.
  - L934: `/guides/schema-design` slug.
- **Cycle 1-4 cross-link impact:** none direct (no link into the 4 critical-rewrite pages).

### `/concepts/type-system` (`type-system.mdx`, 538 lines)

- **Bucket:** POLISH.
- **Reason:** Type-mapping tables (Python ↔ GraphQL ↔ PostgreSQL ↔ JSON, plus cross-DB matrix). The mappings match the framework's scalar definitions at frozen SHA. Stale cross-link L533: `/guides/schema-design` — slug moved.
- **Stale-shape examples:** L533 slug.
- **Cycle 1-4 cross-link impact:** none direct.

### `/concepts/schema` (`schema.mdx`, 651 lines)

- **Bucket:** POLISH.
- **Reason:** Documents Python decorator authoring (`@fraiseql.type`, `@fraiseql.query`, `@fraiseql.input`, custom scalars). The shapes are correct at frozen SHA. The `fraiseql.config(sql_source="v_user")` body-call pattern matches the SDK convention. SpecQL Aside at L221-223 — needs slug-verification, may link to a page that no longer exists or was renamed.
- **Stale-shape examples:**
  - L221-223: SpecQL Aside — needs to verify `/reference/decorators` or wherever the SDK info lives. Per the Phase 01 Cycle 1+4 audit, "fraiseql/specql" hyperlinks were already swapped to plain text on `/reference/decorators` and `/reference/authoring-ir`. This page may carry one more such reference.
- **Cycle 1-4 cross-link impact:** none direct.

### `/concepts/configuration` (`configuration.mdx`, 322 lines)

- **Bucket:** REWRITE.
- **Reason:** Page contains a top-of-page caution Aside (L8-10) listing `[auth]`, `[compilation]`, `[rate_limit]` as causing "hard 'unknown field' error at `fraiseql compile`." This directly contradicts the just-shipped `/building/authentication`, which makes `[auth]` (OIDC) the primary auto-wired path with `audience` required (the framework's `OidcConfig::validate()` refuses to boot without `audience`). Page also says at L129: "There are no `[auth]`, `[logging]`, `[graphql]`, or `[metrics]` sections." — wrong at v2.3.2. The page intends to be authoritative for the TOML config shape and is wrong on the most security-critical section.
- **Stale-shape examples:**
  - L8-10: top-of-page Aside contradicts v2.3.2; `[auth]` is the OIDC section and is required for OIDC deployments.
  - L129: explicit denial of `[auth]` section.
  - L276: stale `/guides/multi-tenancy` cross-link.
  - Multi-transport Aside L134-148 mentions `[rest]` / `[grpc]` "Available since v2.1" — correct shape but version anchor is HISTORICAL (keep per Phase 01 audit guideline).
- **Cycle 1-4 cross-link impact:** directly contradicts `/building/authentication`. Plus stale `/guides/multi-tenancy` slug.

### `/concepts/elo-validation` (`elo-validation.mdx`, 512 lines)

- **Bucket:** DEFER.
- **Reason:** Phase 00 addition. Sweep matrix flagged "OK / Phase 08 polish". The brief pulled it into Cycle 7 ("concepts pass") but the actual page content describes Elo expression language (real surface: `crates/fraiseql-core/src/validation/compile_time.rs` references Elo at frozen SHA). The page has correct shape, correct examples, no contradiction with Cycle 1-4 rewrites. Only potential issue: stale cross-link `/guides/custom-scalars` at L495 — but that's the same one-line slug-fix as every other concept page. **Recommendation: include in 7b POLISH batch as a single slug-fix line, OR formally defer to Phase 08.** Inclusion in 7b costs ~30 seconds of Writer time and avoids a defer-claim debate.
- **Stale-shape examples:** L495 stale `/guides/custom-scalars` slug.
- **Cycle 1-4 cross-link impact:** none.

---

## /community/vs/* (5 pages)

### `/community/vs/hasura` (`hasura.mdx`, 693 lines)

- **Bucket:** POLISH.
- **Reason:** Comparison page; framing is current. Tables compare FraiseQL v2.3.2 surfaces (compiled Rust, observers, REST + gRPC, OpenAPI auto-gen, multi-DB) against Hasura — these claims match the framework reality. Pricing disclaimer is dated "February 2026" with a verify-at link (boilerplate for comparison pages). Python decorator examples match v2.3.2 surface. Main issue: stale cross-link `/guides/performance-benchmarks` at L685 (slug moved).
- **Stale-shape examples:** L685 `/guides/performance-benchmarks` slug.
- **Cycle 1-4 cross-link impact:** none direct.

### `/community/vs/hasura-sqlserver` (`hasura-sqlserver.mdx`, 268 lines)

- **Bucket:** POLISH.
- **Reason:** Phase 01 already updated v2.0.2+ → v2.1+ anchors (Cycle 1) and `install.fraiseql.dev` swap (Cycle 4). The claim "Windows Authentication / Azure AD / AG listener" matches the SQL Server enterprise surface. Comparison table is correct. Minor issues only.
- **Stale-shape examples:** Spot-check needed for any `/guides/` cross-link residuals.
- **Cycle 1-4 cross-link impact:** none direct.

### `/community/vs/apollo` (`apollo.mdx`, 694 lines)

- **Bucket:** POLISH.
- **Reason:** Comparison page; framing current. Python decorator examples align with v2.3.2 SDK. **One potential issue:** L305 `@fraiseql.subscription(entity_type="User", topic="user_created")` Python decorator — subscriptions exist as TOML config and runtime feature at frozen SHA (`crates/fraiseql-cli/src/config/toml_schema/subscriptions.rs`), but the `@fraiseql.subscription` Python authoring decorator with these exact kwargs needs source-verification. May be aspirational. Plus stale `/guides/performance-benchmarks` at L447 and L686.
- **Stale-shape examples:**
  - L305: `@fraiseql.subscription(entity_type=..., topic=...)` decorator — source-verify.
  - L447, L686: stale `/guides/performance-benchmarks` slugs.
- **Cycle 1-4 cross-link impact:** none direct.

### `/community/vs/prisma` (`prisma.mdx`, 598 lines)

- **Bucket:** POLISH.
- **Reason:** Comparison page; current framing. ORM-vs-API-server distinction is the page's load-bearing claim and matches v2.3.2 reality.
- **Stale-shape examples:** Re-grep needed for any `/guides/` slug residuals.
- **Cycle 1-4 cross-link impact:** none direct.

### `/community/vs/postgrest` (`postgrest.mdx`, 125 lines)

- **Bucket:** POLISH.
- **Reason:** Shortest of the 5. Comparison page; current framing. REST surface comparison matches v2.3.2 (`v2.1` introduced REST per the page; correct). PostgREST's "Coming soon" full-text-search caveat is real on FraiseQL side (no FTS in REST surface at v2.3.2).
- **Stale-shape examples:** L105 has one `@fraiseql.query` example — looks correct shape.
- **Cycle 1-4 cross-link impact:** none direct.

---

## Bucket totals

- **Auth/security cluster (7):** REWRITE = 3 (`/features/security`, `/features/oauth-providers`, `/features/mutations` — wait, mutations is POLISH; correct count is 2). POLISH = 5. DEFER = 0. **Revised: REWRITE = 2 (`/features/security`, `/features/oauth-providers`); POLISH = 5 (`/features/encryption`, `/features/audit-logging`, `/features/rate-limiting`, `/features/server-side-injection`, `/features/mutations`); DEFER = 0.**
- **Concepts pass (9):** REWRITE = 1 (`/concepts/configuration`); POLISH = 7 (`/concepts/why-fraiseql`, `/concepts/how-it-works`, `/concepts/cqrs`, `/concepts/developer-owned-sql`, `/concepts/view-composition`, `/concepts/type-system`, `/concepts/schema`); DEFER = 1 (`/concepts/elo-validation` — borderline; can also slot into POLISH batch as one slug-fix line).
- **/community/vs/* (5):** REWRITE = 0; POLISH = 5; DEFER = 0.
- **Grand total:** **REWRITE = 3; POLISH = 17; DEFER = 1.** (Or if elo-validation rolls into POLISH: REWRITE = 3; POLISH = 18; DEFER = 0.)

---

## Proposed Cycle 7 partition

### Cycle 7a — Auth/security REWRITE batch (3 pages)

**Pages:**
- `/features/security` — hub rewrite; sets the cluster's scope vs `/building/authentication`.
- `/features/oauth-providers` — corrects the `[auth] = parse error` falsehood; aligns with `/building/authentication` caveat block; pivots config from `OIDC_*` env vars to `[auth]` TOML.
- `/concepts/configuration` — corrects "no `[auth]` section" falsehood; restores `[auth]` documentation; aligns with `/building/authentication`.

**Persona sequence per page:** Writer-Opus (substantive) → Bug-Finder-Opus (lighter than Cycles 1-4 — much of the adversarial work is reusable from Cycle 4's auth bug-finder; reuse `[security]` and `[auth]` fixtures; verify no NEW framework bugs hide in `/features/security`'s RBAC/admin-token surface) → Writer-GREEN (citations) → CI → Verifier + Reviewer parallel → Cleanup.

**Subagent estimate:** 3 Writer-Opus invocations (one per page; not batchable — each is a substantive rewrite with citations) + 1 Bug-Finder-Opus invocation (consolidated across the 3 pages, since the surfaces overlap heavily and FW-3/FW-24..FW-29 already cover the open bugs). Reviewer-Opus per page (3 invocations).

**Expected framework bugs:** 0-2 new. Most of the security cluster's open issues are already filed (FW-3 RBAC + FW-24..FW-29 auth). A potential new finding around the `[security.error_sanitization]` default-disabled posture or the `[server.cors]` wildcard guard is possible.

### Cycle 7b — Concepts + low-risk security POLISH batch (12 pages, single Writer session)

**Pages (concepts POLISH = 8 including elo-validation; security POLISH = 5):** 13 pages total. Each page gets a ≤10-line patch: cross-link slug fixes (`/guides/X` → `/building/X` or `/operations/X`), FW-N caveat additions where applicable (rate-limiting needs FW-24 caveat), field-name corrections (rate-limiting `failed_login_max_attempts`), and the `/concepts/mutations` → `/features/mutations` slug-pivot.

**Pages in 7b:**
1. `/concepts/why-fraiseql` — 1 slug fix
2. `/concepts/how-it-works` — slug fixes + verify `demo.fraiseql.dev` removed
3. `/concepts/cqrs` — 1 slug fix
4. `/concepts/developer-owned-sql` — slug verify
5. `/concepts/view-composition` — 2 slug fixes
6. `/concepts/type-system` — 1 slug fix
7. `/concepts/schema` — slug verify + SpecQL Aside
8. `/concepts/elo-validation` — 1 slug fix (rolls in from DEFER bucket; trivial)
9. `/features/encryption` — 1 slug fix
10. `/features/audit-logging` — "Schema (auto-created)" copy correction
11. `/features/rate-limiting` — FW-24 caveat box + field-name correction (`max_attempts` not `max_requests`; `lockout_secs` not `window_secs`) + slug fix
12. `/features/server-side-injection` — 1 slug fix + SQLite caveat verify
13. `/features/mutations` — auth section 2-line patch (point to `[auth]` / `[auth_hs256]` TOML; cross-link `/building/authentication`) + scope-statement at top re: `/getting-started/adding-mutations` overlap

**Persona sequence:** single Writer-Opus session (one context window, batch-edit pattern similar to Cycle 6 G8a application) → CI → Reviewer-Opus single pass → Cleanup. NO Bug-Finder — these are slug fixes + 1-2 caveat additions; no adversarial work warranted.

**Subagent estimate:** 1 Writer-Opus invocation (batch); 1 Reviewer-Opus invocation; 1 Cleanup-Sonnet invocation. **3 invocations total for 13 pages.**

**Expected framework bugs:** 0 new (POLISH scope).

### Cycle 7c — vs/* comparison POLISH batch (5 pages, single Writer session)

**Pages:**
1. `/community/vs/hasura` — 1 slug fix (`/guides/performance-benchmarks` → `/operations/performance-benchmarks`)
2. `/community/vs/hasura-sqlserver` — slug verify
3. `/community/vs/apollo` — 2 slug fixes + verify `@fraiseql.subscription` decorator at frozen SHA (potential delete or rewrite of the subscription example)
4. `/community/vs/prisma` — slug verify
5. `/community/vs/postgrest` — slug verify

**Persona sequence:** single Writer-Opus session → CI → Reviewer-Opus single pass → Cleanup. NO Bug-Finder (comparison content; no framework surface to adversarial-test).

**Subagent estimate:** 1 Writer-Opus invocation; 1 Reviewer-Opus invocation; 1 Cleanup-Sonnet invocation. **3 invocations total for 5 pages.**

**Expected framework bugs:** 0 new.

### Partition summary

| Sub-cycle | Pages | Writer invocations | Bug-Finder | Reviewer invocations | Expected new FW bugs |
|-----------|-------|---------------------|------------|----------------------|----------------------|
| 7a (REWRITE) | 3 | 3 (Opus, per-page) | 1 (Opus, consolidated) | 3 (Opus, per-page) | 0-2 |
| 7b (POLISH concepts + security) | 13 | 1 (Opus, batch) | 0 | 1 (Opus, batch) | 0 |
| 7c (POLISH vs/*) | 5 | 1 (Opus, batch) | 0 | 1 (Opus, batch) | 0 |
| **Total** | **21** | **5 Writer-Opus** | **1 Bug-Finder-Opus** | **5 Reviewer-Opus** | **0-2** |

**Page-count check:** 21 not 22 because `/concepts/mutations` was already moved to `/features/mutations` under Option A (the brief mentions both; they refer to the same file). 7 security + 9 concepts + 5 vs/* = 21 distinct files. The brief's "~22 sweep-matrix rows" tracks the matrix rows; `/concepts/mutations` appears as a `redirected` row pointing at `/features/mutations` which is the actual page being edited.

---

## Novel gate candidates

### Candidate G9 — hub-vs-detail boundary for `/features/security`

**Question:** After `/building/authentication` Cycle 4 LEADs with security caveats (FW-24..FW-29), what is the role of `/features/security`?

- **G9a — Make `/features/security` a thin hub.** Page lists each security subsystem (auth → link to `/building/authentication`, rate limiting → link to `/features/rate-limiting`, encryption → link to `/features/encryption`, RBAC → owned by this page) with one-paragraph descriptions. Avoids prose duplication with the cluster's detail pages.
- **G9b — Make `/features/security` a substantive "all the bits on one page" reference.** Page expands every section: JWT validation, field-level RBAC, server-side injection, rate limiting, encryption, audit logging, RBAC API. Cross-links to detail pages for depth. Higher prose duplication; better single-page navigability.
- **G9c — Split.** `/features/security` keeps JWT verification + RBAC management API (the topics it uniquely owns) and de-scopes the rest with cross-links.

**Recommendation: G9c.** Lowest duplication risk; aligns with the IA's hub-and-spoke pattern (`/building/authentication` is the "how to authenticate" page; `/features/security` becomes the "RBAC + field-level access control" page; rate-limiting / encryption / oauth-providers / audit-logging are their own detail pages). Orchestrator-driveable without human gate if recommendation is accepted. If user prefers G9a or G9b, surface as G9 in handoff before Writer-GREEN.

### Candidate G10 — Python decorator scope alignment across the cluster

**Question:** Cycles 1-4 rewrote critical pages WITHOUT prominent Python decorator code (multi-tenancy.md, file-storage.md, observers.mdx, building/authentication.md are TOML-LEAD with minimal `@fraiseql.*` references). The Cycle-7 POLISH pages (server-side-injection, mutations, oauth-providers detail sections, all concept pages, all vs/* pages) are heavily Python-decorator-LEAD. Should Writer-GREEN normalize them to TOML-LEAD as well, or preserve Python decorators because they are correct at frozen SHA (the SDK authoring layer is real)?

**Recommendation: preserve Python decorators.** They are correct at frozen SHA, they ARE the authoring layer (verified at converter tests + executor docs comments), and a wholesale repivot to TOML-LEAD would expand 7b/7c from POLISH to REWRITE. The Cycle 1-4 pages were TOML-LEAD because they document *operator* concerns (deployment-time configuration); the Cycle 7 pages document *developer* concerns (schema authoring). The split is defensible. Orchestrator-driveable without human gate.

### Candidate G11 — comparison-page tone & freshness commitment

**Question:** `/community/vs/*` pages include time-bound disclaimers ("Pricing accurate as of February 2026", "verify current pricing at hasura.io/pricing"). These age out across the doc-overhaul timeline. Are we committing to keep them updated, or formally accepting them as point-in-time snapshots?

**Recommendation: accept as point-in-time.** Add a single inline tag per page: "Snapshot as of <month-year> @ FraiseQL v2.3.2." Orchestrator-driveable without human gate. The Final Reviewer in Phase 10 sweeps for any newly-outdated comparison.

---

## Orchestrator-default recommendation

If no human gate is surfaced for G9 / G10 / G11 resolution:

1. **Orchestrator accepts:**
   - G9 → G9c (`/features/security` becomes RBAC + field-level access control hub; other topics linked out).
   - G10 → preserve Python decorators on POLISH pages; do not repivot to TOML-LEAD.
   - G11 → add "Snapshot as of <month-year>" line to each vs/* page; accept point-in-time framing.

2. **Orchestrator drives the partition in sequence:**
   - **Cycle 7a** (auth/security REWRITE — 3 pages): spawn 3 Writer-Opus subagents in parallel (or sequence if dependency-chain concerns arise — security hub depends on oauth-providers + configuration outcomes for cross-link wiring). Spawn 1 consolidated Bug-Finder-Opus on the cluster. Reviewer-Opus per page in fresh contexts.
   - **Cycle 7b** (concepts + security POLISH — 13 pages, single batch): 1 Writer-Opus session, 1 Reviewer-Opus session, 1 Cleanup-Sonnet session.
   - **Cycle 7c** (vs/* POLISH — 5 pages, single batch): 1 Writer-Opus session, 1 Reviewer-Opus session, 1 Cleanup-Sonnet session.

3. **CI gate per sub-cycle:** Each sub-cycle CI must be green before the next starts.

4. **Style Auditor** at Cycle 7 close (or rolls forward to Cycle 8 phase-close style audit as already scheduled).

---

## Anti-scope confirmation

This document does NOT:
- Edit any docs page.
- Edit any framework file under `~/code/fraiseql`.
- File any framework bug (Bug-Finder territory in 7a).
- Amend prior commits.
- Push to `main`.

The Writer-GREEN cycle that follows this RED applies the bucket classifications above, after the orchestrator (or user) resolves the G9/G10/G11 candidates (if surfaced) and confirms the partition.
