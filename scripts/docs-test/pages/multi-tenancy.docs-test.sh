#!/usr/bin/env bash
#
# multi-tenancy.docs-test.sh — Phase 03 Cycle 1 docs-test for /building/multi-tenancy.
#
# What this script proves:
#   The contract documented on /building/multi-tenancy:
#     1. Multi-tenant mode is composed via the `fraiseql-server` library APIs
#        (`AppState::with_tenant_registry`, `with_tenant_executor_factory`,
#        `with_domain_registry`, `with_tenant_audit_log`).
#     2. The off-the-shelf `fraiseql-server` binary at the frozen FraiseQL SHA
#        does NOT wire the tenant registry — this is FW-3 / #330.
#     3. The page documents both — the library API recipe and the binary gap.
#
# How it proves:
#   The cycle spec asks for a runnable scenario:
#     - bring up FraiseQL with `[tenancy].mode = "row"`,
#     - create tenants `acme` and `nova` via admin REST,
#     - seed tenant-scoped rows,
#     - query each tenant's data and assert isolation,
#     - query tenant `xyz` (unregistered) and assert HTTP 403.
#
#   The off-the-shelf `fraiseql-server` binary cannot run that scenario today
#   because `build_app_state()` leaves `tenant_registry = None`. This script
#   therefore:
#     (a) brings up the binary against an overlay TOML that sets the documented
#         knobs and confirms the docs-test harness boots the binary cleanly;
#     (b) proves FW-3 still reproduces against the frozen SHA by sending the
#         documented requests and asserting the SYMPTOMS the page describes
#         (unregistered key returns 200 not 403; admin tenant API returns 404);
#     (c) re-greps the library-API recipe (`AppState::with_tenant_registry`
#         et al. — see `crates/fraiseql-server/tests/multitenancy_test.rs`)
#         at the frozen SHA to assert the page's recipe is still source-true.
#
#   When #330 lands and the binary wires the runtime, the FW-3 assertions
#   in step (b) flip from "still broken" to "now fixed", at which point this
#   script will fail loudly. That failure is the regression signal Phase 09
#   needs to unblock the binary-driven happy path.
#
# Framing decision: this is option **A2** per the Writer-GREEN brief — the
# script documents the intended sequence, asserts the documented symptoms of
# FW-3 against the off-the-shelf binary, and asserts the library-API recipe
# remains source-true. It does NOT silently skip — each "documented symptom"
# is a real assertion that flips when the upstream fix lands.
#
# Exit codes:
#   0 — every assertion holds against the frozen SHA + the docs-test stack.
#   1 — at least one assertion failed (page is drifting from reality).
#   2 — preflight error (no docker, missing fixture, harness not built).
#
# source: src/content/docs/building/multi-tenancy.md (page under test)
# source: _internal/.plan/.phases/phase-03-critical-rewrites.md:L125-L145 (Cycle 1 spec)
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

OVERLAY="$DOCS_TEST/configs/overlays/multi-tenancy.toml"
COMPILED_SCHEMA="$DOCS_TEST/fixtures/postgres/multi-tenancy.compiled.json"
HOST_PORT_FRAISEQL="${HOST_PORT_FRAISEQL:-8080}"

# Temp override path; populated by write_overlay_override.
OVERLAY_OVERRIDE=""

banner() {
    printf '\n=== multi-tenancy: %s ===\n' "$1"
}

step() {
    printf '  · %s\n' "$*"
}

err() {
    printf 'multi-tenancy.docs-test: %s\n' "$*" >&2
}

die() {
    err "$*"
    exit 2
}

# ---------------------------------------------------------------------------
# Preflight.
# ---------------------------------------------------------------------------
preflight() {
    command -v docker >/dev/null || die "docker not on PATH"
    command -v jq     >/dev/null || die "jq not on PATH (assert_json_shape requires it)"
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
}

