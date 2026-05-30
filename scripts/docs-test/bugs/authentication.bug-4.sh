#!/usr/bin/env bash
#
# authentication.bug-4.sh — reproduction for the JWKS hot-rotate stolen-key
# replay window.
#
# When the operator rotates an OIDC keypair on the IdP side (typical
# response to a suspected private-key compromise), the FraiseQL server
# continues to accept tokens signed by the COMPROMISED key for up to
# `jwks_cache_ttl_secs` (default 300 seconds = 5 minutes) AFTER the
# rotation is complete. Worse, `detect_key_rotation` only logs a warning
# -- it does NOT invalidate the existing cache.
#
# Filed: https://github.com/fraiseql/fraiseql/issues/361
# Registered: _internal/.plan/framework-qa-triage.md (FW-29)
#
# Persona: Bug-Finder (Opus 4.7), Phase 03 / Cycle 4 RED.
# Frozen FraiseQL SHA: d0a4ed4ec1770c70707f68fd9019f2b561d87461 (v2.3.2).
#
# Severity: regression (security). The whole point of rotating a
# compromised key is to immediately stop honouring tokens signed by it;
# a five-minute grace window defeats that. The framework knows when a
# rotation occurs (`detect_key_rotation`) but does nothing actionable
# with the signal.
#
# ============================================================================
# Expected (per the doc comment on jwks_cache_ttl_secs default in
# providers.rs:L147-L150):
#
#   "SECURITY: Reduced from 3600s (1 hour) to 300s (5 minutes)
#    Prevents token cache poisoning by limiting revoked token window"
#
# That comment treats 300s as a defence-in-depth ceiling on the
# stolen-key replay window. The operator-facing expectation is that
# detecting a rotation invalidates the cache and forces a re-fetch
# on the next request, closing the window immediately.
#
# Actual (at frozen SHA):
#
#   1. get_decoding_key (jwks.rs:L113-L161) checks the cache FIRST:
#
#         let cache = self.jwks_cache.read();
#         if let Some(ref cached) = *cache {
#             if !cached.is_expired() {
#                 if let Some(key) = self.find_key(&cached.jwks, kid) {
#                     return self.jwk_to_decoding_key(key);
#                 }
#             }
#         }
#
#      If the cache still contains the compromised key (it does, until
#      300s elapse), every request signed by the compromised key matches
#      and validates. NO check against the upstream JWKS for revocation.
#
#   2. detect_key_rotation (jwks.rs:L210-L228) detects when previously
#      cached keys are missing from the new JWKS but its only action
#      is:
#
#         tracing::warn!(
#             "OIDC key rotation detected: some previously cached keys
#              no longer available"
#         );
#
#      It does NOT remove the rotated keys from the local cache. It
#      does NOT shorten the cache TTL. It does NOT bump a metric the
#      operator can alert on (no Prometheus counter, no
#      structured-log span field beyond the warn level).
#
#   3. detect_key_rotation is called inside get_decoding_key AFTER a
#      cache MISS triggers a fresh fetch -- so a request whose `kid`
#      is still in the cache (the attack scenario) never enters the
#      detection path. detect_key_rotation only fires when the
#      attacker uses a kid the cache hasn't seen yet, which is
#      precisely the path the attacker avoids.
#
#   4. After the 300s TTL expires, fetch_jwks re-fetches and the
#      compromised key naturally drops out -- but the operator can
#      do nothing to accelerate this short of restarting every
#      server replica. There is no SIGHUP, no /admin endpoint, no
#      env-var-driven re-fetch.
#
# Consequence (regression, security):
#
#   Operator detects a leaked private key at 10:00:00. They rotate
#   on the IdP at 10:00:30 (best case: instant new JWKS publication,
#   instant old-key revocation). FraiseQL replicas continue to
#   validate tokens signed by the leaked key until at most
#   10:05:30 -- a five-minute attacker window AFTER the IdP has
#   rotated. With `jwks_cache_ttl_secs` configurable higher than
#   the default (operators chasing JWKS-endpoint rate limits do
#   this), the window grows linearly.
#
#   This is the "S33 hardening" promise (auth input caps, 5-minute
#   default cache TTL) inverted: the 5-minute floor became a
#   5-minute mandatory wait.
#
# Exit codes:
#   0  - bug NOT reproduced (cache-flush-on-detect now present)
#   1  - bug REPRODUCED
#   2  - environment problem
# ============================================================================

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
FRAISEQL_REPO="$(cd "$HERE"/../../../fraiseql && pwd)"
FRAISEQL_SHA="$(cat "$HERE/FRAISEQL_SHA")"

echo "================================================================"
echo "FW-29 reproduction -- JWKS hot-rotate stolen-key replay window"
echo "FraiseQL SHA: $FRAISEQL_SHA"
echo "================================================================"

if ! git -C "$FRAISEQL_REPO" cat-file -e "$FRAISEQL_SHA"; then
    echo "ERROR: frozen SHA $FRAISEQL_SHA not present in $FRAISEQL_REPO" >&2
    exit 2
fi

JWKS=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-core/src/security/oidc/jwks.rs")
PROV=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-core/src/security/oidc/providers.rs")

# (a) Default TTL is 300s.
echo
echo "-- jwks_cache_ttl default --"
printf '%s\n' "$PROV" | grep -nB1 -A4 'default_jwks_cache_ttl' | head -15

if ! printf '%s\n' "$PROV" | grep -q 'jwks_cache_ttl_secs: u64'; then
    echo "BUG NOT REPRODUCED: jwks_cache_ttl_secs field changed shape." >&2
    exit 0
