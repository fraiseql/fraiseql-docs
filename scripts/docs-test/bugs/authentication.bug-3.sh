#!/usr/bin/env bash
#
# authentication.bug-3.sh — reproduction for the "PKCE refuses without
# state encryption" claim mismatch.
#
# The Writer-RED handoff's security-caveats candidate #5 asserted that
# "PKCE refuses to function without state encryption" -- but the framework
# at the frozen SHA only emits a single warn!() and continues. Routes
# /auth/start and /auth/callback ARE mounted; the outbound state token
# is simply the raw internal_key (no encryption). This is doc-vs-code
# drift the GREEN page MUST NOT carry through unverified.
#
# Filed: https://github.com/fraiseql/fraiseql/issues/360
# Registered: _internal/.plan/framework-qa-triage.md (FW-28)
#
# Persona: Bug-Finder (Opus 4.7), Phase 03 / Cycle 4 RED.
# Frozen FraiseQL SHA: d0a4ed4ec1770c70707f68fd9019f2b561d87461 (v2.3.2).
#
# Class: doc-vs-code drift. Not as severe as FW-26 (anonymous revoke),
# but a load-bearing claim the page would have shipped without this
# reproduction. Triaged as `regression (security)` because the
# operator-facing promise of "state encryption is enforced" is unmet.
#
# ============================================================================
# Expected (Writer-RED handoff candidate #5; phase-doc Cycle 4 spec item
# "PKCE OAuth flow (state encryption -- [security.state_encryption], S256
# default)"):
#
#   When `[security.pkce] enabled = true` but `[security.state_encryption]`
#   is missing or disabled, the server refuses to mount the PKCE routes
#   (or aborts startup). The phase-doc treats state encryption as a
#   precondition of PKCE.
#
# Actual (at frozen SHA):
#
#   1. `pkce_store_from_schema` in server/initialization.rs builds a
#      PkceStateStore with `state_encryption.cloned()` -- which is
#      `None` when state_encryption is absent.
#
#   2. The only response to `state_encryption.is_none()` is:
#
#        warn!(
#            "pkce.enabled = true but state_encryption is disabled. \
#             PKCE state tokens are sent to the OIDC provider unencrypted. \
#             Enable [security.state_encryption] in production for full \
#             protection."
#        );
#
#      No return, no early-exit. The function continues and returns
#      Some(PkceStateStore).
#
#   3. mount_auth_routes (server/routing/auth.rs:L25-L46) then mounts
#      /auth/start and /auth/callback as soon as `pkce_store` and
#      `oidc_server_client` are both Some -- which they are.
#
#   4. PkceStateStore::create_state_sync in
#      crates/fraiseql-auth/src/pkce.rs:L153-L194 falls through:
#
#         let outbound_token = match &self.encryptor {
#             Some(enc) => enc.encrypt(internal_key.as_bytes())?,
#             None => internal_key,            // <-- raw key path
#         };
#
#      The state token sent to the OIDC provider is the raw 32-byte
#      internal key (base64 URL-safe encoded). It's still a random
#      one-shot lookup key so CSRF protection is intact (an attacker
#      can't guess it), but the operator promise the page intended to
#      teach -- "PKCE refuses to start without state encryption" --
#      is false.
#
# Consequence (regression, lower severity):
#
#   The page would have shipped a false-confident claim ("we refuse to
#   boot without state encryption -- so you can't accidentally run PKCE
#   in production without it"). An operator who reads that claim and
#   skips configuring state_encryption gets a green boot, sees /auth/start
#   responding 302, and assumes the production posture is correct.
#
#   The actual risk is narrow (outbound state token is unencrypted across
#   the network to the IdP -- the IdP returns it as the `state` query
#   parameter -- a network observer between the user-agent and the IdP
#   sees it, but cannot use it without also racing the server's
#   consume_state call). But the doc-vs-code mismatch alone is a
#   ship-stopper: it inverts a security-caveat claim.
#
# Exit codes:
#   0  - bug NOT reproduced (PKCE now refuses without state encryption)
#   1  - bug REPRODUCED (PKCE warns and continues; outbound state raw)
#   2  - environment problem
# ============================================================================

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
FRAISEQL_REPO="$(cd "$HERE"/../../../fraiseql && pwd)"
FRAISEQL_SHA="$(cat "$HERE/FRAISEQL_SHA")"

echo "================================================================"
echo "FW-28 reproduction -- PKCE doesn't refuse without state encryption"
echo "FraiseQL SHA: $FRAISEQL_SHA"
echo "================================================================"

if ! git -C "$FRAISEQL_REPO" cat-file -e "$FRAISEQL_SHA"; then
    echo "ERROR: frozen SHA $FRAISEQL_SHA not present in $FRAISEQL_REPO" >&2
    exit 2
fi

