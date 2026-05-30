#!/usr/bin/env bash
#
# authentication.bug-1.sh — reproduction for the anonymous-revoke bug.
#
# The /auth/revoke and /auth/revoke-all endpoints are mounted WITHOUT any
# auth middleware. Any unauthenticated client can revoke any JWT (just send
# the token) or wipe every session for any user (just send the `sub`).
#
# Filed: https://github.com/fraiseql/fraiseql/issues/358
# Registered: _internal/.plan/framework-qa-triage.md (FW-26)
#
# Persona: Bug-Finder (Opus 4.7), Phase 03 / Cycle 4 RED.
# Frozen FraiseQL SHA: d0a4ed4ec1770c70707f68fd9019f2b561d87461 (v2.3.2).
#
# Same FW-21 class as the observers anonymous-admin bug (#348).
#
# ============================================================================
# Expected (per the routes/auth.rs:L295-L350 docstring on `revoke_token`):
#
#   The /auth/revoke endpoint accepts the token to be revoked, decodes its
#   claims, and inserts a revocation record. The `oidc_auth_middleware` is
#   meant to guard the route so that only an authenticated session can
#   request revocations.
#
#   For /auth/revoke-all the operator expects callers to be at least
#   authenticated AND authorised to revoke for the requested `sub`
#   (typically by being that sub, or by holding an admin scope).
#
# Actual (at frozen SHA):
#
#   `mount_auth_routes` (server/routing/auth.rs:L103-L114) merges
#   POST /auth/revoke and POST /auth/revoke-all into the application
#   router with NO middleware:
#
#       if let Some(ref rev_mgr) = self.revocation_manager {
#           let rev_state = Arc::new(crate::routes::RevocationRouteState {
#               revocation_manager: Arc::clone(rev_mgr),
#           });
#           let rev_router = Router::new()
#               .route("/auth/revoke", post(crate::routes::revoke_token))
#               .route("/auth/revoke-all", post(crate::routes::revoke_all_tokens))
#               .with_state(rev_state);
#           app = app.merge(rev_router);  // <-- no route_layer / no middleware
#           info!(...);
#       }
#
#   Compare to the SIBLING /auth/me block in the same function
#   (auth.rs:L81-L101) which DOES apply `oidc_auth_middleware`:
#
#       let me_router = Router::new()
#           .route("/auth/me", get(auth_me))
#           .route_layer(middleware::from_fn_with_state(
#                          auth_state, oidc_auth_middleware))  // <-- present
#           .with_state(me_state);
#
#   Global middleware (server/routing/middleware.rs:apply_middleware) only
#   applies metrics, tracing, CORS, body limits, header limits, timeout,
#   and rate limiting -- never an auth layer.
#
#   The /auth/revoke handler (routes/auth.rs:L300-L350) uses
#   `jsonwebtoken::dangerous::insecure_decode` -- it does NOT verify the
#   signature. Any well-formed JWT (signed by anyone or unsigned) with a
#   `jti` claim is accepted, and its `jti` is added to the revocation
#   store. No proof-of-possession, no caller identity, no audit trail.
#
#   /auth/revoke-all (auth.rs:L370-L405) is even worse: it accepts a JSON
#   body `{"sub": "..."}` -- no token at all is needed -- and calls
#   `state.revocation_manager.revoke_all_for_user(&body.sub)`.
#
# Consequence (security severity, critical, anonymous DoS):
#
#   An unauthenticated attacker can:
#     (1) Hand-craft a JWT with arbitrary `jti` values and revoke any token
#         they've harvested from logs / a leaked database / a sniffed
#         response.
#     (2) Pick any known username (`sub`) and call /auth/revoke-all to
#         force-logout that user across every replica that shares the
#         revocation store, repeatedly, with no rate limit beyond the
#         generic per-IP limit -- which the attacker can bypass by IP
#         rotation.
#     (3) Wipe every active session for the administrator account, then
#         repeat continuously to keep them locked out while exfiltrating
#         data through other paths.
#
#   When the revocation store is in-memory and single-replica, the same
#   attack still works against every active session on that instance.
#
# Exit codes:
#   0  - bug NOT reproduced (mount logic now applies an auth middleware)
#   1  - bug REPRODUCED
#   2  - environment problem
# ============================================================================

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
FRAISEQL_REPO="$(cd "$HERE"/../../../fraiseql && pwd)"
FRAISEQL_SHA="$(cat "$HERE/FRAISEQL_SHA")"

echo "================================================================"
echo "FW-26 reproduction -- /auth/revoke and /auth/revoke-all anonymous"
echo "FraiseQL SHA: $FRAISEQL_SHA"
echo "================================================================"

if ! git -C "$FRAISEQL_REPO" cat-file -e "$FRAISEQL_SHA"; then
    echo "ERROR: frozen SHA $FRAISEQL_SHA not present in $FRAISEQL_REPO" >&2
    exit 2
fi

ROUTING=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/server/routing/auth.rs")
HANDLERS=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/routes/auth.rs")
MIDDLEWARE=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/server/routing/middleware.rs")

# (a) The /auth/me block applies oidc_auth_middleware via route_layer.
#     The /auth/revoke block does not.

echo
echo "-- /auth/me mounting block (sibling, the secured shape) --"
printf '%s\n' "$ROUTING" | awk '/auth\/me/,/info!\("Session identity/' | head -25