fi

# (b) get_decoding_key checks cache first, returns cached key if not
# expired even when a more-recent rotation has occurred upstream.
echo
echo "-- get_decoding_key cache-first path --"
printf '%s\n' "$JWKS" | awk '/fn get_decoding_key/,/Fetch fresh JWKS/' | head -25

if ! printf '%s\n' "$JWKS" | awk '/fn get_decoding_key/,/Fetch fresh JWKS/' \
    | grep -q '!cached.is_expired()'; then
    echo "BUG NOT REPRODUCED: cache-first branch shape changed." >&2
    exit 0
fi

# (c) detect_key_rotation only logs, never invalidates cache.
echo
echo "-- detect_key_rotation body (only logs; no cache invalidation) --"
rotation_block=$(printf '%s\n' "$JWKS" | awk '/fn detect_key_rotation/,/^    }/' | head -30)
printf '%s\n' "$rotation_block"

if printf '%s\n' "$JWKS" | grep -A2 'detect_key_rotation' | grep -qE 'cache.write\(\)|cache\.clear|invalidate|\*cache = None'; then
    echo "BUG NOT REPRODUCED: detect_key_rotation now invalidates the cache on detection." >&2
    exit 0
fi

# (d) detect_key_rotation is only called AFTER a cache miss. Confirm by
# checking get_decoding_key call sequence -- detect_key_rotation appears
# AFTER the cache-hit return path.
echo
echo "-- get_decoding_key call sequence (cache-hit returns BEFORE detect_key_rotation) --"
seq_block=$(printf '%s\n' "$JWKS" | awk '/fn get_decoding_key/,/^    \}/' | head -55)
echo "Cache-hit return line:"
printf '%s\n' "$seq_block" | grep -n 'return self.jwk_to_decoding_key' | head -2
echo "detect_key_rotation call line:"
printf '%s\n' "$seq_block" | grep -n 'detect_key_rotation' | head -2

ret_line=$(printf '%s\n' "$seq_block" | grep -n 'return self.jwk_to_decoding_key' | head -1 | cut -d: -f1)
det_line=$(printf '%s\n' "$seq_block" | grep -n 'detect_key_rotation' | head -1 | cut -d: -f1)
if [[ -z "$ret_line" || -z "$det_line" ]]; then
    echo "BUG NOT REPRODUCED: get_decoding_key shape changed." >&2
    exit 0
fi
if (( det_line < ret_line )); then
    echo "BUG NOT REPRODUCED: detect_key_rotation now precedes the cache-hit return." >&2
    exit 0
fi

cat <<'MSG'

================================================================
Bug-shape assertion:
================================================================
- jwks_cache_ttl_secs defaults to 300s
  (providers.rs:L147-L150). Doc comment frames this as a
  "5-minute ceiling on stolen-key replay window". Read another
  way: 5-minute mandatory floor on stale-cache acceptance.
- get_decoding_key (jwks.rs:L113-L161) checks the cache FIRST.
  Any cached, non-expired key is returned WITHOUT consulting
  upstream JWKS.
- detect_key_rotation (jwks.rs:L210-L228) only emits a
  tracing::warn!() -- it does NOT remove rotated keys from the
  cache, does NOT shorten the cached entry's TTL, does NOT bump
  a metric.
- detect_key_rotation runs AFTER a cache miss has already
  triggered a fresh fetch. It does not run on the cache-hit
  path (which is precisely the attack path).
- No SIGHUP / /admin endpoint / env-driven cache-flush path
  exists for the operator to accelerate cache eviction.

BUG REPRODUCED (regression, security).

Live-traffic reproduction:

  0. Server is configured with OIDC + jwks_cache_ttl_secs = 300
     (default).
  1. Server validates one token signed by kid="2026A" at
     t=0. Cache populated with key 2026A.
  2. Attacker leaks the kid="2026A" private key at t=10.
     Operator detects, rotates on IdP at t=20 (new key is
     "2026B"; key "2026A" is removed from upstream JWKS).
  3. Attacker continues to mint tokens signed by 2026A from
     t=20 onward.
  4. FraiseQL keeps validating attacker tokens until t=300
     (when the cached 2026A entry expires). Even if the server
     happens to receive a token signed by 2026B in the
     meantime, the detect_key_rotation warn fires but the
     cached 2026A entry stays until expiry.
  5. Restart of every replica is the only way to immediately
     flush the cache.

Suggested fix:
  1. Make detect_key_rotation invalidate the cache when it
     detects a missing key:
       if rotation_detected {
           *self.jwks_cache.write() = None;
           tracing::warn!(...);
       }
  2. Add an `/admin/v1/auth/refresh-jwks` endpoint (or signal
     handler) so an operator can force re-fetch on detection
     of a compromise -- without waiting up to ttl seconds and
     without restarting.
  3. Bump a Prometheus counter
     `fraiseql_oidc_jwks_rotation_detected_total` so the
     operator can alert on it.
  4. Document jwks_cache_ttl_secs as "MAXIMUM stolen-key
     replay window once rotation has been propagated" -- the
     current doc comment leaves operators thinking the cache
     is responsive.

Affected page: /building/authentication
  - LEAD security-caveats block MUST state the stolen-key
    replay window equals up to jwks_cache_ttl_secs after IdP
    rotation.
  - LEAD security-caveats block MUST tell operators to also
    restart replicas (or wait the TTL) after rotating a
    compromised JWKS key on the IdP side.
MSG
exit 1
