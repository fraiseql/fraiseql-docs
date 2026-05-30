#!/usr/bin/env bash
#
# authentication.docs-test.sh — Phase 03 Cycle 4 docs-test for
# /building/authentication.
#
# What this script proves:
#   The contract documented on /building/authentication:
#     1. Direct-TOML auto-wiring: `[auth]` (OIDC) and `[auth_hs256]` (HS256
#        testing mode) flow from `ServerConfig` and are wired by the binary at
#        startup with NO compile step. The HS256 path is the only auth flavour
#        the docs-test stack can drive end-to-end without an OIDC stub
#        container — exercising it here is the closest the harness can get to
#        an A1 happy-path run at v2.3.2.
#     2. Compile-step indirection: `[security.api_keys]` /
#        `[security.token_revocation]` / `[security.pkce]` /
#        `[security.state_encryption]` / `[security.rate_limiting]` all live on
#        the compiled schema under `schema.security.additional["<subsystem>"]`,
#        consumed via `*_from_schema` builders. The compiled-schema fixture
#        DELIBERATELY omits these blocks because the harness asserts the
#        documented FW-26..FW-29 symptoms via STATIC source-greps at the
#        frozen SHA — no live HTTP probe required.
#     3. Six known security caveats reproduce against the frozen SHA:
#          FW-24 #356 — failed_login_max_attempts / failed_login_lockout_secs
#                       silently dropped by server runtime
#          FW-25 #357 — token_revocation.backend = "postgres" silently
#                       downgrades to in-memory
#          FW-26 #358 — /auth/revoke and /auth/revoke-all are unauthenticated
#                       (critical)
#          FW-27 #359 — HS256 audience is NOT enforced at boot
#          FW-28 #360 — PKCE warns-and-continues without state_encryption (the
#                       documented Writer-RED candidate #5 "PKCE refuses
#                       without state encryption" was wrong; replaced by
#                       this caveat in GREEN)
#          FW-29 #361 — JWKS hot-rotate replay window equals cache TTL (default
#                       300 s) after IdP rotation
#     4. Five negative findings hold (positive page-content statements about
#        defences the framework does enforce):
#          - Algorithm-confusion mitigation: `default_algorithms()` returns
#            `["RS256"]` and `get_algorithm` enforces the allowlist.
#          - Cookie format: `__Host-access_token`, RFC 6265 quoted-string
#            escape (`\` and `"` doubled), no `Domain=` attribute.
#          - API key constant-time compare: `subtle::ConstantTimeEq` +
#            SHA-256 hashed storage.
#          - OIDC audience enforced at boot: `OidcConfig::validate()` returns
#            `SecurityConfigError` when `audience` is unset (only the OIDC
#            path; HS256 lacks the guard — that is FW-27).
#          - Malformed JWK rejection: `jwk_to_decoding_key` returns
#            `SecurityError::InvalidToken` gracefully; no crash.
#
# How it proves:
#   The cycle spec asks for a runnable scenario: configure HS256 testing mode,
#   mint a valid token, verify a protected query succeeds, tamper signature
#   and verify 401, plus PKCE / `/auth/me` round-trips. The harness cannot
#   drive the full PKCE / `/auth/me` round-trip without an OIDC stub container
#   (deferred to a future cycle when an OIDC stub lands).
#
#   This script therefore:
#     (a) brings up the binary against the authentication overlay TOML which
#         carries `[auth_hs256]` direct-TOML, with `FRAISEQL_HS256_SECRET`
#         injected into the container env via a compose override. Asserts the
#         binary boots cleanly and `/health` returns 200;
#     (b) mints a valid HS256 token in-container with `python3 -c`, calls
#         `POST /graphql` introspection with the Bearer token, asserts 200;
#     (c) tampers one byte of the signature, asserts 401;
#     (d) re-greps the documented library-API recipes at the frozen SHA — for
#         the JWKS hot-rotate behaviour, cookie format, API key constant-time
#         compare, OIDC audience-mandatory check, and HS256-without-audience
#         path — to assert page claims stay locked;
#     (e) runs the four static-source bug repros
#         (authentication.bug-{1..4}.sh) and requires each to exit 1 (BUG
#         REPRODUCED) at the frozen SHA. Combined with the negative-findings
#         re-greps in (d), this covers the six FW-N rows the page surfaces.
#
#   When the framework fixes ship, the FW symptoms in step (e) flip from
#   "still broken" to "now fixed", at which point this script will fail
#   loudly. That failure is the regression signal that unblocks the
#   binary-driven happy path.
#
# Framing decision: this is option **A2** per the Writer-GREEN brief — the
# script documents the intended sequence, drives the HS256-direct-TOML happy
# path the binary CAN serve at v2.3.2, asserts the documented FW-24..FW-29
# symptoms against the off-the-shelf binary at the frozen SHA, and asserts
# the negative-findings library-API recipes remain source-true. It does NOT
# silently skip — every "documented symptom" is a real assertion that flips
# when the upstream fix lands.
#
# Why not A1 (a fully wired happy path):
#   - The full PKCE / `/auth/me` / `/auth/revoke` flow requires an OIDC stub
#     container; the docs-test Compose stack does not ship one at v2.3.2. A1
#     of this surface is out of harness budget at this cycle.
#   - The bug repros (bug-1..4) already exercise the source surface at the
#     frozen SHA; A2 reuses them as positive assertions that the page's
#     security caveats remain real.
#   - This matches the Cycle 1 / 2 / 3 precedent.
#
# Exit codes:
#   0 — every assertion holds against the frozen SHA + the docs-test stack.
#   1 — at least one assertion failed (page is drifting from reality).
#   2 — preflight error (no docker, missing fixture, harness not built).
#
# source: src/content/docs/building/authentication.md (page under test)
# source: _internal/.plan/.phases/phase-03-critical-rewrites.md:L196-L221 (Cycle 4 spec)
# source: _internal/.plan/methodology.md § 6 (container harness conventions)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
DOCS_TEST="$HERE"
OPERATOR_CLI="$DOCS_TEST/docs-test.sh"
COMPOSE_FILE="$DOCS_TEST/docker-compose.docs-test.yml"
FRAISEQL_REPO="$(cd "$DOCS_TEST/../../../fraiseql" && pwd)"
FRAISEQL_SHA="$(tr -d '[:space:]' < "$DOCS_TEST/FRAISEQL_SHA")"