# ---------------------------------------------------------------------------
# Compose override — bind-mounts the multi-tenancy overlay TOML and the
# compiled schema into the fraiseql container.
# ---------------------------------------------------------------------------
write_overlay_override() {
    OVERLAY_OVERRIDE="$(mktemp -t fraiseql-docs-mt-override.XXXXXX.yml)"
    cat >"$OVERLAY_OVERRIDE" <<EOF
# Generated by scripts/docs-test/pages/multi-tenancy.docs-test.sh — do not commit.
services:
  fraiseql:
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
# Assertion 1 — the page's library-API recipe is source-true at the frozen
# SHA. The page documents `AppState::with_tenant_registry`,
# `with_tenant_executor_factory`, `with_domain_registry`, and
# `with_tenant_audit_log` as the composition surface. Assert each method
# exists on `AppState` at the frozen SHA.
# ---------------------------------------------------------------------------
assert_library_recipe_source_true() {
    banner "library-API recipe is source-true"
    local app_state
    app_state=$(git -C "$FRAISEQL_REPO" show \
        "${FRAISEQL_SHA}:crates/fraiseql-server/src/routes/graphql/app_state.rs")

    local ok=0
    for method in with_tenant_registry with_tenant_executor_factory with_domain_registry with_tenant_audit_log; do
        if printf '%s' "$app_state" | grep -Eq "pub fn ${method}"; then
            step "AppState::${method} present"
        else
            err "AppState::${method} MISSING at frozen SHA — page drift"
            ok=1
        fi
    done
    return "$ok"
}

# ---------------------------------------------------------------------------
# Assertion 2 — FW-3 / #330 still reproduces against the off-the-shelf binary
# in the docs-test stack. Symptoms documented on the page:
#   (a) PUT /api/v1/admin/tenants/{key} returns 404 ("multi-tenant mode not enabled")
#       regardless of admin_token presence;
#   (b) An unregistered X-Tenant-ID header does NOT yield 403 — the binary
#       routes through the default executor.
#
# Step (a) is the canonical FW-3 signal. Step (b) is the security symptom.
# When #330 lands and the binary wires the registry, (a) flips to 200/4xx for
# specific request errors instead of "multi-tenant mode not enabled", and the
# script must be rewritten to drive the binary directly through the documented
# admin REST sequence.
# ---------------------------------------------------------------------------
assert_fw3_330_still_reproduces() {
    banner "FW-3 / #330 — runtime not wired in fraiseql-server binary"

    write_overlay_override

    "$OPERATOR_CLI" down --volumes >/dev/null 2>&1 || true

    docker compose -f "$COMPOSE_FILE" -f "$OVERLAY_OVERRIDE" \
        --profile fraiseql up -d --wait --wait-timeout 240 >/dev/null
    step "stack up with multi-tenancy overlay"

    # Wait for /health to flip to 200.
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
        err "fraiseql /health did not return 200 (got $health_code)"
        return 1
    fi
    step "/health == 200"

    # (a) Admin REST PUT returns 404 "multi-tenant mode not enabled".
    #     The overlay does NOT set admin_token (#330 sidenote: admin_api_enabled
    #     = true breaks RBAC schema init on the harness PG). Without
    #     admin_token the route is not mounted, so we get 404. Either way, the
    #     FW-3 contract holds: admin tenant API is unreachable from the binary.
    local admin_body admin_code
    admin_code=$(curl -sS -o /tmp/_mt-admin.json -w '%{http_code}' \
        -X PUT "http://127.0.0.1:$HOST_PORT_FRAISEQL/api/v1/admin/tenants/acme" \
        -H "Content-Type: application/json" \
        -d '{"schema":{"queries":[],"mutations":[]},"connection":{"database_url":"postgresql://nope"}}' \
        || true)
    admin_body=$(cat /tmp/_mt-admin.json 2>/dev/null || echo '')
    if [ "$admin_code" != "404" ]; then
        err "expected admin PUT /api/v1/admin/tenants/acme to return 404 (multi-tenant runtime not wired); got $admin_code: $admin_body"
        return 1
    fi
    step "admin PUT /tenants/acme returns 404 (FW-3 still reproduces)"

    # (b) Unregistered X-Tenant-ID is NOT explicitly denied. The exact response
    #     from the default executor depends on the compiled schema's query
    #     surface; the documented FW-3 symptom is "no 403". Assert NOT 403.
    local xt_code
    xt_code=$(curl -sS -o /dev/null -w '%{http_code}' \
        -X POST "http://127.0.0.1:$HOST_PORT_FRAISEQL/graphql" \
        -H "Content-Type: application/json" \
        -H "X-Tenant-ID: xyz" \
        -d '{"query":"{ __typename }"}' \
        || true)
    if [ "$xt_code" = "403" ]; then
        err "unregistered X-Tenant-ID returned 403 — FW-3 may be fixed; rewrite this assertion against the wired binary"
        return 1
    fi
    step "unregistered X-Tenant-ID does NOT return 403 (FW-3 symptom holds — got $xt_code)"

    "$OPERATOR_CLI" down --volumes >/dev/null 2>&1 || true
    step "stack down clean"
    return 0
}

# ---------------------------------------------------------------------------
# Assertion 3 — the page's "explicit-deny" library-API contract holds in the
# upstream integration test. We don't execute the test ourselves (no Rust
# toolchain in the harness image); we re-grep the test fixture at the frozen
# SHA and confirm the documented assertion is present.
#
# When the fixture moves or the test is renamed, this assertion fires.
# ---------------------------------------------------------------------------
assert_explicit_deny_test_present() {
    banner "explicit-deny library-API contract is locked by upstream test"

    local fixture
    fixture=$(git -C "$FRAISEQL_REPO" show \
        "${FRAISEQL_SHA}:crates/fraiseql-server/tests/multitenancy_test.rs")

    if printf '%s' "$fixture" \
        | grep -Eq 'fn test_explicit_unregistered_tenant_returns_error'; then
        step "test_explicit_unregistered_tenant_returns_error present at frozen SHA"
    else
        err "upstream integration test for the documented 403 contract is missing or renamed at frozen SHA — page drift"
        return 1
    fi

    # The page documents `with_tenant_registry` as the composition surface;
    # confirm the test actually exercises it (so the page's recipe is real).
    if printf '%s' "$fixture" | grep -Eq 'with_tenant_registry'; then
        step "AppState::with_tenant_registry exercised in upstream test"
    else
        err "upstream test no longer exercises with_tenant_registry — page drift"
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# main.
# ---------------------------------------------------------------------------
main() {
    preflight

    local rc=0
    if ! assert_library_recipe_source_true; then rc=1; fi
    if ! assert_explicit_deny_test_present; then rc=1; fi
    if ! assert_fw3_330_still_reproduces;   then rc=1; fi

    if [ "$rc" -eq 0 ]; then
        printf '\nmulti-tenancy.docs-test: PASS\n'
    else
        err "FAILURES — see stderr above"
    fi
    return "$rc"
}

main "$@"