me_block=$(printf '%s\n' "$ROUTING" | awk '/auth\/me/,/info!\("Session identity/')
if ! printf '%s\n' "$me_block" | grep -q 'route_layer.*oidc_auth_middleware'; then
    echo "BUG NOT REPRODUCED: /auth/me no longer applies oidc_auth_middleware; baseline shape changed." >&2
    exit 0
fi

echo
echo "-- /auth/revoke mounting block (the bug) --"
revoke_block=$(printf '%s\n' "$ROUTING" | awk '/Token revocation routes/,/info!\("Token revocation/')
printf '%s\n' "$revoke_block"

if printf '%s\n' "$revoke_block" | grep -qE 'route_layer|from_fn_with_state|oidc_auth_middleware|hs256_auth_middleware|api_key_auth'; then
    echo "BUG NOT REPRODUCED: /auth/revoke block now applies an auth middleware." >&2
    exit 0
fi

# (b) Global middleware does not apply auth -- confirm.

echo
echo "-- apply_middleware: layers applied globally (must NOT include auth) --"
printf '%s\n' "$MIDDLEWARE" | grep -nE 'app = app.layer|app = app$' | head -30

if printf '%s\n' "$MIDDLEWARE" | grep -qE 'oidc_auth_middleware|hs256_auth_middleware'; then
    echo "BUG NOT REPRODUCED: apply_middleware now adds a server-wide auth layer." >&2
    exit 0
fi

# (c) The handler decodes the token WITHOUT verifying the signature.

echo
echo "-- revoke_token handler decode call --"
printf '%s\n' "$HANDLERS" | grep -nE 'insecure_decode|dangerous|decode\b' | head -5

if ! printf '%s\n' "$HANDLERS" | grep -q 'dangerous::insecure_decode'; then
    echo "BUG NOT REPRODUCED: revoke_token handler now uses a signature-verifying decode path." >&2
    exit 0
fi

# (d) revoke_all accepts a plain `sub` body with no proof-of-possession.

echo
echo "-- revoke_all_tokens handler body schema --"
printf '%s\n' "$HANDLERS" | awk '/struct RevokeAllRequest/,/^}/' | head -10
printf '%s\n' "$HANDLERS" | awk '/async fn revoke_all_tokens/,/^}/' | head -25

if ! printf '%s\n' "$HANDLERS" | grep -q 'revoke_all_for_user'; then
    echo "BUG NOT REPRODUCED: revoke_all_for_user contract changed." >&2
    exit 0
fi

cat <<'MSG'

================================================================
Bug-shape assertion:
================================================================
- mount_auth_routes (server/routing/auth.rs:L103-L114) merges the
  /auth/revoke and /auth/revoke-all routes into the application
  router with NO route_layer, NO middleware, NO auth gate.
- The sibling /auth/me block (auth.rs:L81-L101) DOES apply
  oidc_auth_middleware via route_layer -- so the codebase clearly
  knows the pattern. The revocation block omits it.
- apply_middleware (server/routing/middleware.rs) only applies
  metrics, tracing, CORS, body limits, header limits, timeout, and
  rate limiting -- never auth.
- revoke_token handler (routes/auth.rs:L300-L350) decodes the
  token with `jsonwebtoken::dangerous::insecure_decode` -- no
  signature check, no proof-of-possession.
- revoke_all_tokens handler (routes/auth.rs:L370-L405) accepts a
  body `{"sub":"..."}` with no token at all and wipes every
  active session for that sub.

BUG REPRODUCED (security, critical).

Live-traffic reproduction (after a host binary mounts revocation):

  # Lock out user 'alice' across every replica sharing the
  # revocation store. No auth required.
  curl -X POST http://server/auth/revoke-all \
       -H 'Content-Type: application/json' \
       -d '{"sub":"alice"}'

  # Revoke a specific JTI harvested from logs / a leaked DB row.
  # The token doesn't need to be valid; only well-formed.
  ATTACKER_JWT=$(jwt-cli -a HS256 -p any-secret \
                         '{"jti":"victims-jti-here","sub":"x","exp":9999999999}')
  curl -X POST http://server/auth/revoke \
       -H 'Content-Type: application/json' \
       -d "{\"token\":\"$ATTACKER_JWT\"}"

Suggested fix:
  1. In mount_auth_routes, wrap the revocation router with
     `route_layer(middleware::from_fn_with_state(auth_state, oidc_auth_middleware))`
     the same way /auth/me does (or hs256_auth_middleware when
     [auth_hs256] is configured instead of [auth]).
  2. In revoke_token, ASSERT that the caller's authenticated `sub`
     matches the `sub` claim of the token being revoked, unless an
     admin scope is present. Anyone should be able to revoke their
     own session; nobody should be able to revoke other users'.
  3. In revoke_all_tokens, require either (a) the caller's
     authenticated `sub` to equal `body.sub`, or (b) an admin scope.

Affected page draft: /building/authentication (token-revocation
                     section) + /building/authentication LEAD
                     security-caveats block.
Until fixed:
  - Page MUST warn that /auth/revoke and /auth/revoke-all are
    UNAUTHENTICATED at this SHA and recommend the operator deploy
    them behind a reverse-proxy auth gate, OR not mount them at
    all (turn revocation off in the compiled schema).
  - Page MUST NOT recommend /auth/revoke as a self-service
    logout endpoint for browser flows -- it is an anonymous DoS
    primitive at this SHA.
MSG
exit 1