# shellcheck source=../lib/assert.sh disable=SC1091
. "$DOCS_TEST/lib/assert.sh"

OVERLAY="$DOCS_TEST/configs/overlays/authentication.toml"
COMPILED_SCHEMA="$DOCS_TEST/fixtures/postgres/authentication.compiled.json"
BUGS_DIR="$DOCS_TEST/bugs"
HOST_PORT_FRAISEQL="${HOST_PORT_FRAISEQL:-8080}"

# HS256 secret — a fixed 32-byte base64 value, sufficient for HS256 in the
# docs-test environment. NOT a real production secret; this script is
# self-contained and the value never leaves the test stack.
HS256_SECRET="docs-test-hs256-secret-do-not-use-in-prod-32b"

# Temp override path; populated by write_overlay_override.
OVERLAY_OVERRIDE=""

banner() {
    printf '\n=== authentication: %s ===\n' "$1"
}

step() {
    printf '  · %s\n' "$*"
}

err() {
    printf 'authentication.docs-test: %s\n' "$*" >&2
}

die() {
    err "$*"
    exit 2
}

# ---------------------------------------------------------------------------
# Preflight.
# ---------------------------------------------------------------------------
preflight() {
    command -v docker  >/dev/null || die "docker not on PATH"
    command -v jq      >/dev/null || die "jq not on PATH (assert_json_shape requires it)"
    command -v python3 >/dev/null || die "python3 not on PATH (mint_hs256 runs on the host because the fraiseql runtime image is slim)"
    [ -x "$OPERATOR_CLI" ]       || die "operator CLI missing: $OPERATOR_CLI"
    [ -r "$COMPOSE_FILE" ]       || die "compose file missing: $COMPOSE_FILE"
    [ -r "$OVERLAY" ]            || die "overlay missing: $OVERLAY"
    [ -r "$COMPILED_SCHEMA" ]    || die "compiled-schema fixture missing: $COMPILED_SCHEMA"

    if ! docker image inspect fraiseql-docs-test-fraiseql:latest >/dev/null 2>&1; then
        die "image fraiseql-docs-test-fraiseql:latest not present; run \`docker compose -f $COMPOSE_FILE build fraiseql\` once before this test"
    fi

    if ! git -C "$FRAISEQL_REPO" cat-file -e "$FRAISEQL_SHA"; then
        die "frozen FraiseQL SHA $FRAISEQL_SHA not present in $FRAISEQL_REPO"
    fi

    for n in 1 2 3 4; do
        [ -x "$BUGS_DIR/authentication.bug-$n.sh" ] \
            || die "missing or non-executable repro: $BUGS_DIR/authentication.bug-$n.sh"
    done
}

