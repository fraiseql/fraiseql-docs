# Phase 03: Critical rewrites

## Objective

Replace the four documentation pages that **actively mislead** today: `guides/multi-tenancy.md`, `features/file-storage.md`, `concepts/observers.mdx`, `guides/authentication.md`. Each one describes a different product than what the framework actually ships.

## Why this exists

Stale facts are annoying. Missing pages are inconvenient. Pages that *confidently* describe a different product than what the framework ships are dangerous — they cost adopters days of debugging when their setup follows the docs but doesn't work. These four pages are doing that today.

This is the highest-leverage phase in the entire plan: every reader of these pages either gives up or files a bug. We stop both, today.

## Success criteria

- [ ] Each of the four pages is fully rewritten against the v2.3.2 code reality.
- [ ] Each page has a passing `*.docs-test.sh` companion against the documented DB matrix.
- [ ] Each page has at least one before / after migration callout helping readers transition from the old shape (if they followed the previous version's docs).
- [ ] Each page's claims grep-able in the source.
- [ ] Each page has an adversarial reviewer sign-off.
- [ ] Cross-links updated from related pages.
- [ ] At least one framework bug filed per page (statistically — these areas are dense and likely to surface real issues).

## Scope (in)

### `guides/multi-tenancy.md` → rewrite

**Old:** generic SaaS multi-tenancy primer using a hand-rolled Python `TenantRouter` example.

**New:** documents the actual built-in multi-tenancy:
- Per-tenant executor isolation (v2.2.0).
- Dispatch sources: `X-Tenant-ID` header, JWT `tenant_id` claim, Host-domain registry.
- Admin REST API:
  - `PUT/DELETE /api/v1/admin/tenants/{key}`
  - `GET /api/v1/admin/tenants`
  - `GET /api/v1/admin/tenants/{key}/health`
  - `PUT/DELETE /api/v1/admin/domains/{domain}`
  - `GET /api/v1/admin/domains`
- ArcSwap-based hot-reload semantics.
- Single-tenant zero-overhead claim.
- Security note: explicit-but-unregistered tenant key returns 403, not default-tenant data.
- v2.3 additions (Phase 15 hardening):
  - `TenancyConfig` / `TenancyMode` settings.
  - Compile-time `@tenant_id` row-isolation guard.
  - Schema-isolation DDL + `search_path` management.
  - Suspend/resume lifecycle with admin scope guard.
  - Tenant-aware rate limiting and quotas.
  - Tenant audit trail.
  - Tenant cross-source consistency validation.

### `features/file-storage.md` → rewrite

**Old:** Python-decorator-flavoured `Upload` mutation + `[files]` TOML section that doesn't exist in v2.3.

**New:** documents the v2.3 `fraiseql-storage` crate:
- Backends: local, S3, Azure Blob, GCS.
- RLS-enforced tenant isolation.
- File transforms (resize, watermark, format conversion).
- Access control routes mounted on the server.
- Storage API endpoints.
- Security guardrails: HTTP allowlist defaults (default-deny outbound HTTP in `fraiseql-functions` adjacent).
- `FraiseQLError::File(FileError::*)` error mapping (v2.3 migration callout).

### `concepts/observers.mdx` → rewrite

**Old:** Python `@observer` decorator API with `webhook=`/`email=`/`slack=` action kwargs.

**New:** documents the actual observer runtime:
- `[observers]` TOML section.
- Backends: in-memory, NATS, Redis, PostgreSQL, MySQL.
- Feature flags: `observers`, `observers-nats`, `observers-enterprise`.
- Action types: webhook (with retry / DLQ), NATS publish, email, custom.
- Observer changelog handlers, DLQ handlers (v2.3 additions).
- Lifecycle: subscription, dispatch, retry strategy, DLQ behaviour.
- `entity_type_index` atomicity (v2.3.0 F056 fix — explicit snapshot atomicity).
- Cross-instance HA via `observers-enterprise`.
- Worker panic propagation (v2.3 F014).

### `guides/authentication.md` → rewrite

**Old:** JWT 101 + Python `@authenticated` decorators. Comprehensive but only scratches the surface.

**New:** maps the actual auth surface:
- Authentication methods:
  - JWT / OIDC (incl. nested-claims extraction, `jwt:email` / `jwt:name`).
  - API keys with hashed storage (`[security.api_keys]`).
  - HS256 mode for testing (#217 in v2.1.6).
  - PKCE OAuth flow (state encryption — `[security.state_encryption]`, S256 default).
  - `/auth/me` endpoint (v2.1.5).
- Token revocation (`[security.token_revocation]`).
- Rate limiting on auth endpoints (per-IP for start/callback, per-user for refresh).
- Brute-force protection (failed_login_max_attempts).
- Cookie security (`__Host-` prefix, RFC 6265 quoting).
- Pointer to Auth Extensions (Phase 13 / v2.3) — magic links, TOTP, SMS OTP, social, account linking — covered in phase 05.
- Pointer to OAuth providers reference (existing page, sanity-checked in phase 08).

## Scope (out)

- New pages for Auth Extensions (magic links, TOTP, social) — phase 05.
- OAuth Providers reference page — phase 08 sweep.
- Federation auth + mTLS — phase 06.
- RBAC reference details — left in existing security page; touched in phase 08.

## Dependencies

- **Requires:** Phase 02 (so we can link to migration callouts) and Phase 01 (G1 resolved).
- **Blocks:** Phase 05 Auth Extensions page links *into* the rewritten authentication.md.

## Personas involved

This phase is the highest-leverage in the overhaul and the most likely source of framework bugs. Each cycle runs the full persona sequence.

| Cycle | Personas (in order) |
|-------|---------------------|
| 1 (multi-tenancy) | Writer → Bug-Finder (Opus 4.7 — actively try to cross tenant boundaries) → Writer GREEN → CI green → Source-Citation Verifier + Reviewer (parallel) → Cleanup |
| 2 (file-storage) | Writer → Bug-Finder (try cross-tenant blob access, signed-URL replay) → Writer → CI → Verifier + Reviewer → Cleanup |
| 3 (observers) | Writer → Bug-Finder (kill webhook destination; race DLQ handlers) → Writer → CI → Verifier + Reviewer → Cleanup |
| 4 (authentication) | Writer → Bug-Finder (algorithm-confusion attack, replay revoked token) → Writer → CI → Verifier + Reviewer → Cleanup |
| 5 (style audit) | Style Auditor (Sonnet 4.6) → Cleanup |

Expected escalations: zero in nominal case. If the Style Auditor flags >10 voice issues across four pages, escalate to Opus for cycle 5 and review prompt fidelity in handoff.

## TDD cycles

### Cycle 1: `multi-tenancy.md` rewrite

- **RED:**
  - Start a single-tenant FraiseQL server in the container. Send `X-Tenant-ID: foo` for an unregistered key. Capture response.
  - Configure two-tenant deployment via `PUT /api/v1/admin/tenants/foo` and `bar`. Issue queries through both with the same JWT. Observe behaviour.
  - Old docs page renders Python `TenantRouter` example that has nothing to do with this.
- **GREEN:** new page with:
  - "Built-in multi-tenancy" section (the default reader path).
  - Configuration via TOML + admin REST.
  - Three subsections: per-DB, per-schema, per-row tenancy modes.
  - Compile-time `@tenant_id` guard explanation.
  - Security model: explicit-deny on unregistered keys; 403 not default-tenant.
  - Hot-reload semantics.
  - Worked example: bootstrap two tenants, query both, verify isolation.
- **REFACTOR:** push the "design rationale" section to a `## Architecture` block at the bottom; lead with how-to.
- **CLEANUP:** `multi-tenancy.docs-test.sh`:
  - Bring up FraiseQL with `[tenancy].mode = "row"`.
  - Create tenants `acme` and `nova` via admin API.
  - Insert tenant-scoped rows in PG.
  - Query each tenant's data; cross-tenant query returns empty.
  - Tenant `xyz` (unregistered) returns 403.
  - Tear down.

### Cycle 2: `file-storage.md` rewrite

- **RED:** the current page's `[files]` TOML doesn't appear anywhere in `~/code/fraiseql`'s `fraiseql.toml.example`. The `Upload` GraphQL multipart mutation has no corresponding code path in `fraiseql-storage`.
- **GREEN:** new page covering:
  - `[storage]` TOML section (the actual current shape — confirmed by reading `fraiseql-storage` config types).
  - Per-backend configuration (local, S3, Azure, GCS).
  - RLS tenant-isolation contract.
  - File transforms.
  - Access control routes.
  - Error mapping (FileError variants → HTTP status).
- **REFACTOR:** worked example uses MinIO (Compose has it in phase 00); shows upload, transform, signed-URL download.
- **CLEANUP:** `file-storage.docs-test.sh`:
  - Bring up FraiseQL + MinIO + Azurite + fake-gcs.
  - For each backend: upload a 100KB image, fetch metadata, transform (resize), download, assert byte count and MIME.
  - Negative: attempt to access another tenant's blob → 403 with documented error.

### Cycle 3: `observers.mdx` rewrite

- **RED:** the existing page's `@observer(entity="Order", event="INSERT", condition=..., actions=[slack(...), email(...)])` Python decorator does not exist in the Rust runtime. The page is purely aspirational.
- **GREEN:** new page covering:
  - The observer mental model (event → registered handler → dispatch → retry / DLQ).
  - TOML configuration:
    ```toml
    [observers]
    enabled = true
    backend = "nats"        # or postgres / redis / in-memory / mysql
    nats_url = "${FRAISEQL_NATS_URL}"

    [[observers.handlers]]
    name = "slack_notifier"
    event = "user_created"
    action = "slack"
    webhook_url = "https://hooks.slack.com/..."
    retry_strategy = "exponential"
    max_retries = 3
    ```
  - Action types (webhook, slack, email, NATS publish, custom).
  - Feature-flag matrix (`observers`, `observers-nats`, `observers-enterprise`).
  - Multi-instance HA (lease management, DLQ handlers).
  - Hot-reload safety (v2.3 F056 — `entity_type_index` snapshot atomicity).
  - Worker panic propagation (v2.3 F014).
- **REFACTOR:** restructure as "Concept → Configuration → Action types → Operations".
- **CLEANUP:** `observers.docs-test.sh`:
  - Bring up FraiseQL + NATS.
  - Configure one observer with a webhook to a netcat sink in the test container.
  - Trigger the source event via mutation.
  - Verify the webhook payload reaches the sink.
  - Kill the sink; verify retries; verify DLQ contains the failed event.

### Cycle 4: `authentication.md` rewrite

- **RED:** the existing page covers JWT but has no awareness of PKCE, state encryption, `/auth/me`, API keys, token revocation, brute-force protection — all of which are configured in the actual `[security]` and `[auth]` TOML.
- **GREEN:** new page covering:
  - The full `[auth]` + `[security.*]` surface.
  - JWT validation (algorithms, JWKS, audience).
  - OAuth/OIDC providers (deep link to oauth-providers reference page).
  - PKCE OAuth flow with state encryption.
  - Cookie-based session (`__Host-access_token`, `HttpOnly`, RFC 6265 quoting).
  - `GET /auth/me` endpoint + `[auth.me]` config.
  - Nested JWT claims extraction (Azure AD `{"value": ...}`, OIDC `{"given": ..., "family": ...}`).
  - RLS session variables (`jwt:email`, `jwt:name`, `jwt:display_name`, custom).
  - API key authentication (`[security.api_keys]`).
  - HS256 mode for tests.
  - Token revocation (memory / Redis / Postgres).
  - Brute-force protection (failed_login_max_attempts).
  - Rate limiting on auth endpoints.
  - Pointers: Auth Extensions for magic-link / TOTP / social (phase 05); OAuth Providers reference; Federation auth (phase 06).
- **REFACTOR:** add a decision tree at the top: "Which method should I use?" → JWT, API key, OIDC, cookie session.
- **CLEANUP:** `authentication.docs-test.sh`:
  - Configure JWT auth with HS256 (testing mode).
  - Issue a valid token; verify a protected query succeeds.
  - Tamper the signature; verify 401.
  - Revoke (Redis backend); verify subsequent use fails closed.
  - PKCE flow against a stub identity provider container; verify the cookie shape after callback.
  - `GET /auth/me`; verify the claims subset returned.

### Cycle 5: Phase-close style audit

Persona: Style Auditor (Sonnet 4.6) → Cleanup (Sonnet 4.6).

- **RED:** four rewritten pages × multiple persona invocations. Voice drift is plausible, especially because each page touches a different framework area (tenancy / storage / observers / auth).
- **GREEN:** Style Auditor reads all four pages in one context window, produces `_internal/.plan/style-audits/phase-03.md`. Special attention to: security-callout tone, error-message quoting style, "Migration" callout placement, terminology consistency for security-sensitive terms (`tenant_id` vs. `fk_customer_org`; `JWT claim` vs. `token claim`).
- **CLEANUP:** Cleanup applies all entries. Handoff updated with the bug-list for phase 09.

## Adversarial review protocol

Each page goes through a fresh-context review:

1. Reviewer pulls the branch; runs the page's `*.docs-test.sh` from a fully reset Docker state.
2. For the multi-tenancy page: reviewer adds a deliberate cross-tenant query to the test (assertion: must fail). If the page's example doesn't tell them how to make this fail predictably, the page is wrong.
3. For the file-storage page: reviewer changes one config key to a non-existent value. Expect a clear error message; the page must document this failure mode.
4. For the observers page: reviewer kills the webhook destination mid-test. The page's DLQ description must match what actually ends up in the DLQ.
5. For the authentication page: reviewer tries the "wrong algorithm" attack (JWT signed with HS256 against an RS256-configured server). Page must call this out.
6. 12-point checklist filled on the PR.

## Container verification matrix

| Page | PG | MySQL | SQLite | MSSQL | Other |
|------|----|----|----|----|-----|
| multi-tenancy | ✅ | ⚠️ (PG primary; MySQL where applicable) | ❌ (RLS limitations — document) | ⚠️ | Redis (rate-limiting integration) |
| file-storage | ✅ | n/a (storage is DB-agnostic) | n/a | n/a | MinIO, Azurite, fake-gcs |
| observers | ✅ | ✅ | ⚠️ (in-memory backend only) | ✅ | NATS, Redis |
| authentication | ✅ | ✅ | ✅ | ✅ | Redis (token revocation, PKCE) |

## Risks specific to this phase

| Risk | Mitigation |
|------|------------|
| The actual `[storage]` config shape isn't what we expect from CHANGELOG; needs source verification | Cycle 2 RED reads `crates/fraiseql-storage/src/config.rs` directly before writing GREEN |
| Observers DLQ behaviour differs across backends | The page documents per-backend behaviour explicitly; the test exercises NATS path |
| `@tenant_id` compile-time guard may not yet have a public surface | If true, page documents the runtime guard and files an issue requesting the compile-time guard be exposed in user code |
| Auth page risks becoming bloated | Use cross-links aggressively; keep this page to "how to authenticate"; push detail to oauth-providers + auth-extensions + token-revocation pages |

## Estimated effort

**Effort proxy: 2.** Highest-leverage phase. Per page: Writer-Opus (substantial — read framework source, write draft with citations), Bug-Finder-Opus (substantial — these are exactly the surfaces where bugs hide), Reviewer-Opus, Verifier-Sonnet, Cleanup-Sonnet. Expected framework-bug count per page: ≥1. Style Auditor at close. Plan for compute escalations on at least one cycle.

## Status

- [ ] Not started
- [~] RED in progress
- [ ] GREEN in progress
- [ ] REFACTOR in progress
- [ ] CLEANUP in progress
- [ ] Complete

Opened 2026-05-29 against `main@9b512aa` (Phase 02 squash). Branch `phase-03/critical-rewrites`.

## Owner

orchestrator (Cycle 0 / branch + status flip); Writer Opus 4.7 onwards per cycle.

## Pages completed

- `/building/multi-tenancy` (Cycle 1 — closed 2026-05-29)
- `/features/file-storage` (Cycle 2 — closed 2026-05-30)

## Framework bugs filed

- FW-3 [#330](https://github.com/fraiseql/fraiseql/issues/330) — off-the-shelf binary does not wire `TenantExecutorRegistry`/`TenantExecutorFactory`/`DomainRegistry`/`TenantAuditLog`; RBAC bootstrap crash when `admin_api_enabled = true` or non-empty `admin_token`
- FW-4 [#331](https://github.com/fraiseql/fraiseql/issues/331) — WebSocket subscription endpoint drops JWT `tenant_id` claim and disables strict cross-source validation
- FW-5 [#332](https://github.com/fraiseql/fraiseql/issues/332) — GraphQL handler collapses `ServiceUnavailable { retry_after }` into `ErrorCode::Forbidden` (HTTP 403), losing `Retry-After` header for suspended tenants
- FW-6 [#333](https://github.com/fraiseql/fraiseql/issues/333) — `X-Tenant-ID` validator allows `-` (hyphen) but schema-isolation validator rejects it; keys with `-` silently fail schema provisioning in `schema` mode
- FW-7 [#334](https://github.com/fraiseql/fraiseql/issues/334) — binary doesn't auto-wire `[storage.<name>]` TOML; every `/storage/v1/*` request returns 404 regardless of config
- FW-8 [#335](https://github.com/fraiseql/fraiseql/issues/335) — (CRITICAL) signed-URL replay / no-auth presign: `presign_handler` performs no RLS/metadata check — anonymous 24h presigned URLs
- FW-9 [#336](https://github.com/fraiseql/fraiseql/issues/336) — cross-bucket isolation: modern routes don't forward `bucket_name` to backend — key collisions across buckets
- FW-10 [#337](https://github.com/fraiseql/fraiseql/issues/337) — MIME confusion / stored XSS: `get_handler` serves verbatim `Content-Type`, no `nosniff`, no `Content-Disposition`, no magic-byte check
- FW-11 [#338](https://github.com/fraiseql/fraiseql/issues/338) — unbounded upload body: `default_max_request_body_bytes = 1_048_576` applied globally; full buffering before rejection
- FW-12 [#339](https://github.com/fraiseql/fraiseql/issues/339) — LIKE injection in list: `metadata::list` interpolates `prefix` into `LIKE` with no ESCAPE clause
