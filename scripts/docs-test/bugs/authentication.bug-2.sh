#!/usr/bin/env bash
#
# authentication.bug-2.sh — reproduction for HS256 missing-audience acceptance.
#
# `[auth_hs256]` boots cleanly with no `audience`; the resulting validator
# then accepts any token with any non-empty `aud` claim (cross-service token
# replay). The CHANGELOG and inline doc comments treat audience as a
# critical defence; the [auth_hs256] code path skips the defence.
#
# Filed: https://github.com/fraiseql/fraiseql/issues/359
# Registered: _internal/.plan/framework-qa-triage.md (FW-27)
#
# Persona: Bug-Finder (Opus 4.7), Phase 03 / Cycle 4 RED.
# Frozen FraiseQL SHA: d0a4ed4ec1770c70707f68fd9019f2b561d87461 (v2.3.2).
#
# Asymmetry with the OIDC `[auth]` path: OIDC's `OidcConfig::validate()`
# explicitly refuses to start when `audience` is None and
# `additional_audiences` is empty
# (crates/fraiseql-core/src/security/oidc/providers.rs:L290-L310).
# HS256 has no such guard.
#
# ============================================================================
# Expected (per CHANGELOG v2.3 entry "S40: JWT claims hardening" + the
# `OidcConfig.audience` doc comment in providers.rs:L59-L73 which marks
# audience as "SECURITY CRITICAL: This field is mandatory"):
#
#   Either the framework refuses to boot HS256 without an audience, or
#   the HS256 validator rejects every token whose `aud` doesn't match a
#   configured audience.
#
# Actual (at frozen SHA):
#
#   (a) Hs256Config (server_config/hs256.rs:L24-L39) declares:
#
#         #[derive(Debug, Clone, Serialize, Deserialize)]
#         pub struct Hs256Config {
#             pub secret_env: String,
#             #[serde(default)]
#             pub issuer: Option<String>,
#             #[serde(default)]
#             pub audience: Option<String>,
#         }
#
#       No `validate()` method, no guard.
#
#   (b) build_hs256_auth (server/builder.rs:L19-L39) only calls
#       `.with_audience(aud)` when `hs.audience.is_some()`. When None,
#       no audience is set on AuthConfig.
#
#   (c) AuthMiddleware::validate_token_with_signature
#       (auth_middleware/middleware.rs) only adds audience validation
#       when `self.config.audience.is_some()`:
#
#         if let Some(ref audience) = self.config.audience {
#             validation.set_audience(&[audience]);
#         }
#
#       Inline comment on the audience block:
#         "When no audience is pinned, any non-empty `aud` claim is
#          accepted -- callers should set `audience` in config to
#          restrict this further."
#
#       But no caller is required to set audience -- and the server
#       config makes it #[serde(default)] Option<String>.
#
#   (d) `jsonwebtoken::Validation::new(alg)` defaults to
#       `validate_aud = true`. When no audience is configured on
#       FraiseQL side, jsonwebtoken still walks the JWT's `aud` field
#       but accepts ANY value (including arbitrary attacker-chosen
#       service identifiers).
#
# Consequence (security severity, regression):
#
#   When an organisation runs two HS256-protected services A and B
#   that share a signing secret (common: test fixtures, internal
#   service mesh, monorepo CI), a token minted for A by a low-trust
#   component is accepted by B. The audience-confusion attack class
#   the v2.3 hardening (S40 + the OIDC audience-mandatory check)
#   was meant to close is open for the HS256 code path.
#
#   The mitigation is "operator remembers to set audience in
#   fraiseql.toml". The OIDC path enforces it; HS256 doesn't.
#
# Exit codes:
#   0  - bug NOT reproduced
#   1  - bug REPRODUCED
#   2  - environment problem
# ============================================================================

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
FRAISEQL_REPO="$(cd "$HERE"/../../../fraiseql && pwd)"
FRAISEQL_SHA="$(cat "$HERE/FRAISEQL_SHA")"

echo "================================================================"
echo "FW-27 reproduction -- HS256 accepts boot without audience"
echo "FraiseQL SHA: $FRAISEQL_SHA"
echo "================================================================"

if ! git -C "$FRAISEQL_REPO" cat-file -e "$FRAISEQL_SHA"; then
    echo "ERROR: frozen SHA $FRAISEQL_SHA not present in $FRAISEQL_REPO" >&2
    exit 2
fi

HS256_CFG=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/server_config/hs256.rs")
BUILDER=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/server/builder.rs")
AUTHMW=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-core/src/security/auth_middleware/middleware.rs")
OIDC_PROV=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-core/src/security/oidc/providers.rs")

# (a) Hs256Config has audience: Option<String> with #[serde(default)], no validate().
echo
echo "-- Hs256Config field shape --"
printf '%s\n' "$HS256_CFG" | grep -nE 'audience|fn validate|impl Hs256Config' | head -10

