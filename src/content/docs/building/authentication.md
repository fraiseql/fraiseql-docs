---
title: Authentication
description: Configure JWT/OIDC, HS256, API keys, PKCE, token revocation, and auth rate limiting at v2.3.2 — with all security caveats
---

FraiseQL ships multiple authentication mechanisms in a single binary: an OIDC validator for production JWTs, an HS256 validator for integration testing, an API-key authenticator for service-to-service traffic, a PKCE OAuth2 flow with HttpOnly cookies, and a token-revocation manager. The off-the-shelf `fraiseql-server` binary auto-wires `[auth]` (OIDC) and `[auth_hs256]` directly from `ServerConfig`; every other auth subsystem — API keys, token revocation, PKCE, state encryption, per-endpoint rate limiting — lives behind the `fraiseql-cli compile` step that produces `schema.compiled.json`, and is consumed from `security.additional[...]` at startup. **Read [Security caveats](#security-caveats) before exposing any auth route to the public internet**; six framework issues are open at v2.3.2, two of them critical, and the v2.3 surface ships several security controls that exist in the CLI schema but are silently dropped by the server runtime.

## Security caveats

Six framework issues are open against the v2.3.2 authentication surface; one is critical, three are security regressions, two are operator footguns that the framework does not catch. **Do not expose `/auth/revoke*` to the public internet without an authenticating reverse proxy** (caveat 2 below). Eleven mitigations follow; they apply in addition to whatever your network perimeter enforces.

### 1. Anonymous baseline — no auth = no auth

When neither `[auth]` (OIDC) nor `[auth_hs256]` is configured, the binary boots, mounts `/graphql` and `/studio`, and serves every request as anonymous. The `*_require_auth` flags default `true` but only enforce when a validator is installed; with no validator the require-auth check is a no-op. The first deployment lesson is therefore to always configure `[auth]` or `[auth_hs256]` before exposing the binary to any non-localhost network.

<!-- source: crates/fraiseql-server/src/server/builder.rs:L308-L323 — OIDC validator built only when config.auth is Some -->
<!-- source: crates/fraiseql-server/src/server/builder.rs:L19-L39 — build_hs256_auth returns Ok(None) when [auth_hs256] absent -->

### 2. FW-26 [#358](https://github.com/fraiseql/fraiseql/issues/358) — `/auth/revoke` and `/auth/revoke-all` are unauthenticated (critical)

`mount_auth_routes` merges `POST /auth/revoke` and `POST /auth/revoke-all` into the router with no `route_layer`, no `from_fn_with_state`, no `oidc_auth_middleware`. The sibling `/auth/me` block in the same function does apply `oidc_auth_middleware`. The `revoke_token` handler decodes the supplied token via `jsonwebtoken::dangerous::insecure_decode` — no signature check — and stores its `jti` in the revocation store. `revoke_all_tokens` accepts a body `{"sub": "..."}` with no token at all. An anonymous attacker can lock out any user across every replica sharing the revocation store.

<!-- source: crates/fraiseql-server/src/server/routing/auth.rs:L103-L114 — revocation routes merged with no route_layer -->
<!-- source: crates/fraiseql-server/src/server/routing/auth.rs:L81-L101 — sibling /auth/me block DOES apply oidc_auth_middleware -->
<!-- source: crates/fraiseql-server/src/routes/auth.rs:L301-L375 — revoke_token uses dangerous::insecure_decode; revoke_all_tokens accepts {"sub": "..."} -->

**Mitigation:** gate `/auth/revoke` and `/auth/revoke-all` behind an authenticating reverse proxy (mTLS, OIDC introspection, or a known-key header check). If revocation is not strictly required at v2.3.2, omit `[security.token_revocation]` from the compiled schema entirely — the routes are not mounted when the manager is absent.

### 3. FW-27 [#359](https://github.com/fraiseql/fraiseql/issues/359) — HS256 `audience` is not enforced by the framework (security)

`Hs256Config.audience` is declared `Option<String>` with `#[serde(default)]` and has no `validate()` method. `build_hs256_auth` only calls `auth_config = auth_config.with_audience(aud)` when `hs.audience.is_some()`, and the OIDC `AuthMiddleware` only calls `validation.set_audience(...)` when the audience is present. The OIDC path enforces audience via `OidcConfig::validate()` — the HS256 path has no equivalent guard. A shared HS256 secret without `audience` is exposed to cross-service token confusion.

<!-- source: crates/fraiseql-server/src/server_config/hs256.rs:L24-L39 — Hs256Config.audience field is optional with serde default, no validate() method -->
<!-- source: crates/fraiseql-server/src/server/builder.rs:L19-L39 — build_hs256_auth only sets audience when hs.audience.is_some() -->

**Mitigation:** always set `audience = "<api-id>"` in `[auth_hs256]`. Treat it as required even though the framework does not enforce it.

### 4. FW-28 [#360](https://github.com/fraiseql/fraiseql/issues/360) — PKCE warns but continues without state encryption (security)

When `pkce.enabled = true` and `[security.state_encryption]` is absent, `pkce_store_from_schema` emits one `warn!` ("PKCE state tokens are sent to the OIDC provider unencrypted. Enable [security.state_encryption] in production for full protection.") and returns `Some(PkceStateStore)`. The store falls through to the unencrypted code path, so the outbound `state` token is the raw internal lookup key. CSRF protection still holds (the lookup key is random and one-shot), but the operator-facing claim that state encryption is "required" is unmet.

<!-- source: crates/fraiseql-server/src/server/initialization.rs:L80-L97 — pkce_store_from_schema warns then continues when state_encryption is None -->
<!-- source: crates/fraiseql-server/src/server/routing/auth.rs:L26-L46 — PKCE routes mount on (pkce_store, oidc_server_client); no state_encryption check -->

**Mitigation:** configure `[security.state_encryption]` with `STATE_ENCRYPTION_KEY` (a 32-byte random secret) before turning `pkce.enabled = true`. The warn log line is the only operator-side signal in production.

### 5. FW-29 [#361](https://github.com/fraiseql/fraiseql/issues/361) — JWKS hot-rotate window equals the cache TTL (security)

`get_decoding_key` checks the cache first and returns the cached key when not expired. On a cache miss, `detect_key_rotation` runs and emits a `tracing::warn!` when the previously cached keys no longer appear in the upstream JWKS — but it does not flush the cache. A stolen private key rotated out on the IdP side is honoured by the validator for up to `jwks_cache_ttl_secs` (default 300 s) after rotation; no SIGHUP, no admin endpoint, no env-var flush flag.

<!-- source: crates/fraiseql-core/src/security/oidc/jwks.rs:L113-L161 — cache-hit returns key without consulting upstream; detect_key_rotation only warns -->
<!-- source: crates/fraiseql-core/src/security/oidc/providers.rs:L147-L150 — default_jwks_cache_ttl = 300 secs -->

**Mitigation:** after rotating a compromised key on the IdP side, restart every FraiseQL replica. If the IdP supports an explicit `revoke_published` annotation, set the TTL lower (`jwks_cache_ttl_secs = 60`) at the cost of higher discovery traffic. Otherwise treat the cache TTL as the maximum stolen-key replay window.

### 6. FW-24 [#356](https://github.com/fraiseql/fraiseql/issues/356) — brute-force protection silently dropped (security)

The CLI TOML schema `RateLimitingSecurityConfig` accepts `failed_login_max_attempts` and `failed_login_lockout_secs`; the server runtime mirror `RateLimitConfig` has neither. Serde silently drops the keys. A whole-server grep for `failed_logins` returns zero hits — the `fraiseql-auth::AuthRateLimiters` type exists in a sibling crate but is never instantiated by `fraiseql-server`. Brute-force lockout via `[security.rate_limiting]` is a no-op at v2.3.2.

<!-- source: crates/fraiseql-cli/src/config/toml_schema/security.rs:L181-L249 — CLI schema accepts failed_login_max_attempts / failed_login_lockout_secs -->
<!-- source: crates/fraiseql-server/src/middleware/rate_limit/config.rs:L7-L52 — server runtime mirror has no failed_login_* fields -->

**Mitigation:** rate-limit auth endpoints (`/auth/start`, `/auth/callback`, `/auth/v1/*`, `/graphql` for token-bearing requests) at the reverse proxy or CDN layer until the field is wired in the server runtime.

### 7. FW-25 [#357](https://github.com/fraiseql/fraiseql/issues/357) — token revocation `backend = "postgres"` silently downgrades (regression)

The CLI TOML schema accepts `backend = "memory" | "redis" | "postgres"`. The server's `revocation_manager_from_schema` match arms cover `memory` (and `env`) and `redis`; `postgres` lands in the catch-all `warn!(backend = %other, "Unknown revocation backend — falling back to in-memory")` arm. A CLI-validated `backend = "postgres"` deployment silently runs in-memory single-instance ephemeral, no cross-replica revoke contract.

<!-- source: crates/fraiseql-cli/src/config/toml_schema/security.rs:L463-L501 — CLI accepts "memory" | "redis" | "postgres" -->
<!-- source: crates/fraiseql-server/src/token_revocation.rs:L399-L437 — server arms cover memory + redis only; postgres → "Unknown" warn + fallback -->

**Mitigation:** use `backend = "redis"` for persistent revocation across replicas at v2.3.2. The Redis store survives restart and replicates across replicas. Avoid `backend = "postgres"` until the upstream fix lands.

### 8. Compiled-schema indirection — `[security.*]` requires `fraiseql-cli compile`

API keys, token revocation, PKCE, state encryption, and per-endpoint rate limiting all live under `[security.*]` in `fraiseql.toml`. The binary does not read `[security.*]` from `ServerConfig`; it reads from `schema.compiled.json` under `schema.security.additional["<subsystem>"]`. A TOML edit alone is a silent no-op — the compile step has to run for the runtime to see the change. (`[auth]` and `[auth_hs256]` are the exceptions: they live directly on `ServerConfig` and are read at every startup.)

<!-- source: crates/fraiseql-server/src/api_key.rs:L237-L251 — api_key_authenticator_from_schema reads schema.security.additional["api_keys"] -->
<!-- source: crates/fraiseql-server/src/token_revocation.rs:L384-L390 — revocation_manager_from_schema reads schema.security.additional["token_revocation"] -->
<!-- source: crates/fraiseql-server/src/server/initialization.rs:L44-L82 — pkce_store_from_schema reads schema.security.additional["pkce"] -->

### 9. OIDC `audience` is mandatory — the framework refuses to boot without it

For the OIDC path, `OidcConfig::validate()` returns `SecurityConfigError("OIDC audience is REQUIRED for security. Set 'audience' in auth config to your API identifier. This prevents token confusion attacks ...")` if `audience` and `additional_audiences` are both empty. Boot will fail. This is the enforcement caveat 3 above wants HS256 to acquire.

<!-- source: crates/fraiseql-core/src/security/oidc/providers.rs:L290-L320 — validate() refuses boot when audience + additional_audiences both empty -->
<!-- source: crates/fraiseql-core/src/security/oidc/providers.rs:L45-L73 — audience field SECURITY CRITICAL doc comment -->

### 10. Algorithm allowlist defaults to `["RS256"]` — keep it that way

`default_algorithms()` returns `vec!["RS256".to_string()]`. The validator enforces this list at `get_algorithm`: `if !self.config.allowed_algorithms.contains(&alg_str) { return Err(SecurityError::InvalidTokenAlgorithm) }`. Algorithm-confusion attacks (presenting an HS256-signed token to an RS256-only validator) return 401. Do not widen the allowlist to include `HS256` from a JWKS-only OIDC setup — that opens the algorithm-confusion attack with the JWKS public key as the HMAC secret.

<!-- source: crates/fraiseql-core/src/security/oidc/providers.rs:L152-L154 — default_algorithms() returns ["RS256"] -->
<!-- source: crates/fraiseql-core/src/security/oidc/token.rs:L355-L368 — get_algorithm enforces allowlist; returns InvalidTokenAlgorithm -->

### 11. `trust_proxy_headers` requires `trusted_proxy_cidrs`

`trust_proxy_headers = true` without a non-empty `trusted_proxy_cidrs` allows any client to spoof `X-Forwarded-For` and bypass per-IP rate limits. The server logs a startup warning (`"Rate limiter: trust_proxy_headers = true but trusted_proxy_cidrs is not set. Any client can spoof X-Forwarded-For ..."`) but does not refuse to boot.

<!-- source: crates/fraiseql-server/src/server/initialization.rs:L205-L213 — trust_proxy_headers warning -->

`/auth/me` carries its own footgun worth knowing: the response unconditionally includes `email` and `display_name` when present on the validated user, regardless of `expose_claims`. The `expose_claims` allowlist controls only **extra** claims. Listing an arbitrary claim name (for example, `expose_claims = ["password"]`) against a token that carries that claim will return it — the framework treats the allowlist as opt-in inclusion, not as a privacy filter. Validate the allowlist against your token shape.

<!-- source: crates/fraiseql-server/src/routes/auth.rs:L432-L460 — auth_me handler: always-include email/display_name; expose_claims iterates user.extra_claims -->

## Quick reference

| Aspect | Value at v2.3.2 |
|---|---|
| OIDC validator | `[auth]` (direct-TOML on `ServerConfig.auth: Option<OidcConfig>`) <!-- source: crates/fraiseql-server/src/server_config/mod.rs:L293-L307 --> |
| HS256 validator | `[auth_hs256]` (direct-TOML on `ServerConfig.auth_hs256: Option<Hs256Config>`); mutually exclusive with `[auth]` <!-- source: crates/fraiseql-server/src/server_config/hs256.rs:L11-L39 --> |
| `/auth/me` session-identity endpoint | `[auth.me]` (rides on `[auth]` OIDC); requires `oidc_validator` to be present <!-- source: crates/fraiseql-core/src/security/oidc/providers.rs:L25-L41 --> <!-- source: crates/fraiseql-server/src/server/routing/auth.rs:L81-L101 --> |
| API key authentication | `[security.api_keys]` (compile-step; consumed from `schema.security.additional["api_keys"]`) <!-- source: crates/fraiseql-server/src/api_key.rs:L237-L251 --> |
| Token revocation | `[security.token_revocation]` (compile-step); backends actually wired: `memory`, `redis` (FW-25 — `postgres` silently downgrades) <!-- source: crates/fraiseql-server/src/token_revocation.rs:L384-L437 --> |
| PKCE OAuth2 flow | `[security.pkce]` (compile-step); requires `[auth]` + `oidc_server_client`; S256 default <!-- source: crates/fraiseql-cli/src/config/toml_schema/security.rs:L309-L316 --> <!-- source: crates/fraiseql-server/src/server/routing/auth.rs:L26-L46 --> |
| State encryption | `[security.state_encryption]` (compile-step); ChaCha20-Poly1305 or AES-256-GCM; key from `STATE_ENCRYPTION_KEY` env var <!-- source: crates/fraiseql-cli/src/config/toml_schema/security.rs:L284-L306 --> |
| Per-endpoint rate limiting | `[security.rate_limiting]` (compile-step); auth_start / auth_callback / auth_refresh dispatch <!-- source: crates/fraiseql-server/src/middleware/rate_limit/config.rs:L7-L52 --> |
| Algorithm allowlist | `[auth] allowed_algorithms`; defaults to `["RS256"]` <!-- source: crates/fraiseql-core/src/security/oidc/providers.rs:L152-L154 --> |
| JWKS cache TTL | `[auth] jwks_cache_ttl_secs`; default `300` s (S-class hardening) <!-- source: crates/fraiseql-core/src/security/oidc/providers.rs:L147-L150 --> |
| Cookie format on PKCE callback | `__Host-access_token="..."; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=<expires_in or 300>` <!-- source: crates/fraiseql-server/src/routes/auth.rs:L220-L246 --> |
| Required Cargo features for PKCE state in Redis / revocation in Redis | `redis-pkce`, `redis-rate-limiting` (used by both PKCE store and token revocation) <!-- source: crates/fraiseql-server/src/token_revocation.rs:L399-L406 --> |

## How auth is composed today

Two configuration shapes coexist and the difference matters more on this page than anywhere else in the docs. The binary auto-wires the OIDC and HS256 validators directly from `fraiseql.toml`; every other auth subsystem reads from the compiled schema and is silent on raw TOML.

### Direct-TOML (auto-wired) — `[auth]`, `[auth_hs256]`, `[auth.me]`

`ServerConfig` declares `auth: Option<OidcConfig>` and `auth_hs256: Option<Hs256Config>` directly. The constructor instantiates the validators at startup; no compile step required. `/auth/me` rides on top of `[auth]` (it requires an OIDC validator) — toggle it with `[auth.me] enabled = true`.

<!-- source: crates/fraiseql-server/src/server_config/mod.rs:L40-L42 — ServerConfig struct; no #[serde(deny_unknown_fields)] -->
<!-- source: crates/fraiseql-server/src/server_config/mod.rs:L293-L307 — auth field of type optional OidcConfig with doc comment -->

```toml title="fraiseql.toml — OIDC auto-wired"
# Required for production. Validator refuses to boot if `audience` is unset.
[auth]
issuer = "https://your-tenant.auth0.com/"
audience = "https://api.example.com"   # SECURITY CRITICAL — see caveat 9
# allowed_algorithms = ["RS256"]       # default; do not widen (caveat 10)
# jwks_cache_ttl_secs = 300            # default; tighten only if your IdP supports fast rotation

[auth.me]                              # opt-in; rides on [auth]
enabled = true
expose_claims = ["tenant_id", "https://myapp.com/role"]
```

```toml title="fraiseql.toml — HS256 for tests"
# Use ONLY for integration tests and trusted internal traffic.
# Mutually exclusive with [auth].
[auth_hs256]
secret_env = "FRAISEQL_HS256_SECRET"   # value never goes in TOML
issuer = "my-test-suite"
audience = "my-api"                    # NOT enforced by framework — see caveat 3
```

When both `[auth]` and `[auth_hs256]` are present, the OIDC validator wins; the HS256 builder still runs but its validator is overshadowed by the OIDC middleware on auth-guarded routes. Pick one per environment.

<!-- source: crates/fraiseql-server/src/server/builder.rs:L308-L319 — OIDC validator instantiated when config.auth.is_some() -->
<!-- source: crates/fraiseql-server/src/server/builder.rs:L19-L39 — build_hs256_auth returns Some(AuthMiddleware) when [auth_hs256] is configured -->

### Compile-step indirection — `[security.*]`

API keys, token revocation, PKCE (and its state encryption and OIDC client dependencies), and per-endpoint rate limiting all flow through `fraiseql-cli compile`. The CLI validates the `[security.*]` blocks against its own schema, then writes them into `schema.compiled.json` under `schema.security.additional["<subsystem>"]`. The server reads from there at startup. A raw `[security.api_keys]` block in `fraiseql.toml` without a recompile is silently ignored — `ServerConfig` has no `security` field for the server to see.

<!-- source: crates/fraiseql-server/src/api_key.rs:L237-L251 — api_key_authenticator_from_schema reads compiled schema, not ServerConfig -->
<!-- source: crates/fraiseql-server/src/token_revocation.rs:L384-L390 — revocation_manager_from_schema reads compiled schema -->
<!-- source: crates/fraiseql-server/src/server/initialization.rs:L22-L82 — state_encryption_from_schema + pkce_store_from_schema read compiled schema -->
<!-- source: crates/fraiseql-server/src/server/initialization.rs:L192-L260 — rate_limiter_from_schema reads compiled schema -->

```bash title="Compile + boot — the only path that wires [security.*]"
fraiseql-cli compile --output schema.compiled.json
fraiseql-server --config fraiseql.toml
```

When `[security.*]` changes in TOML, re-run `fraiseql-cli compile` and restart the server. The build pipeline should do this in the same step the server image rolls out; otherwise an operator-edited TOML lands without effect.

## JWT and OIDC

The OIDC validator validates incoming JWTs against the issuer's JWKS document. It runs at every request through `oidc_auth_middleware`, which prefers an `Authorization: Bearer <token>` header and falls back to the `__Host-access_token` HttpOnly cookie set by `/auth/callback` (see [PKCE OAuth2 flow](#pkce-oauth2-flow)).

<!-- source: crates/fraiseql-server/src/middleware/oidc_auth.rs:L48-L62 — extract_access_token_cookie -->
<!-- source: crates/fraiseql-server/src/middleware/oidc_auth.rs:L83-L97 — oidc_auth_middleware doc comment: Bearer header → cookie fallback -->

### Algorithms, JWKS, audience

`OidcConfig` exposes the full validation surface:

| Field | Type | Default | Notes |
|---|---|---|---|
| `issuer` | `String` | empty (required) | Must match `iss` claim exactly; HTTPS required except `localhost`/`127.0.0.1`. <!-- source: crates/fraiseql-core/src/security/oidc/providers.rs:L52-L60 --> |
| `audience` | `Option<String>` | `None` (required) | Mandatory — boot fails without it (caveat 9). Set to your API identifier (Auth0: API audience). <!-- source: crates/fraiseql-core/src/security/oidc/providers.rs:L58-L73 --> |
| `additional_audiences` | `Vec<String>` | `[]` | Either `audience` or this must be non-empty. |
| `allowed_algorithms` | `Vec<String>` | `["RS256"]` | Algorithm-confusion mitigation (caveat 10). <!-- source: crates/fraiseql-core/src/security/oidc/providers.rs:L152-L154 --> |
| `jwks_cache_ttl_secs` | `u64` | `300` | Stolen-key replay window (caveat 5). <!-- source: crates/fraiseql-core/src/security/oidc/providers.rs:L147-L150 --> |
| `clock_skew_secs` | `u64` | `60` | Capped at `MAX_CLOCK_SKEW_SECS = 300` regardless of config. <!-- source: crates/fraiseql-core/src/security/oidc/providers.rs:L160-L165 --> |
| `me` | `Option<MeEndpointConfig>` | `None` | Opt-in; see [`/auth/me`](#authme-session-identity-endpoint). |

Provider-specific constructors exist for Auth0, Keycloak, Okta, Cognito, and Azure AD; they fill in `issuer` and `audience` from supplied tenant / domain values and return a populated `OidcConfig`.

<!-- source: crates/fraiseql-core/src/security/oidc/providers.rs:L172-L260 — per-provider constructors -->

### Nested-claims extraction (`jwt:email`, `jwt:name`)

JWTs from Azure AD ship `email` as a string and `name` as a string; OIDC core ships `name` as either a string or `{"given": ..., "family": ...}`; some IdPs nest the email under `{"value": ..., "verified": true}`. The validator normalises both into single strings exposed on the `SecurityContext` as `email` and `display_name`. RLS policies access these through the session-variable mappings `jwt:email`, `jwt:name`, and `jwt:display_name`.

<!-- source: crates/fraiseql-core/src/security/security_context.rs:L115-L127 — email + display_name fields; mapped to jwt:email / jwt:name / jwt:display_name -->

### RLS session variables

The compiled schema maps JWT claims to PostgreSQL session variables (`SET LOCAL "jwt.<name>" = ...`) consumed by RLS policies. The always-defined keys are `jwt:sub` (always present), `jwt:email`, `jwt:name`, `jwt:display_name` (when extractable from the token). Additional custom claims are injected per-query via `inject={"sql_param": "jwt:<claim>"}` in your Python schema definition; the Rust runtime reads the verified claim and passes it to the SQL view as a parameter — the value is never supplied by the client.

### Cookie-based session

The `oidc_auth_middleware` accepts the JWT from either header or cookie. The cookie path is the browser flow that `/auth/callback` produces (see [PKCE OAuth2 flow](#pkce-oauth2-flow)). The cookie is named `__Host-access_token`, attribute-locked to `Path=/; HttpOnly; Secure; SameSite=Strict`. The framework hard-codes no `Domain=` attribute; the `__Host-` prefix instructs browsers to reject any cookie with a `Domain=` attribute, so an upstream reverse proxy MUST NOT rewrite the cookie to add one.

<!-- source: crates/fraiseql-server/src/routes/auth.rs:L220-L246 — cookie format hard-coded without Domain= -->

### `/auth/me` session identity endpoint

`[auth.me] enabled = true` mounts `GET /auth/me` behind `oidc_auth_middleware`. The handler returns a JSON object with three always-present fields — `sub`, `user_id` (an alias for `sub`), `expires_at` — plus `email` and `display_name` when the validator extracted them from the token, plus every claim in the operator-supplied `expose_claims` allowlist that is also present on the token.

<!-- source: crates/fraiseql-server/src/routes/auth.rs:L432-L460 — auth_me handler implementation -->

```bash title="GET /auth/me"
curl -fsS http://localhost:8080/auth/me \
  -H "Authorization: Bearer $TOKEN"
# {"sub":"auth0|abc","user_id":"auth0|abc","expires_at":"2026-05-30T...",
#  "email":"alice@example.com","tenant_id":"acme"}
```

Listing `user_id` in `expose_claims` is silently a no-op — the alias is server-side and there is no `user_id` claim on the token. Listing an arbitrary claim name (`"password"`, `"ssn"`) against a token that carries that claim WILL return it — `expose_claims` is opt-in inclusion, not a privacy filter. See caveat 11.

## HS256 testing mode

The HS256 validator is intended for integration tests and trusted internal traffic. It validates JWTs with a shared symmetric secret loaded from an environment variable at startup. No JWKS fetch, no network. Mutually exclusive with `[auth]`.

<!-- source: crates/fraiseql-server/src/server_config/hs256.rs:L24-L39 — Hs256Config fields -->

```toml title="fraiseql.toml — HS256 walk-through"
[auth_hs256]
secret_env = "FRAISEQL_HS256_SECRET"
issuer = "my-test-suite"
audience = "my-api"                    # operator-required; framework does not enforce (caveat 3)
```

```bash title="boot + mint + call"
export FRAISEQL_HS256_SECRET="$(openssl rand -base64 32)"
fraiseql-server --config fraiseql.toml &

# Mint a token (jwt-cli or equivalent)
TOKEN=$(jwt encode \
  --secret "$FRAISEQL_HS256_SECRET" \
  --alg HS256 \
  --iss my-test-suite \
  --aud my-api \
  --sub user-1 \
  '{}')

# Call a protected query
curl -fsS http://localhost:8080/graphql \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query":"{ me { sub } }"}'
```

When `audience` is unset the framework still boots; presented tokens are not audience-checked. **Set `audience` regardless of what the framework lets you get away with** (caveat 3).

<!-- source: crates/fraiseql-server/src/server/builder.rs:L26-L33 — audience only set when hs.audience.is_some() -->

## API keys

`[security.api_keys]` configures static API keys with SHA-256-hashed storage and constant-time comparison. The CLI shape lives in `crates/fraiseql-cli/src/config/toml_schema/security.rs:L358-L399`; the server reads it from the compiled schema at startup. Each request presents the key via an operator-named header (default `X-API-Key`); the authenticator strips an optional `Bearer ` prefix, hashes the bytes, and compares with `subtle::ConstantTimeEq`. Static keys are loaded from environment variables; the postgres-backed key store is declared in the CLI schema but not wired in the server runtime at v2.3.2.

<!-- source: crates/fraiseql-server/src/api_key.rs:L186-L196 — sha256_hash + ConstantTimeEq comparison -->
<!-- source: crates/fraiseql-server/src/api_key.rs:L213-L222 — sha256_hash impl -->
<!-- source: crates/fraiseql-server/src/api_key.rs:L237-L251 — api_key_authenticator_from_schema -->

```toml title="fraiseql.toml — API keys (becomes schema.security.additional[\"api_keys\"] after compile)"
[security.api_keys]
enabled = true
header_name = "X-API-Key"

[[security.api_keys.static_keys]]
name = "metrics-scraper"
hash_env = "FRAISEQL_APIKEY_METRICS_HASH"   # value: sha256 hex of the actual key
scopes = ["metrics:read"]
```

```bash title="generate the hash, set env, call"
# Generate a key (never stored in TOML or git)
KEY="$(openssl rand -base64 32)"

# Compute SHA-256 hex (sha256:<hex>)
echo -n "$KEY" | sha256sum
# 1d5f...   (the hex prefix; SECRET stays out of logs)

export FRAISEQL_APIKEY_METRICS_HASH="<the hex above>"
fraiseql-server --config fraiseql.toml &

curl -fsS http://localhost:8080/graphql \
  -H "X-API-Key: $KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"{ posts { id } }"}'
```

The authenticator returns `ApiKeyResult::Authenticated` with a `SecurityContext` whose `user_id` is `apikey:<name>` and whose scopes are the configured `scopes` list. Field-level scope checks against the JWT path see this context identically.

<!-- source: crates/fraiseql-server/src/api_key.rs:L226-L235 — build_security_context -->

## PKCE OAuth2 flow

`[security.pkce]` mounts `GET /auth/start` and `GET /auth/callback`. `/auth/start` redirects the browser to the IdP with a generated PKCE challenge (S256 by default; `plain` warns); `/auth/callback` consumes the verifier, exchanges the code at the IdP, sets the `__Host-access_token` cookie, and redirects to a configured post-login URI.

<!-- source: crates/fraiseql-server/src/server/routing/auth.rs:L26-L46 — PKCE routes mounted on (pkce_store, oidc_server_client) -->
<!-- source: crates/fraiseql-server/src/routes/auth.rs:L114 — pub async fn auth_start -->
<!-- source: crates/fraiseql-server/src/routes/auth.rs:L168 — pub async fn auth_callback -->

The state token is stored server-side in `PkceStateStore` (in-memory by default; Redis under feature `redis-pkce`). When `[security.state_encryption]` is configured, the outbound state token is the AEAD-encrypted lookup key; otherwise it is the raw lookup key (CSRF protection still holds, but the state is unencrypted — see caveat 4).

<!-- source: crates/fraiseql-server/src/server/initialization.rs:L44-L112 — pkce_store_from_schema; Redis path under #[cfg(feature = "redis-pkce")] -->

```toml title="fraiseql.toml — PKCE + state encryption (becomes schema.security.* after compile)"
[security.state_encryption]
enabled = true
algorithm = "chacha20-poly1305"
# Key sourced from STATE_ENCRYPTION_KEY env var; do NOT put it in TOML.

[security.pkce]
enabled = true
code_challenge_method = "S256"   # default; never set to "plain" in production
state_ttl_secs = 600
# redis_url = "redis://redis:6379"  # required for multi-replica deployments
```

```bash title="boot + cookie"
export STATE_ENCRYPTION_KEY="$(openssl rand -base64 32)"
fraiseql-cli compile
fraiseql-server --config fraiseql.toml &

# Browser flow: GET /auth/start in a browser → IdP → GET /auth/callback?code=...&state=...
# After callback the response is a 303 Redirect with:
#   Set-Cookie: __Host-access_token="<jwt>"; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=...
```

## Token revocation

`[security.token_revocation]` mounts `POST /auth/revoke` and `POST /auth/revoke-all`. **Both routes are unauthenticated at v2.3.2 (caveat 2 — FW-26 #358) — gate them at the reverse proxy or do not mount revocation at all.** The manager checks `jti` on every validated token; revoked `jti`s return 401 on subsequent presentation.

| Backend | Status at v2.3.2 | Cargo feature |
|---|---|---|
| `memory` | wired; in-process; lost on restart | (none — always available) |
| `redis` | wired; survives restart; cross-replica | `redis-rate-limiting` |
| `postgres` | declared by CLI but **silently downgrades to memory** (caveat 7 — FW-25 #357) | (n/a) |

<!-- source: crates/fraiseql-server/src/token_revocation.rs:L399-L437 — backend match arms -->

```toml title="fraiseql.toml — token revocation (compile-step)"
[security.token_revocation]
enabled = true
backend = "redis"
redis_url = "redis://redis:6379"
require_jti = true
fail_open = false
```

The `require_jti` setting controls whether tokens without a `jti` claim are accepted; defaults to `true`. `fail_open` controls behaviour when the revocation backend is unavailable (`false` → reject; `true` → allow — only set `true` if you understand the operational consequence).

## Rate limiting on auth endpoints

`[security.rate_limiting]` mounts per-endpoint dispatchers covering `/auth/start`, `/auth/callback`, `/auth/refresh`, `/auth/logout`. Per-IP limits guard the public endpoints (`auth_start`, `auth_callback`); per-user limits guard authenticated endpoints (`auth_refresh`, `auth_logout`). The Redis backend is required for cross-replica accounting; the in-memory backend is correct only on single-instance deployments.

<!-- source: crates/fraiseql-server/src/middleware/rate_limit/config.rs:L7-L52 — RateLimitConfig struct -->
<!-- source: crates/fraiseql-server/src/middleware/rate_limit/in_memory.rs:L59-L100 — per-endpoint dispatch -->
<!-- source: crates/fraiseql-server/src/server/initialization.rs:L192-L260 — rate_limiter_from_schema -->

```toml title="fraiseql.toml — per-endpoint auth rate limits"
[security.rate_limiting]
enabled = true
trust_proxy_headers = false   # see caveat 11
# trusted_proxy_cidrs = ["10.0.0.0/8"]   # required if trust_proxy_headers = true

auth_start_max_requests    = 100
auth_start_window_secs     = 60
auth_callback_max_requests = 50
auth_callback_window_secs  = 60
auth_refresh_max_requests  = 10
auth_refresh_window_secs   = 60
auth_logout_max_requests   = 20
auth_logout_window_secs    = 60
```

The CLI schema also accepts `failed_login_max_attempts` and `failed_login_lockout_secs`, but **the server runtime drops both keys silently (caveat 6 — FW-24 #356)**. Brute-force lockout via `[security.rate_limiting]` is a no-op at v2.3.2; enforce it at your reverse proxy until the fields are wired in the server runtime.

## Cookie security

The PKCE callback handler sets the cookie with the exact attribute string:

```text
__Host-access_token="<token-escaped>"; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=<expires_in or 300>
```

The token value is RFC 6265 quoted-string-escaped (`\` and `"` each get a leading `\`) and wrapped in double quotes; the cookie name carries the `__Host-` prefix; no `Domain=` attribute is emitted. Browsers reject any `__Host-`-prefixed cookie that carries `Domain=` — so an upstream reverse proxy that rewrites cookies to add `Domain=` will break the auth path entirely.

<!-- source: crates/fraiseql-server/src/routes/auth.rs:L233-L237 — token value RFC 6265 quoted-string escape (\ and ") -->
<!-- source: crates/fraiseql-server/src/routes/auth.rs:L236-L240 — cookie attribute string hard-coded; no Domain= -->

The reading side of the cookie (`extract_access_token_cookie`) strips the surrounding double quotes before validation and accepts the cookie under any `Cookie:` header position. Combined with the writing side, an OIDC ID-token claim containing CRLF cannot escape the cookie value because the token is URL-safe-base64 and the writer escapes the remaining metacharacters.

<!-- source: crates/fraiseql-server/src/middleware/oidc_auth.rs:L48-L62 — extract_access_token_cookie strips quotes -->

## Worked example

The companion script `scripts/docs-test/pages/authentication.docs-test.sh` exercises the HS256-direct-TOML path against the docs-test stack, then asserts the documented FW-24 / FW-25 / FW-26 / FW-27 / FW-28 / FW-29 symptoms still reproduce against the frozen FraiseQL SHA.

1. Boot `fraiseql-server` with `[auth_hs256]` from the overlay; `FRAISEQL_HS256_SECRET` injected into the container env.
2. Mint a valid HS256 token; verify `GET /graphql` (introspection) succeeds.
3. Tamper one byte of the signature; verify the same query returns 401.
4. Configure `[security.token_revocation] backend = "redis"` via the compiled-schema fixture; revoke the `jti`; verify subsequent use fails closed.
5. Re-grep the JWKS / cookie / API-key paths at the frozen SHA to assert the documented library APIs remain source-true.
6. Run each `authentication.bug-{1..4}.sh` repro and require exit code 1 (BUG REPRODUCED) at the frozen SHA.
7. Stack down clean.

The script does not exercise the full PKCE/OIDC happy path because the docs-test Compose stack has no OIDC stub container. Instead it source-greps `pkce_store_from_schema` for the warn-and-continue shape and reproduces FW-28 directly; when an OIDC stub is added to the harness in a future cycle this branch will flip to driving `/auth/start` → `/auth/callback` end-to-end. When a framework fix removes one of the documented symptoms, the corresponding assertion will exit 1 — the regression signal that unblocks the binary-driven happy path.

## Migration from the v2.2 page

:::caution[Previous version: `@authenticated` decorator and `[security.enterprise]`]
The prior revision of this page documented a Python `@authenticated` / `@fraiseql.requires_scope(...)` decorator API, an OIDC configuration via `OIDC_*` environment variables only, a `[security.enterprise]` audit-logging block, and `[security.error_sanitization]` / `[security.rate_limiting]` blocks set against `fraiseql.toml` directly. None of these match the v2.3.2 framework verbatim — they over-state direct-TOML and under-state compile-step indirection.
:::

What changed:

- The `@authenticated` Python decorator and `actions=[...]` kwargs are gone. Field-level access control is declared via `fraiseql.field(requires_scope=...)` inside `@fraiseql.type` and baked into the compiled schema; the Rust runtime enforces it.
- `OIDC_ISSUER_URL` / `OIDC_CLIENT_ID` / `OIDC_CLIENT_SECRET` / `OIDC_REDIRECT_URI` environment variables are not how the framework reads its OIDC config. The OIDC validator reads `[auth]` from `fraiseql.toml` via `ServerConfig.auth: Option<OidcConfig>`. Provider-specific constructors (`OidcConfig::auth0`, `::keycloak`, `::okta`, `::cognito`, `::azure_ad`) exist for convenience but they populate the same struct.
- The new `[auth_hs256]` block is the testing path. The pre-v2.2 docs had no equivalent.
- `[security.enterprise]` audit logging is not a top-level v2.3.2 block; audit-related controls live under `[security.*]` subsystems and consume the compiled-schema path.
- `[security.rate_limiting] failed_login_max_attempts` is documented elsewhere as enforced; at v2.3.2 it is silently dropped (FW-24 #356).
- `[security.token_revocation] backend = "postgres"` is documented elsewhere as supported; at v2.3.2 it silently downgrades to memory (FW-25 #357).
- `/auth/revoke` is documented elsewhere as a self-service logout endpoint; at v2.3.2 it is unauthenticated (FW-26 #358).

## Known issues

Six framework issues are open against the v2.3.2 authentication surface. Plan around them.

| ID | Symptom | Workaround |
|---|---|---|
| FW-24 [#356](https://github.com/fraiseql/fraiseql/issues/356) | `[security.rate_limiting] failed_login_max_attempts` / `failed_login_lockout_secs` are accepted by the CLI but silently dropped by the server runtime. Brute-force lockout via `[security.rate_limiting]` is a no-op. | Enforce brute-force lockout at the reverse proxy or CDN layer until the field is wired. See [caveat 6](#6-fw-24-356--brute-force-protection-silently-dropped-security). |
| FW-25 [#357](https://github.com/fraiseql/fraiseql/issues/357) | `[security.token_revocation] backend = "postgres"` silently downgrades to in-memory single-instance ephemeral storage. No cross-replica revocation, lost on restart. | Use `backend = "redis"` for production. See [caveat 7](#7-fw-25-357--token-revocation-backend--postgres-silently-downgrades-regression). |
| FW-26 [#358](https://github.com/fraiseql/fraiseql/issues/358) (critical) | `POST /auth/revoke` and `POST /auth/revoke-all` are mounted without any auth middleware. Anonymous clients can revoke any harvested JWT or wipe every active session for any known username. | Gate `/auth/revoke*` behind an authenticating reverse proxy, or omit `[security.token_revocation]` from the compiled schema. See [caveat 2](#2-fw-26-358--authrevoke-and-authrevoke-all-are-unauthenticated-critical). |
| FW-27 [#359](https://github.com/fraiseql/fraiseql/issues/359) | HS256 boot without `audience` configured succeeds; presented tokens are not audience-checked. Cross-service token confusion attack open for the shared-secret path. | Always set `[auth_hs256] audience = "..."`. See [caveat 3](#3-fw-27-359--hs256-audience-is-not-enforced-by-the-framework-security). |
| FW-28 [#360](https://github.com/fraiseql/fraiseql/issues/360) | PKCE with `state_encryption` disabled warns once at startup and continues; the outbound `state` token is the raw internal lookup key. Documented contract "PKCE refuses without state encryption" is not met. | Configure `[security.state_encryption]` with `STATE_ENCRYPTION_KEY` before enabling `pkce.enabled = true`. See [caveat 4](#4-fw-28-360--pkce-warns-but-continues-without-state-encryption-security). |
| FW-29 [#361](https://github.com/fraiseql/fraiseql/issues/361) | JWKS cache holds rotated-out keys for up to `jwks_cache_ttl_secs` after the IdP rotates them. `detect_key_rotation` warns but does not flush. Stolen-key replay window equals the cache TTL. | After rotating a compromised key at the IdP, restart every replica. Tighten `jwks_cache_ttl_secs` if your IdP supports it. See [caveat 5](#5-fw-29-361--jwks-hot-rotate-window-equals-the-cache-ttl-security). |

## Pointers

- **Auth Extensions** (magic links, TOTP, SMS OTP, social, anonymous signup, account linking) — the `auth/v1/*` route family is mounted by the same `mount_auth_routes` function documented here; the dedicated extension pages cover the TOML shapes and the dispatch surfaces. Cross-link landing: `/features/auth-extensions` (to be written).
- **OAuth providers reference** — per-provider quirks (Auth0 namespacing for custom claims, Keycloak realm roles, Okta groups, Cognito user-pool quirks, Azure AD `oid` vs `sub`) live in the reference page. The provider constructors at `crates/fraiseql-core/src/security/oidc/providers.rs:L172-L260` are the source of truth.
- **Federation authentication** — multi-replica deployments behind a federation gateway need consistent `[auth]` config across services and either a shared JWKS source or a per-service issuer + audience pair. The federation page covers mTLS, request signing, and the JWT-pinning patterns.
- **Multi-tenancy** — see the [Multi-tenancy guide](/building/multi-tenancy) for how the `tenant_id` JWT claim flows into the dispatch path and SQL session variables.

## Next steps

- [Multi-tenancy](/building/multi-tenancy) — the JWT `tenant_id` claim that feeds tenant dispatch.
- [Reference: TOML configuration](/reference/toml-config) — every `[auth]`, `[auth_hs256]`, `[auth.me]`, and `[security.*]` key.
- [Schema design](/building/schema-design) — `inject={"sql_param": "jwt:<claim>"}` patterns for JWT-claim-scoped queries.