INIT=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/server/initialization.rs")
PKCE=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-auth/src/pkce.rs")
ROUTING=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/server/routing/auth.rs")

# (a) pkce_store_from_schema only warns -- does not return None or error.
echo
echo "-- pkce_store_from_schema state_encryption.is_none() branch --"
init_block=$(printf '%s\n' "$INIT" | awk '/fn pkce_store_from_schema/,/^    }/' | head -120)
printf '%s\n' "$init_block" | grep -nB1 -A4 'state_encryption.is_none' | head -15

if ! printf '%s\n' "$init_block" | grep -A3 'state_encryption.is_none()' | grep -q 'warn!'; then
    echo "BUG NOT REPRODUCED: state_encryption.is_none branch shape changed." >&2
    exit 0
fi

if printf '%s\n' "$init_block" \
    | awk '/state_encryption.is_none\(\)/{flag=1; print; next} flag && /^        \}/{flag=0; print; exit} flag' \
    | grep -qE 'return\s+None|return\s+Err'; then
    echo "BUG NOT REPRODUCED: state_encryption-missing branch now returns early." >&2
    exit 0
fi

# (b) Confirm pkce.rs falls through unencrypted.
echo
echo "-- pkce.rs create_state_sync outbound_token branch --"
printf '%s\n' "$PKCE" | awk '/fn create_state_sync/,/Ok\(\(outbound_token/' | head -50

if ! printf '%s\n' "$PKCE" | grep -q 'None => internal_key'; then
    echo "BUG NOT REPRODUCED: create_state_sync no longer has an unencrypted fallback." >&2
    exit 0
fi

# (c) Mounting logic only checks pkce_store + oidc_server_client.
echo
echo "-- mount_auth_routes PKCE mounting block --"
printf '%s\n' "$ROUTING" | awk '/PKCE OAuth2 auth routes/,/PKCE auth routes mounted/' | head -25

if ! printf '%s\n' "$ROUTING" \
    | grep -A2 'PKCE OAuth2 auth routes' \
    | grep -q 'pkce_store.*Some.*oidc_server_client.*Some\|Some(store), Some(client)'; then
    echo "BUG NOT REPRODUCED: mounting condition no longer pkce_store + oidc_server_client." >&2
    exit 0
fi
if printf '%s\n' "$ROUTING" \
    | awk '/PKCE OAuth2 auth routes/,/PKCE auth routes mounted/' \
    | grep -qE 'state_encryption'; then
    echo "BUG NOT REPRODUCED: mounting now gates on state_encryption." >&2
    exit 0
fi

cat <<'MSG'

================================================================
Bug-shape assertion (doc-vs-code drift):
================================================================
- The Writer-RED handoff (Phase 03 / Cycle 4) listed as
  security-caveat candidate #5:
    "PKCE refuses to function without state encryption."
- The phase-doc Cycle 4 spec frames `[security.state_encryption]`
  as a PKCE precondition.
- In the actual framework at the frozen SHA:
    * pkce_store_from_schema (server/initialization.rs) emits
      ONE warn!() when state_encryption.is_none() and continues
      to return Some(PkceStateStore).
    * mount_auth_routes (server/routing/auth.rs:L25-L46) gates
      ONLY on (pkce_store, oidc_server_client). No
      state_encryption check.
    * PkceStateStore::create_state_sync (fraiseql-auth/src/pkce.rs)
      explicitly handles the encryptor=None case by falling
      through unencrypted.

The Writer-RED handoff claim was wrong. If we'd written the GREEN
page on top of that claim, /building/authentication would have
taught readers a security guarantee that doesn't exist.

BUG REPRODUCED (regression, security -- doc-vs-code claim drift).

Suggested fix (framework side):
  1. Make state_encryption a hard prerequisite for PKCE:
     pkce_store_from_schema returns None (and the routes don't
     mount) when state_encryption.is_none() and PKCE is enabled.
  2. Or upgrade the warn!() to a Result::Err so the server
     refuses to boot in that posture (matching the existing
     OidcConfig::validate() pattern for missing audience).

Suggested fix (docs side, until framework changes):
  The GREEN /building/authentication page MUST NOT repeat the
  Writer-RED claim. The page MUST instead document:
    - state_encryption is recommended but not enforced at this SHA.
    - PKCE routes WILL mount and serve traffic with
      state_encryption disabled; the outbound state token is the
      raw internal lookup key (still random + one-shot, so CSRF
      protection is preserved, but the OIDC provider sees the
      key in cleartext on the redirect URL).
    - Operators who skip [security.state_encryption] get a single
      startup warning and no further enforcement.

This finding is a Bug-Finder gift to the GREEN Writer: do NOT
copy security-caveat candidate #5 from the RED handoff verbatim.
The actual posture is "warn-and-continue", not "refuse".
MSG
exit 1