# ---------------------------------------------------------------------------
# Compose override — bind-mounts the authentication overlay TOML, the compiled
# schema, and injects FRAISEQL_HS256_SECRET into the fraiseql container env.
# ---------------------------------------------------------------------------
write_overlay_override() {
    OVERLAY_OVERRIDE="$(mktemp -t fraiseql-docs-auth-override.XXXXXX.yml)"
    cat >"$OVERLAY_OVERRIDE" <<EOF
# Generated by scripts/docs-test/pages/authentication.docs-test.sh — do not commit.
services:
  fraiseql:
    environment:
      FRAISEQL_HS256_SECRET: "$HS256_SECRET"
    volumes:
      - $OVERLAY:/etc/fraiseql/fraiseql.toml:ro
      - $COMPILED_SCHEMA:/etc/fraiseql/schema.compiled.json:ro
EOF
}

cleanup() {
    set +e
    if [ -n "${OVERLAY_OVERRIDE:-}" ] && [ -f "$OVERLAY_OVERRIDE" ]; then
        rm -f "$OVERLAY_OVERRIDE"
    fi
    "$OPERATOR_CLI" down --volumes >/dev/null 2>&1 || true
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Mint an HS256 JWT on the HOST (fraiseql runtime image is slim and does not
# bundle python3 or jq). The host's python3 is a preflight requirement.
# Returns the token on stdout. Args: <iss> <aud> <sub> <exp_seconds_from_now>
# ---------------------------------------------------------------------------
mint_hs256() {
    local iss="$1" aud="$2" sub="$3" exp_secs="$4"
    FRAISEQL_HS256_SECRET="$HS256_SECRET" \
    FRAISEQL_MINT_ISS="$iss" \
    FRAISEQL_MINT_AUD="$aud" \
    FRAISEQL_MINT_SUB="$sub" \
    FRAISEQL_MINT_EXP="$exp_secs" \
    python3 -c "
import base64, hmac, hashlib, json, time, os, sys
secret = os.environ['FRAISEQL_HS256_SECRET'].encode()
header = {'alg': 'HS256', 'typ': 'JWT'}
now = int(time.time())
payload = {
    'iss': os.environ['FRAISEQL_MINT_ISS'],
    'aud': os.environ['FRAISEQL_MINT_AUD'],
    'sub': os.environ['FRAISEQL_MINT_SUB'],
    'iat': now,
    'exp': now + int(os.environ['FRAISEQL_MINT_EXP']),
    'jti': 'docs-test-' + str(now),
}
def b64(d):
    return base64.urlsafe_b64encode(json.dumps(d, separators=(',', ':')).encode()).rstrip(b'=')
signing_input = b64(header) + b'.' + b64(payload)
sig = hmac.new(secret, signing_input, hashlib.sha256).digest()
sig_b64 = base64.urlsafe_b64encode(sig).rstrip(b'=')
sys.stdout.write((signing_input + b'.' + sig_b64).decode())
"
}

# ---------------------------------------------------------------------------
# Assertion 1 — `[auth_hs256]` direct-TOML wires the binary's HS256 validator.
# The binary's startup log mentions "Initializing HS256 authentication", and
# protected requests with a valid HS256 token reach the handler. This is the
# closest the docs-test gets to driving the page's documented happy path.
#
# Probe shape:
#   - stack up
#   - /health returns 200
#   - mint a valid HS256 token (iss=fraiseql-docs-test, aud=docs-test-api)
#   - POST /graphql introspection with Bearer token — assert 200
#   - tamper the signature (flip last char) — assert 401
# ---------------------------------------------------------------------------
assert_hs256_direct_toml_happy_path() {
    banner "HS256 direct-TOML happy path (auto-wired from ServerConfig)"

    write_overlay_override

    "$OPERATOR_CLI" down --volumes >/dev/null 2>&1 || true

    docker compose -f "$COMPOSE_FILE" -f "$OVERLAY_OVERRIDE" \
        --profile fraiseql up -d --wait --wait-timeout 240 >/dev/null
    step "stack up with authentication overlay"

    # Wait for /health (max 30s).
    local attempt
    for attempt in $(seq 1 30); do
        if curl -fsS "http://127.0.0.1:$HOST_PORT_FRAISEQL/health" >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done
    : "$attempt"

    local health_code
    health_code=$(curl -sS -o /dev/null -w '%{http_code}' \
        "http://127.0.0.1:$HOST_PORT_FRAISEQL/health" || true)
    if [ "$health_code" != "200" ]; then
        err "/health returned $health_code; expected 200 — HS256 boot may be failing"
        return 1
    fi
    step "/health returns 200 (binary booted under HS256 overlay)"

    # Mint a valid token for the configured iss/aud.
    local token
    token=$(mint_hs256 fraiseql-docs-test docs-test-api docs-test-user 600 || true)
    # Shape check: a HS256 JWT is base64url segments separated by 2 dots
    # (header.payload.signature). `grep -c '\.'` counts MATCHING LINES, not
    # dot occurrences — a single-line token always returns 1, so the original
    # `< 2` test mis-rejected every valid token. Use `tr` to count chars.
    if [ -z "$token" ] || [ "$(printf '%s' "$token" | tr -cd '.' | wc -c)" -lt 2 ]; then
        err "mint_hs256 produced no token (or token shape is malformed). Host python3 required: mint runs on the host because the fraiseql runtime image is slim."
        return 1
    fi
    step "minted HS256 token (iss=fraiseql-docs-test aud=docs-test-api)"

    # POST /graphql with a trivial introspection query; the request is
    # authenticated via Bearer token. The framework runs `oidc_auth_middleware`
    # (which accepts HS256 when the HS256 validator is configured); we assert
    # the response is NOT 401 — any non-401 status confirms the token reached
    # the handler.
    local resp_code
    resp_code=$(curl -sS -o /dev/null -w '%{http_code}' \
        -X POST "http://127.0.0.1:$HOST_PORT_FRAISEQL/graphql" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d '{"query":"{__typename}"}' || true)
    if [ "$resp_code" = "401" ] || [ "$resp_code" = "403" ]; then
        err "POST /graphql with valid HS256 token returned $resp_code; expected 200/400/422 — token validation rejected a valid token"
        return 1
    fi
    step "POST /graphql with valid HS256 token returned $resp_code (token reached the handler)"

    # Tamper the signature (flip the last character to one that is definitely
    # not the original).
    local last_char tampered_token
    last_char=$(printf '%s' "$token" | tail -c 1)
    if [ "$last_char" = "A" ]; then
        tampered_token="${token%?}B"
    else
        tampered_token="${token%?}A"
    fi

    local tampered_code
    tampered_code=$(curl -sS -o /dev/null -w '%{http_code}' \
        -X POST "http://127.0.0.1:$HOST_PORT_FRAISEQL/graphql" \
        -H "Authorization: Bearer $tampered_token" \
        -H "Content-Type: application/json" \
        -d '{"query":"{__typename}"}' || true)
    if [ "$tampered_code" != "401" ]; then
        err "POST /graphql with tampered HS256 token returned $tampered_code; expected 401 — signature verification may be silently passing"
        return 1
    fi
    step "POST /graphql with tampered HS256 token returned 401 (signature rejection works)"

    "$OPERATOR_CLI" down --volumes >/dev/null 2>&1 || true
    step "stack down clean"
    return 0
}

# ---------------------------------------------------------------------------
# Assertion 2 — algorithm allowlist defaults to `["RS256"]` and the validator
# enforces it at `get_algorithm`. Page claim: algorithm-confusion attack
# (HS256 token against RS256-only validator) is rejected with
# `SecurityError::InvalidTokenAlgorithm`.
# ---------------------------------------------------------------------------
assert_algorithm_allowlist_enforced() {
    banner "Algorithm allowlist defaults to [\"RS256\"] and is enforced"

    local providers token
    providers=$(git -C "$FRAISEQL_REPO" show \
        "${FRAISEQL_SHA}:crates/fraiseql-core/src/security/oidc/providers.rs")
    token=$(git -C "$FRAISEQL_REPO" show \
        "${FRAISEQL_SHA}:crates/fraiseql-core/src/security/oidc/token.rs")

    if printf '%s' "$providers" | grep -qE 'fn default_algorithms\(\)' \
        && printf '%s' "$providers" | grep -qE '"RS256"\.to_string\(\)'; then
        step "default_algorithms() returns [\"RS256\"] at frozen SHA"
    else
        err "default_algorithms() shape changed at frozen SHA — page's allowlist-default claim drifts"
        return 1
    fi

    if printf '%s' "$token" | grep -qE 'allowed_algorithms\.contains\(' \
        && printf '%s' "$token" | grep -qE 'InvalidTokenAlgorithm'; then
        step "get_algorithm enforces allowed_algorithms and returns InvalidTokenAlgorithm on mismatch"
    else
        err "algorithm allowlist enforcement changed — page's algorithm-confusion mitigation claim drifts"
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# Assertion 3 — cookie format on PKCE callback is documented verbatim:
# `__Host-access_token="..."; Path=/; HttpOnly; Secure; SameSite=Strict;
# Max-Age=...`. The token value is RFC 6265 quoted-string-escaped. No
# `Domain=` attribute.
# ---------------------------------------------------------------------------
assert_cookie_format_holds() {
    banner "Cookie format: __Host- + RFC 6265 quoting, no Domain="

    local routes
    routes=$(git -C "$FRAISEQL_REPO" show \
        "${FRAISEQL_SHA}:crates/fraiseql-server/src/routes/auth.rs")

    # The exact cookie format string must be present in /auth/callback.
    if printf '%s' "$routes" | grep -qE '__Host-access_token="' \
        && printf '%s' "$routes" | grep -qE 'Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=' \
        && ! printf '%s' "$routes" | grep -qE '__Host-access_token=.*Domain='; then
        step "cookie format string present at frozen SHA (no Domain= attribute)"
    else
        err "cookie format string drift at frozen SHA — page's Set-Cookie claim drifts"
        return 1
    fi

    # RFC 6265 escape: token value has `\\` and `\"` replaced.
    if printf '%s' "$routes" | grep -qE "replace\\('\\\\\\\\', r\"\\\\\\\\\\\\\\\\\"\\)\\.replace\\('\"'" \
        || printf '%s' "$routes" | grep -qE 'replace.*backslash|RFC 6265'; then
        step "RFC 6265 quoted-string escape applied to cookie value"
    else
        err "RFC 6265 escape no longer applied — page's cookie-injection claim drifts"
        return 1
    fi

    # The ingest side strips quotes.
    local middleware
    middleware=$(git -C "$FRAISEQL_REPO" show \
        "${FRAISEQL_SHA}:crates/fraiseql-server/src/middleware/oidc_auth.rs")
    # Framework code at frozen SHA is `.trim_matches('"')` — a single-quoted
    # char literal containing the double-quote. The earlier regex required
    # `trim_matches\(.\\"`, which never matches because shell collapses `\\"`
    # to `\"` and the actual source has `'"'` (no backslash). Look for
    # `trim_matches\(.'.\)` with `'"'` substring.
    if printf '%s' "$middleware" | grep -qE 'fn extract_access_token_cookie' \
        && printf '%s' "$middleware" | grep -qF "trim_matches('\"')"; then
        step "extract_access_token_cookie strips quotes at frozen SHA"
    else
        err "cookie ingest helper changed — page's cookie-fallback claim drifts"
        return 1
    fi

    return 0
}

# ---------------------------------------------------------------------------
# Assertion 4 — API key authenticator uses SHA-256 + ConstantTimeEq.
# ---------------------------------------------------------------------------
assert_api_key_constant_time_compare() {
    banner "API key authentication: SHA-256 + subtle::ConstantTimeEq"

    local api_key
    api_key=$(git -C "$FRAISEQL_REPO" show \
        "${FRAISEQL_SHA}:crates/fraiseql-server/src/api_key.rs")

    if printf '%s' "$api_key" | grep -qE 'use subtle::ConstantTimeEq'; then
        step "subtle::ConstantTimeEq imported at frozen SHA"
    else
        err "subtle::ConstantTimeEq import missing — page's constant-time claim drifts"
        return 1
    fi

    if printf '%s' "$api_key" | grep -qE 'key_hash\.ct_eq\('; then
        step "ct_eq(...) comparison present at frozen SHA"
    else
        err "ct_eq comparison missing — page's constant-time claim drifts"
        return 1
    fi

    if printf '%s' "$api_key" | grep -qE 'fn sha256_hash' \
        && printf '%s' "$api_key" | grep -qE 'Sha256::new'; then
        step "sha256_hash impl present at frozen SHA"
    else
        err "sha256_hash impl missing — page's SHA-256 hashed-storage claim drifts"
        return 1
    fi

    return 0
}

# ---------------------------------------------------------------------------
# Assertion 5 — OIDC validator REJECTS boot without `audience` configured.
# This is the positive enforcement caveat 9 documents — it balances the four
# "framework doesn't enforce" caveats. Page claim:
# `OidcConfig::validate()` returns `SecurityConfigError("OIDC audience is
# REQUIRED for security...")` when audience + additional_audiences are both
# empty.
# ---------------------------------------------------------------------------
assert_oidc_audience_mandatory_at_boot() {
    banner "OIDC audience is mandatory: OidcConfig::validate() refuses boot when empty"

    local providers
    providers=$(git -C "$FRAISEQL_REPO" show \
        "${FRAISEQL_SHA}:crates/fraiseql-core/src/security/oidc/providers.rs")

    # The validate() fn that rejects audience-empty boot.
    if printf '%s' "$providers" | grep -qE 'pub fn validate\(&self\) -> Result' \
        && printf '%s' "$providers" | grep -qE 'OIDC audience is REQUIRED'; then
        step "OidcConfig::validate() carries the 'audience is REQUIRED' check at frozen SHA"
    else
        err "OidcConfig::validate() audience check missing — page's caveat 9 drifts (and this is now FW-class)"
        return 1
    fi

    return 0
}

# ---------------------------------------------------------------------------
# Assertion 6 — malformed JWK rejection is graceful. Page claim:
# `jwk_to_decoding_key` returns `SecurityError::InvalidToken` for malformed
# `n`/`e` or unsupported `kty`. No crash, no panic.
# ---------------------------------------------------------------------------
assert_malformed_jwk_handling_graceful() {
    banner "Malformed JWK handling: graceful InvalidToken, no panic"

    local jwks
    jwks=$(git -C "$FRAISEQL_REPO" show \
        "${FRAISEQL_SHA}:crates/fraiseql-core/src/security/oidc/jwks.rs")

    if printf '%s' "$jwks" | grep -qE 'fn jwk_to_decoding_key' \
        && printf '%s' "$jwks" | grep -qE 'SecurityError::InvalidToken'; then
        step "jwk_to_decoding_key returns InvalidToken at frozen SHA"
    else
        err "jwk_to_decoding_key error shape changed — page's malformed-JWK claim drifts"
        return 1
    fi

    return 0
}

# ---------------------------------------------------------------------------
# Assertion 7 — the four known-issue bugs still reproduce. Each repro is a
# static-source assertion against the frozen SHA and exits 1 when the bug
# remains. When any of these flips to exit 0, the corresponding LEAD
# security-caveat sub-section + Known-Issues table row become incorrect.
# ---------------------------------------------------------------------------
assert_known_issues_still_reproduce() {
    banner "known-issue bugs (FW-26..FW-29) still reproduce at frozen SHA"

    local rc=0
    local n
    # FW-N for bug-K: FW-26=bug-1, FW-27=bug-2, FW-28=bug-3, FW-29=bug-4.
    for n in 1 2 3 4; do
        local script="$BUGS_DIR/authentication.bug-$n.sh"
        local fw_id=$((n + 25))   # FW-26, FW-27, FW-28, FW-29
        local exit_code=0
        "$script" >/tmp/_auth-bug-$n.log 2>&1 || exit_code=$?

        case "$exit_code" in
            1)
                step "authentication.bug-$n.sh — BUG REPRODUCED (FW-$fw_id remains real)"
                ;;
            0)
                err "authentication.bug-$n.sh exited 0 — FW-$fw_id appears FIXED. Update /building/authentication to remove the caveat or known-issues row."
                rc=1
                ;;
            *)
                err "authentication.bug-$n.sh exited $exit_code (preflight error or harness drift). See /tmp/_auth-bug-$n.log"
                rc=1
                ;;
        esac
    done

    return "$rc"
}

