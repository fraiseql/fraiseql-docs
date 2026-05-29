---
title: Multi-tenancy
description: Compose FraiseQL's multi-tenant runtime as a library — per-tenant executors, dispatch sources, admin API, and the binary-wiring gap at v2.3.2
---

FraiseQL ships a multi-tenant runtime as a set of `fraiseql-server` library APIs. A host binary composes an `AppState` with a `TenantExecutorRegistry`, a `TenantExecutorFactory`, an optional `DomainRegistry`, and an optional `TenantAuditLog`, then mounts the same routers the off-the-shelf binary mounts. The runtime supports three isolation modes (`none`, `row`, `schema`), three dispatch sources (JWT claim, `X-Tenant-ID` header, Host-domain registry), and admin REST endpoints for tenant lifecycle, quotas, and audit. The off-the-shelf `fraiseql-server` binary at v2.3.2 does **not** wire any of these components by default — see [Known issues](#known-issues) before planning a deployment.

## Quick reference

| Aspect | Value at v2.3.2 |
|---|---|
| Isolation modes | `none`, `row`, `schema` (compile-time `[fraiseql.tenancy] mode = "..."`) <!-- source: crates/fraiseql-core/src/schema/security_config.rs:L113-L142 --> |
| Database support — `row` | PostgreSQL, MySQL, SQLite, SQL Server (adapter-agnostic; the validator only rewrites `inject` params) <!-- source: crates/fraiseql-cli/src/schema/converter/tenancy.rs:L62-L135 --> |
| Database support — `schema` | PostgreSQL only (the helpers emit `SET search_path TO tenant_{key}, public` and `CREATE SCHEMA`) <!-- source: crates/fraiseql-server/src/tenancy/schema_isolation.rs:L1-L120 --> |
| Dispatch precedence | JWT `tenant_id` > `X-Tenant-ID` header > `Host` header through `DomainRegistry` <!-- source: crates/fraiseql-server/src/routes/graphql/tenant_key.rs:L36-L102 --> |
| Default on unregistered key | `FraiseQLError::Authorization` ("Tenant '`<key>`' is not registered") — surfaced as HTTP 403 by the GraphQL handler <!-- source: crates/fraiseql-server/src/routes/graphql/tenant_registry.rs:L140-L165 --> <!-- source: crates/fraiseql-server/src/routes/graphql/handler.rs:L577-L583 --> |
| Hot-reload | `ArcSwap` atomic swap on `upsert`; in-flight requests complete on the previous executor <!-- source: crates/fraiseql-server/src/routes/graphql/tenant_registry.rs:L67-L92 --> <!-- source: crates/fraiseql-server/src/routes/graphql/tenant_registry.rs:L199-L212 --> |
| Audit backend | `TenantAuditLog` trait; `InMemoryAuditLog` default (not durable) <!-- source: crates/fraiseql-server/src/tenancy/audit.rs:L60-L120 --> |

## How tenancy is composed today

The `fraiseql-server` crate exposes `AppState` builders that install each tenancy component independently. A host binary wraps `fraiseql-server`, calls the builders, and mounts the same routers the off-the-shelf binary mounts.

<!-- source: crates/fraiseql-server/src/routes/graphql/app_state.rs:L226-L283 -->

```rust title="src/main.rs (host binary)"
use std::sync::Arc;
use fraiseql_server::routes::graphql::{
    AppState, DomainRegistry, TenantExecutorRegistry,
};
use fraiseql_server::tenancy::audit::InMemoryAuditLog;

// `default_executor` is the executor for the unset-tenant case
// (single-tenant compatibility). `factory` builds a per-tenant executor
// from compiled schema JSON + a connection config.
let state = AppState::new(default_executor)
    .with_tenant_registry(Arc::new(
        TenantExecutorRegistry::new(default_executor.clone()),
    ))
    .with_tenant_executor_factory(factory)
    .with_domain_registry(Arc::new(DomainRegistry::new()))
    .with_tenant_audit_log(Arc::new(InMemoryAuditLog::new()));
```

<!-- source: crates/fraiseql-server/tests/multitenancy_test.rs:L107-L130 -->

The integration test `crates/fraiseql-server/tests/multitenancy_test.rs` exercises this exact shape against stub adapters. The off-the-shelf binary's `build_app_state()` leaves `tenant_registry`, `tenant_executor_factory`, and `tenant_audit_log` as `None`, and constructs an empty `DomainRegistry` — see [Known issues](#known-issues).

<!-- source: crates/fraiseql-server/src/routes/graphql/app_state.rs:L95-L106 -->
<!-- source: crates/fraiseql-server/src/routes/graphql/app_state.rs:L171-L182 -->

## Tenancy modes

The mode is fixed at compile time, declared in `fraiseql.toml`, compiled into `schema.compiled.json` under `security.tenancy`. Three values are accepted.

<!-- source: crates/fraiseql-core/src/schema/security_config.rs:L113-L142 -->
<!-- source: crates/fraiseql-core/src/schema/security_config.rs:L144-L186 -->

```toml title="fraiseql.toml"
[fraiseql.tenancy]
mode = "row"           # "none" | "row" | "schema"
tenant_claim = "tenant_id"   # JWT claim name; default "tenant_id"
```

### `none` — single-tenant

Default. No isolation machinery is compiled in. Use the multi-tenant runtime APIs at all when you have a single-tenant deployment if you want to keep the dispatch path uniform for future tenancy.

### `row` — shared tables with `@tenant_id` injection

Tenant-scoped GraphQL types declare a field annotated with `@tenant_id`. The compiler walks every query and mutation whose return type carries the annotation, and either auto-injects `inject_params = { <field>: jwt:<tenant_claim> }` or — if `inject` is non-empty and missing the annotated field — fails the build. The result is a runtime guarantee that the JWT-derived tenant identifier reaches the SQL `WHERE` clause for every read and every mutation.

<!-- source: crates/fraiseql-cli/src/schema/converter/tenancy.rs:L1-L60 -->
<!-- source: crates/fraiseql-cli/src/schema/converter/tenancy.rs:L62-L135 -->

```graphql title="schema.graphql (excerpt)"
type Project {
  id: ID!
  name: String!
  tenant_id: UUID! @tenant_id
}
```

Adapter support: all four (PostgreSQL, MySQL, SQLite, SQL Server). The validator only rewrites `inject_params`; the resulting SQL is adapter-portable.

### `schema` — per-tenant PostgreSQL schemas

A tenant key `acme` maps to PostgreSQL schema `tenant_acme`. The runtime issues `SET search_path TO tenant_acme, public` on connection acquisition. DDL helpers emit `CREATE SCHEMA IF NOT EXISTS tenant_acme` and `DROP SCHEMA tenant_acme CASCADE`.

<!-- source: crates/fraiseql-server/src/tenancy/schema_isolation.rs:L17-L120 -->

Adapter support: PostgreSQL only. The helpers are PostgreSQL-specific by construction (`SET search_path` and the 63-character identifier cap are PostgreSQL conventions). MySQL, SQLite, and SQL Server have no equivalent abstraction in the v2.3.2 release.

## Dispatch sources and precedence

Per request, `TenantKeyResolver::resolve` collects up to three sources and picks the highest-priority one:

1. **JWT `tenant_id` claim** (highest priority, trusted because the JWT signature is already validated).
2. **`X-Tenant-ID` header** (validated alphabet + length; see below).
3. **`Host` header** routed through the installed `DomainRegistry`.

<!-- source: crates/fraiseql-server/src/routes/graphql/tenant_key.rs:L36-L102 -->

When more than one source is present, the resolver compares values. In **strict mode**, a mismatch returns `FraiseQLError::Validation`. The GraphQL handler turns strict mode on when the compiled schema has RLS configured.

<!-- source: crates/fraiseql-server/src/routes/graphql/tenant_key.rs:L83-L102 -->
<!-- source: crates/fraiseql-server/src/routes/graphql/handler.rs:L506-L520 -->

### `X-Tenant-ID` header validation

The validator accepts ASCII alphanumeric plus `-` and `_`, up to `MAX_TENANT_KEY_LEN = 128` bytes. Any character outside that alphabet returns `FraiseQLError::Validation` with message `"X-Tenant-ID contains invalid characters (allowed: a-zA-Z0-9_-)"`. Over-length returns `"X-Tenant-ID exceeds maximum length of 128 characters"`.

<!-- source: crates/fraiseql-server/src/routes/graphql/tenant_key.rs:L20-L21 -->
<!-- source: crates/fraiseql-server/src/routes/graphql/tenant_key.rs:L108-L122 -->

When the runtime is configured for `schema` mode, the alphabet shrinks further — see [Known issues](#known-issues) (FW-6, [#333](https://github.com/fraiseql/fraiseql/issues/333)).

### `DomainRegistry` lookup

`DomainRegistry::lookup` strips the port from the `Host` header (so `api.acme.com:8080` becomes `api.acme.com`) and reads the resulting domain from a `DashMap`. Lookups are case-sensitive.

<!-- source: crates/fraiseql-server/src/routes/graphql/tenant_key.rs:L132-L165 -->

Register and lower-case domain entries before insertion, otherwise an operator who registers `Acme.com` while clients send `Host: acme.com` will see the request fall through to the default executor.

:::note[Deprecated path — do not use]
The pre-v2.2 `X-Org-ID` middleware in `crates/fraiseql-server/src/middleware/tenant.rs` is exported but is dead code in the `fraiseql-server` binary at v2.3.2 (no router invokes it). Use the `X-Tenant-ID` dispatch path described above. <!-- source: crates/fraiseql-server/src/middleware/tenant.rs:L20-L43 -->
:::

## Security defaults

The runtime-library guarantees, in order of importance, are:

- **Explicit-deny on unregistered keys.** When `tenant_registry().executor_for(Some("foo"))` is called and `foo` is not registered, the registry returns `FraiseQLError::Authorization("Tenant 'foo' is not registered")`. The GraphQL handler maps this to `ErrorCode::Forbidden` (HTTP 403). There is no fallback to the default executor for an explicit-but-unregistered key.
  <!-- source: crates/fraiseql-server/src/routes/graphql/tenant_registry.rs:L140-L165 -->
  <!-- source: crates/fraiseql-server/src/routes/graphql/handler.rs:L577-L583 -->
- **Suspended tenants return `FraiseQLError::ServiceUnavailable` with `retry_after = Some(60)`.** Read by the registry's `require_active` check on every request.
  <!-- source: crates/fraiseql-server/src/routes/graphql/tenant_registry.rs:L103-L104 -->
  <!-- source: crates/fraiseql-server/src/routes/graphql/tenant_registry.rs:L167-L182 -->
- **Strict cross-source validation when RLS is configured.** Schemas declaring RLS toggle the resolver's `strict` flag at the GraphQL handler. Conflicting tenant identifiers from JWT, `X-Tenant-ID`, and `Host` return `FraiseQLError::Validation` with the conflicting sources enumerated.
  <!-- source: crates/fraiseql-server/src/routes/graphql/handler.rs:L506-L520 -->
  <!-- source: crates/fraiseql-server/src/routes/graphql/tenant_key.rs:L83-L102 -->

:::caution[These are library-API guarantees]
The defaults above hold when a host binary wires `with_tenant_registry(...)`. The off-the-shelf `fraiseql-server` binary at v2.3.2 leaves the registry unset, so an unregistered `X-Tenant-ID: foo` is silently routed to the default executor and the suspended-tenant 503 mapping is unreachable. See [Known issues](#known-issues) for FW-3 ([#330](https://github.com/fraiseql/fraiseql/issues/330)) and FW-5 ([#332](https://github.com/fraiseql/fraiseql/issues/332)).
:::

## Admin REST API

Tenant lifecycle, domain mappings, and per-tenant health are managed through bearer-authenticated REST endpoints under `/api/v1/admin/`. Write operations are gated by `admin_token`; reads use `admin_readonly_token` if set, else `admin_token`.

| Endpoint | Method | Purpose |
|---|---|---|
| `/api/v1/admin/tenants/{key}` | `PUT` | Create or update a tenant (executor, quota, connection) <!-- source: crates/fraiseql-server/src/routes/api/tenant_admin.rs:L160-L212 --> |
| `/api/v1/admin/tenants/{key}` | `DELETE` | Remove a tenant; in-flight requests complete on the old executor <!-- source: crates/fraiseql-server/src/routes/api/tenant_admin.rs:L217-L247 --> |
| `/api/v1/admin/tenants/{key}/suspend` | `POST` | Suspend a tenant (data requests return 503) <!-- source: crates/fraiseql-server/src/routes/api/tenant_admin.rs:L250-L283 --> |
| `/api/v1/admin/tenants/{key}/resume` | `POST` | Resume a suspended tenant <!-- source: crates/fraiseql-server/src/routes/api/tenant_admin.rs:L285-L317 --> |
| `/api/v1/admin/tenants` | `GET` | List all registered tenant keys <!-- source: crates/fraiseql-server/src/routes/api/tenant_admin.rs:L355-L370 --> |
| `/api/v1/admin/tenants/{key}/health` | `GET` | Health-check a tenant's connection pool <!-- source: crates/fraiseql-server/src/routes/api/tenant_admin.rs:L372-L398 --> |
| `/api/v1/admin/domains/{domain}` | `PUT` | Register `domain` → `tenant_key` mapping <!-- source: crates/fraiseql-server/src/routes/api/tenant_admin.rs:L450-L475 --> |
| `/api/v1/admin/domains/{domain}` | `DELETE` | Remove a domain mapping <!-- source: crates/fraiseql-server/src/routes/api/tenant_admin.rs:L477-L505 --> |
| `/api/v1/admin/domains` | `GET` | List all `domain` → `tenant_key` mappings <!-- source: crates/fraiseql-server/src/routes/api/tenant_admin.rs:L507-L530 --> |

Every handler short-circuits with `ApiError::not_found("multi-tenant mode not enabled")` (HTTP 404) when `state.tenant_registry()` is `None`. The routes are mounted in `crates/fraiseql-server/src/server/routing/admin.rs` when `admin_token` is set.

<!-- source: crates/fraiseql-server/src/server/routing/admin.rs:L389-L489 -->

```bash title="Create a tenant"
curl -X PUT http://localhost:8080/api/v1/admin/tenants/acme \
  -H "Authorization: Bearer $FRAISEQL_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "schema": { "queries": [], "mutations": [] },
    "connection": { "database_url": "postgresql://fraiseql@db/acme" },
    "max_concurrent": 32,
    "max_requests_per_sec": 100
  }'
```

Delete order matters when domain mappings are involved: `DELETE /api/v1/admin/domains/{d}` before `DELETE /api/v1/admin/tenants/{key}`. A domain mapping whose target tenant no longer exists resolves the request to a 403 (the registry's explicit-deny path), but the registry won't auto-prune dangling domain rows.

## Hot-reload semantics

Each `TenantEntry` stores its executor as `Arc<ArcSwap<Executor<A>>>`. `upsert` calls `ArcSwap::store(new)` on existing entries; in-flight requests that already loaded the previous `Arc` continue to use it until they drop the guard. New requests pick up the swapped executor.

<!-- source: crates/fraiseql-server/src/routes/graphql/tenant_registry.rs:L67-L92 -->
<!-- source: crates/fraiseql-server/src/routes/graphql/tenant_registry.rs:L199-L212 -->

What is atomic at the entry level: the schema swap on an existing tenant key. What is not: cross-tenant invariants (e.g., "remove tenant `foo` after migrating its data to tenant `bar`"). Sequence destructive admin operations explicitly.

## Quotas and rate limiting

Each tenant carries an optional `TenantQuota`:

```rust
pub struct TenantQuota {
    pub max_requests_per_sec: Option<u32>,
    pub max_concurrent:       Option<u32>,
    pub max_storage_bytes:    Option<u64>,
}
```

<!-- source: crates/fraiseql-server/src/routes/graphql/tenant_registry.rs:L50-L62 -->

| Quota field | Enforced by | Failure mode |
|---|---|---|
| `max_requests_per_sec` | Per-tenant token bucket in the in-memory rate-limit backend <!-- source: crates/fraiseql-server/src/middleware/rate_limit/dispatch.rs:L122-L138 --> <!-- source: crates/fraiseql-server/src/middleware/rate_limit/in_memory.rs:L31-L80 --> | `CheckResult::deny` → HTTP 429 |
| `max_concurrent` | `tokio::sync::Semaphore` held for the duration of each request <!-- source: crates/fraiseql-server/src/routes/graphql/tenant_registry.rs:L242-L271 --> | `FraiseQLError::RateLimited` with `retry_after_secs = 1` |
| `max_storage_bytes` | Soft quota flag set by a background task; mutations rejected when set <!-- source: crates/fraiseql-server/src/routes/graphql/tenant_registry.rs:L273-L290 --> | Mutation rejected; reads still allowed |

Rate-limit backend matrix at v2.3.2: per-tenant token buckets are implemented only in the in-memory backend. The Redis backend returns `CheckResult::allow` for the tenant path (effectively allow-all).

<!-- source: crates/fraiseql-server/src/middleware/rate_limit/dispatch.rs:L128-L137 -->

## Audit trail

Tenant lifecycle events are recorded through the `TenantAuditLog` trait. The default `InMemoryAuditLog` stores events in a `RwLock<Vec<TenantEvent>>` — sufficient for testing, not durable.

<!-- source: crates/fraiseql-server/src/tenancy/audit.rs:L1-L60 -->
<!-- source: crates/fraiseql-server/src/tenancy/audit.rs:L60-L120 -->

Recorded events:

| `TenantEventKind` | Triggered by |
|---|---|
| `Created` | First `PUT /api/v1/admin/tenants/{key}` <!-- source: crates/fraiseql-server/src/routes/api/tenant_admin.rs:L195-L212 --> |
| `ConfigChanged` | Subsequent `PUT` on the same key |
| `Suspended` | `POST /api/v1/admin/tenants/{key}/suspend` <!-- source: crates/fraiseql-server/src/routes/api/tenant_admin.rs:L275-L283 --> |
| `Resumed` | `POST /api/v1/admin/tenants/{key}/resume` |
| `Deleted` | `DELETE /api/v1/admin/tenants/{key}` <!-- source: crates/fraiseql-server/src/routes/api/tenant_admin.rs:L237-L242 --> |

Audit failures are logged but do not abort the originating admin operation: `if let Err(e) = audit_log.record(...) { tracing::warn!(...); }`. Pick a durable backend by implementing the trait against your own datastore and passing the `Arc` to `AppState::with_tenant_audit_log(...)`.

## Schema isolation helpers (PostgreSQL)

When `mode = "schema"`, the runtime depends on a handful of helpers in `crates/fraiseql-server/src/tenancy/schema_isolation.rs`:

- `tenant_schema_name(key)` — produces `tenant_{key}` after validating the key is `[a-zA-Z0-9_]` and the result fits in 63 bytes (the PostgreSQL identifier cap).
- `search_path_sql(key)` — returns `SET search_path TO tenant_{key}, public`.
- `create_schema_ddl(key)` — returns `CREATE SCHEMA IF NOT EXISTS tenant_{key}`.
- `drop_schema_ddl(key)` — returns `DROP SCHEMA tenant_{key} CASCADE`.
- `provision_tenant_schema(adapter, key)` — runs `create_schema_ddl` through the adapter.
- `drop_tenant_schema(adapter, key)` — runs `drop_schema_ddl` through the adapter.

<!-- source: crates/fraiseql-server/src/tenancy/schema_isolation.rs:L17-L120 -->

The 63-character cap, minus the 7-character `tenant_` prefix, leaves 56 characters of usable tenant key in `schema` mode. The header validator allows up to 128. The intersection — `[a-zA-Z0-9_]` (no hyphen) and ≤ 56 characters — is the only safe alphabet when `schema` mode is enabled. See [Known issues](#known-issues) (FW-6, [#333](https://github.com/fraiseql/fraiseql/issues/333)).

## Worked example

The companion script `scripts/docs-test/pages/multi-tenancy.docs-test.sh` exercises the intended host-binary scenario:

1. Boot FraiseQL with `[tenancy].mode = "row"`.
2. Create tenants `acme` and `nova` via `PUT /api/v1/admin/tenants/{key}`.
3. Seed tenant-scoped rows in PostgreSQL.
4. Query each tenant's data; assert isolation.
5. Query tenant `xyz` (unregistered); assert HTTP 403.

```bash title="Expected — tenant acme"
curl -fsS http://localhost:8080/graphql \
  -H "Content-Type: application/json" \
  -H "X-Tenant-ID: acme" \
  -d '{"query":"{ projects { id name } }"}'
# {"data":{"projects":[{"id":"...","name":"acme-only"}]}}
```

```bash title="Expected — unregistered tenant"
curl -fsS -o /dev/null -w '%{http_code}\n' http://localhost:8080/graphql \
  -H "Content-Type: application/json" \
  -H "X-Tenant-ID: xyz" \
  -d '{"query":"{ projects { id } }"}'
# 403
```

At v2.3.2 the script runs against the library-API surface, not the off-the-shelf binary, because the binary does not wire the tenant registry — see [Known issues](#known-issues). The script's regression-test value is that it locks the contract: when [#330](https://github.com/fraiseql/fraiseql/issues/330) lands and the binary wires the runtime, the script flips to driving the binary directly without further changes.

## Migration from the pre-v2.2 page

:::caution[Previous version: `TenantRouter` is not a real API]
The prior revision of this page documented a Python `TenantRouter` helper and an `inject={"tenant_id": "jwt:tenant_id"}` decorator pattern. Neither exists in the FraiseQL v2.3.2 runtime. The actual surface is the Rust library API documented above; tenancy is configured in `[fraiseql.tenancy]` and through `AppState` builders, not through a Python decorator.
:::

What changed:

- The Python `TenantRouter` example is removed. The runtime is in Rust; there is no Python dispatch layer.
- The `inject={"tenant_id": "jwt:tenant_id"}` decorator is replaced by compile-time `@tenant_id` annotation in row mode (the validator auto-injects the parameter).
- RLS is no longer the primary isolation mechanism documented on this page — RLS is one valid implementation of `row` mode, but it is configured separately under `[security]`. See the [authentication guide](/building/authentication) for the JWT-claim → SQL session-variable pipeline (cross-referenced for the RLS interaction).
- Schema-per-tenant is now a first-class mode (`mode = "schema"`) with built-in DDL helpers, replacing the hand-rolled `CREATE SCHEMA` recipe.

## Known issues

Five framework bugs are open against the v2.3.2 multi-tenant surface. Plan around them.

| ID | Symptom | Workaround |
|---|---|---|
| FW-3 [#330](https://github.com/fraiseql/fraiseql/issues/330) | The off-the-shelf `fraiseql-server` binary does not wire `TenantExecutorRegistry`, `TenantExecutorFactory`, `DomainRegistry`, or `TenantAuditLog` in `build_app_state()`. Unregistered `X-Tenant-ID` returns 200 from the default executor; admin tenant REST returns 404. | Build a host binary that wraps `fraiseql-server` and calls the `AppState::with_tenant_*` builders (see [How tenancy is composed today](#how-tenancy-is-composed-today)). |
| FW-3 (sidenote in [#330](https://github.com/fraiseql/fraiseql/issues/330)) | Setting `admin_api_enabled = true` against a clean PostgreSQL database fails startup with `Failed to initialize RBAC schema: syntax error at or near "("`. | Leave `admin_api_enabled = false` and route admin operations through a separate trusted-network gateway until [#330](https://github.com/fraiseql/fraiseql/issues/330) is fixed. |
| FW-4 [#331](https://github.com/fraiseql/fraiseql/issues/331) | The WebSocket subscription endpoint calls `TenantKeyResolver::resolve(None, &headers, None, false)`: the JWT `tenant_id` claim is dropped, the installed `DomainRegistry` is unreachable, and strict cross-source validation is forced off. | Do not rely on subscription-path tenant dispatch for security. Until fixed, prefer GraphQL queries/mutations for tenant-scoped reads or terminate the subscription at an authenticating proxy that re-validates the tenant before forwarding. <!-- source: crates/fraiseql-server/src/routes/subscriptions.rs:L182-L184 --> |
| FW-5 [#332](https://github.com/fraiseql/fraiseql/issues/332) | The GraphQL handler maps every `executor_for_tenant` error to `ErrorCode::Forbidden`, including the `ServiceUnavailable { retry_after: Some(60) }` variant raised for suspended tenants. Suspended tenants reach the client as HTTP 403 with no `Retry-After` header. | When the suspended-state HTTP contract matters, surface a separate 503 from your gateway or document HTTP 403 as the suspended-state response until the variant is preserved upstream. |
| FW-6 [#333](https://github.com/fraiseql/fraiseql/issues/333) | The `X-Tenant-ID` validator (`[a-zA-Z0-9_-]`, ≤128 chars) and the schema-isolation validator (`[a-zA-Z0-9_]`, schema name ≤63 chars → 56 usable key chars) disagree. A tenant key with `-` is admitted but silently fails schema provisioning. | When `schema` mode is in use, enforce `[a-zA-Z0-9_]` and ≤56 characters at the admin layer before calling `PUT /api/v1/admin/tenants/{key}`. |

Three smaller caveats do not warrant upstream issues but affect operators:

- `DomainRegistry::lookup` is case-sensitive. Lower-case host values before registering domain mappings.
- `DELETE /api/v1/admin/domains/{domain}` before `DELETE /api/v1/admin/tenants/{key}` — a domain whose target tenant is gone resolves to a 403, which is correct but produces confusing error reports.
- RLS session-variable propagation to mutation SQL functions is tracked separately in [#329](https://github.com/fraiseql/fraiseql/issues/329). When you rely on `current_setting('app.tenant_id')` inside a mutation function, inject the claim explicitly via `inject_params = { tenant_id: "jwt:tenant_id" }` until [#329](https://github.com/fraiseql/fraiseql/issues/329) ships.

## Next steps

- [Authentication](/building/authentication) — JWT claim extraction that feeds the `tenant_id` source.
- [Schema design](/building/schema-design) — the `tb_` / `v_` / `fn_` trinity pattern that pairs with tenancy.
- [Reference: TOML configuration](/reference/toml-config) — `[fraiseql.tenancy]`, `[security]`, and admin-token settings.
- [Custom resolvers](/building/custom-resolvers) — how `inject_params` reaches your SQL functions.