if ! printf '%s\n' "$HS256_CFG" | grep -qE 'audience:\s*Option<String>'; then
    echo "BUG NOT REPRODUCED: Hs256Config.audience is no longer Option<String>." >&2
    exit 0
fi
if printf '%s\n' "$HS256_CFG" | grep -qE 'fn validate'; then
    echo "BUG NOT REPRODUCED: Hs256Config now has a validate() that may enforce audience." >&2
    exit 0
fi

# (b) build_hs256_auth only sets audience when it's Some.
echo
echo "-- build_hs256_auth audience-handling --"
build_block=$(printf '%s\n' "$BUILDER" | awk '/fn build_hs256_auth/,/^}/' | head -30)
printf '%s\n' "$build_block"

if ! printf '%s\n' "$build_block" | grep -q 'if let Some(ref aud) = hs.audience'; then
    echo "BUG NOT REPRODUCED: build_hs256_auth audience handling changed." >&2
    exit 0
fi
if printf '%s\n' "$build_block" | grep -qE 'ConfigError.*audience|return.*audience'; then
    echo "BUG NOT REPRODUCED: build_hs256_auth now refuses missing audience." >&2
    exit 0
fi

# (c) AuthMiddleware skips set_audience when config.audience is None
echo
echo "-- AuthMiddleware audience-validation block (the doc-disclaimed gap) --"
mw_block=$(printf '%s\n' "$AUTHMW" | awk '/validate_token_with_signature/,/Validation::new/' | head -30)
printf '%s\n' "$AUTHMW" | grep -nB1 -A3 'set_audience' | head -15

if ! printf '%s\n' "$AUTHMW" | grep -q 'if let Some(ref audience) = self.config.audience'; then
    echo "BUG NOT REPRODUCED: AuthMiddleware audience-conditional changed." >&2
    exit 0
fi

# (d) Show that the OIDC path DOES enforce audience -- the asymmetry.
echo
echo "-- OIDC validate() audience guard (the contrast) --"
printf '%s\n' "$OIDC_PROV" | awk '/fn validate/,/^    }/' | grep -nA2 'audience' | head -20

if ! printf '%s\n' "$OIDC_PROV" | grep -q 'OIDC audience is REQUIRED'; then
    echo "WARN: OIDC audience-mandatory guard shape changed; the asymmetry may have closed." >&2
fi

cat <<'MSG'

================================================================
Bug-shape assertion:
================================================================
- Hs256Config (server_config/hs256.rs:L37-L39) declares
  `audience: Option<String>` with `#[serde(default)]` and has NO
  validate() method. An operator can boot [auth_hs256] with only
  `secret_env` set; the binary loads cleanly.
- build_hs256_auth (server/builder.rs:L26-L31) only calls
  `.with_audience(...)` when `hs.audience.is_some()`. When None,
  AuthConfig.audience stays None.
- AuthMiddleware (auth_middleware/middleware.rs near
  validate_token_with_signature) only calls
  `validation.set_audience(...)` when `config.audience.is_some()`.
- The inline comment in middleware.rs admits:
    "When no audience is pinned, any non-empty `aud` claim is
     accepted -- callers should set `audience` in config to
     restrict this further."
- The OIDC code path REJECTS the same misconfiguration:
  OidcConfig::validate() in providers.rs returns
  SecurityError::SecurityConfigError("OIDC audience is REQUIRED
  for security...") when audience.is_none() &&
  additional_audiences.is_empty(). HS256 has no equivalent guard.

BUG REPRODUCED (security, regression).

Consequence:
  Cross-service token confusion: an HS256 token minted for
  service A (audience = "a") is accepted by service B
  (audience unset) when A and B share the HS256 secret. The
  defence S40 + the OIDC `audience` guard added in v2.3 closes
  this attack for OIDC but leaves it open for the
  shared-secret testing path -- which is exactly the path most
  vulnerable to having a shared secret across services.

Suggested fix:
  1. Add `validate()` to Hs256Config that returns an error when
     audience is None (mirroring OidcConfig::validate()).
  2. Call it from build_hs256_auth before constructing the
     AuthConfig.
  3. Loud-warn (not just silent-accept) in
     AuthMiddleware::from_config when signing_key.is_some() AND
     audience.is_none() AND required=true, mirroring the
     existing warn for missing signing_key.

Affected page draft: /building/authentication
  - LEAD security-caveats block must call out that
    `[auth_hs256] audience = "..."` is REQUIRED for any
    production-adjacent use, even though the server doesn't
    enforce it.
  - The HS256 walk-through example in the GREEN draft MUST
    show `audience = "<api-id>"` in the [auth_hs256] block.
MSG
exit 1