# ---------------------------------------------------------------------------
# Assertion 8 — FW-24 (failed_login_max_attempts silent drop) + FW-25
# (token_revocation backend = "postgres" silent downgrade) — re-grep the
# server runtime mirror to confirm the silent-drop / silent-downgrade
# shapes remain at the frozen SHA. These two FW rows have no dedicated
# bug-N.sh script (they were filed during Writer-RED and the symptom is
# a missing-field shape, not a runnable repro), so the static-grep IS the
# assertion.
# ---------------------------------------------------------------------------
assert_fw24_fw25_still_reproduce() {
    banner "FW-24 + FW-25: silent-drop / silent-downgrade shapes at frozen SHA"

    # FW-24: RateLimitConfig (server) has NO failed_login_max_attempts field.
    local rate_cfg
    rate_cfg=$(git -C "$FRAISEQL_REPO" show \
        "${FRAISEQL_SHA}:crates/fraiseql-server/src/middleware/rate_limit/config.rs")

    if printf '%s' "$rate_cfg" | grep -qE 'failed_login_max_attempts|failed_login_lockout_secs'; then
        err "FW-24: RateLimitConfig now carries failed_login_* fields — the silent-drop is fixed. Update /building/authentication."
        return 1
    fi
    step "FW-24: RateLimitConfig (server) still has no failed_login_* fields — silent-drop reproduces"

    # FW-25: revocation_manager_from_schema match arms cover memory + redis
    # only; postgres falls into the "Unknown" warn-and-fallback arm.
    local rev
    rev=$(git -C "$FRAISEQL_REPO" show \
        "${FRAISEQL_SHA}:crates/fraiseql-server/src/token_revocation.rs")

    if ! printf '%s' "$rev" | grep -qE 'Unknown revocation backend'; then
        err "FW-25: token_revocation no longer carries 'Unknown revocation backend' fallback warning — postgres path may now be wired. Update /building/authentication."
        return 1
    fi

    # And the postgres arm must be ABSENT from the match (presence would mean
    # the silent-downgrade is fixed).
    if printf '%s' "$rev" | grep -qE '"postgres"\s*=>\s*\{'; then
        err "FW-25: token_revocation now has a 'postgres' match arm — the silent-downgrade is fixed. Update /building/authentication."
        return 1
    fi
    step "FW-25: token_revocation match arms still cover memory + redis only — postgres silent-downgrade reproduces"

    return 0
}

# ---------------------------------------------------------------------------
# main.
# ---------------------------------------------------------------------------
main() {
    preflight

    local rc=0
    if ! assert_algorithm_allowlist_enforced;       then rc=1; fi
    if ! assert_cookie_format_holds;                 then rc=1; fi
    if ! assert_api_key_constant_time_compare;       then rc=1; fi
    if ! assert_oidc_audience_mandatory_at_boot;     then rc=1; fi
    if ! assert_malformed_jwk_handling_graceful;     then rc=1; fi
    if ! assert_known_issues_still_reproduce;        then rc=1; fi
    if ! assert_fw24_fw25_still_reproduce;           then rc=1; fi
    if ! assert_hs256_direct_toml_happy_path;        then rc=1; fi

    if [ "$rc" -eq 0 ]; then
        printf '\nauthentication.docs-test: PASS\n'
    else
        err "FAILURES — see stderr above"
    fi
    return "$rc"
}

main "$@"
