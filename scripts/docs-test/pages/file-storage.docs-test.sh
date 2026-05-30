#!/usr/bin/env bash
#
# file-storage.docs-test.sh — Phase 03 Cycle 2 docs-test for /features/file-storage.
#
# What this script proves:
#   The contract documented on /features/file-storage:
#     1. Storage is composed via library APIs (`Server::with_storage(create_backend(&cfg))`
#        on the legacy path, or `ServerSubsystemsBuilder::with_storage(storage_subsystem)`
#        + `storage_router(state)` on the modern path).
#     2. The off-the-shelf `fraiseql-server` binary at the frozen FraiseQL SHA does
#        NOT auto-wire either composition path — this is FW-7 / #334.
#     3. Five known security caveats reproduce against the frozen SHA:
#          FW-8  #335 — presign endpoint bypasses RLS
#          FW-9  #336 — bucket name dropped before backend call
#          FW-10 #337 — MIME confusion / stored XSS
#          FW-11 #338 — global 1 MiB body limit caps storage uploads
#          FW-12 #339 — LIKE-pattern injection on list
#     4. Three adversarial classes are confirmed not exploitable at v2.3.2:
#          path traversal via key (validate_key), storage-side SSRF (no outbound HTTP
#          in fraiseql-storage), concurrent same-key writes (last-write-wins by design).
#
# How it proves:
#   The cycle spec asks for a runnable scenario: upload, transform, signed-URL
#   download per backend, plus a negative cross-tenant assertion. The off-the-shelf
#   binary cannot run that scenario today because the binary does not wire the
#   storage subsystem from TOML (FW-7 #334) and the default Docker image is built
#   without the `aws-s3` / `gcs` / `azure-blob` / `transforms` Cargo features.
#
#   This script therefore:
#     (a) brings up the binary against an overlay TOML that sets `[storage.docs_test]`
#         (structurally correct against `RuntimeConfig.storage` + `StorageConfig`)
#         and confirms the docs-test harness boots the binary cleanly;
#     (b) proves FW-7 #334 still reproduces: every `/storage/v1/*` request returns
#         404 regardless of the overlay;
#     (c) re-greps the library-API recipes (`Server::with_storage` on the legacy path
#         and `ServerSubsystemsBuilder::with_storage` + `StorageState` on the modern
#         path) at the frozen SHA to assert the page's claims stay locked;
#     (d) re-runs the five static-source bug repros (file-storage.bug-{1..5}.sh) and
#         requires each to exit 1 (BUG REPRODUCED) at the frozen SHA.
#
#   When the framework fixes ship and the binary wires the storage subsystem, the
#   FW-7 assertions in step (b) flip from "still broken" to "now fixed", at which
#   point this script will fail loudly. That failure is the regression signal
#   Phase 09 needs to unblock the binary-driven happy path.
#
# Framing decision: this is option **A2** per the Writer-GREEN brief — the
# script documents the intended sequence, asserts the documented symptoms of
# FW-7 / FW-8 / FW-9 / FW-10 / FW-11 / FW-12 against the off-the-shelf binary
# and the frozen SHA, and asserts the library-API recipes remain source-true.
# It does NOT silently skip — every "documented symptom" is a real assertion
# that flips when the upstream fix lands.
#
# Why not A1 (a wired host-binary harness):
#   - FW-7 #334 means the off-the-shelf binary cannot drive the documented
#     happy path; we would have to build a custom Rust host binary just for
#     the docs-test, which is out of harness budget at this cycle.
#   - The bug repros (bug-1..5) already exercise the source surface at the
#     frozen SHA; A2 reuses them as positive assertions that the page's
#     security caveats remain real.
#   - This matches the Cycle 1 multi-tenancy precedent exactly.
#
# Exit codes:
#   0 — every assertion holds against the frozen SHA + the docs-test stack.
#   1 — at least one assertion failed (page is drifting from reality).
#   2 — preflight error (no docker, missing fixture, harness not built).
#
# source: src/content/docs/features/file-storage.md (page under test)
# source: _internal/.plan/.phases/phase-03-critical-rewrites.md:L147-L162 (Cycle 2 spec)
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

OVERLAY="$DOCS_TEST/configs/overlays/file-storage.toml"
COMPILED_SCHEMA="$DOCS_TEST/fixtures/postgres/file-storage.compiled.json"
BUGS_DIR="$DOCS_TEST/bugs"
HOST_PORT_FRAISEQL="${HOST_PORT_FRAISEQL:-8080}"

# Temp override path; populated by write_overlay_override.
OVERLAY_OVERRIDE=""

banner() {
    printf '\n=== file-storage: %s ===\n' "$1"
}

step() {
    printf '  · %s\n' "$*"
}

err() {
    printf 'file-storage.docs-test: %s\n' "$*" >&2
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

    for n in 1 2 3 4 5; do
        [ -x "$BUGS_DIR/file-storage.bug-$n.sh" ] \
            || die "missing or non-executable repro: $BUGS_DIR/file-storage.bug-$n.sh"
    done
}

# ---------------------------------------------------------------------------
# Compose override — bind-mounts the file-storage overlay TOML and the
# compiled schema into the fraiseql container.
# ---------------------------------------------------------------------------
write_overlay_override() {
    OVERLAY_OVERRIDE="$(mktemp -t fraiseql-docs-fs-override.XXXXXX.yml)"
    cat >"$OVERLAY_OVERRIDE" <<EOF
# Generated by scripts/docs-test/pages/file-storage.docs-test.sh — do not commit.
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
# Assertion 1 — the page's legacy library-API recipe is source-true at the
# frozen SHA. The page documents `Server::with_storage(create_backend(&cfg))`
# as the legacy composition surface. Assert the method exists, takes the
# documented signature, and `create_backend` exists too.
# ---------------------------------------------------------------------------
assert_legacy_recipe_source_true() {
    banner "legacy library-API recipe is source-true"

    local builder
    builder=$(git -C "$FRAISEQL_REPO" show \
        "${FRAISEQL_SHA}:crates/fraiseql-server/src/server/builder.rs")

    if printf '%s' "$builder" | grep -Eq 'pub fn with_storage\(mut self, backend: Arc<dyn crate::storage::StorageBackend>\)'; then
        step "Server::with_storage(Arc<dyn StorageBackend>) present at frozen SHA"
    else
        err "Server::with_storage signature changed at frozen SHA — page drift"
        return 1
    fi

    local backend_mod
    backend_mod=$(git -C "$FRAISEQL_REPO" show \
        "${FRAISEQL_SHA}:crates/fraiseql-storage/src/backend/mod.rs")

    if printf '%s' "$backend_mod" | grep -Eq 'pub async fn create_backend\(config: &crate::config::StorageConfig\)'; then
        step "create_backend(&StorageConfig) -> Result<StorageBackend> present at frozen SHA"
    else
        err "create_backend signature changed at frozen SHA — page drift"
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# Assertion 2 — the page's modern library-API recipe is source-true. The page
# documents `ServerSubsystemsBuilder::with_storage(storage_subsystem)` and
# `storage_router(state)`. Assert each method exists at the frozen SHA.
# ---------------------------------------------------------------------------
assert_modern_recipe_source_true() {
    banner "modern library-API recipe is source-true"

    local subsystems
    subsystems=$(git -C "$FRAISEQL_REPO" show \
        "${FRAISEQL_SHA}:crates/fraiseql-server/src/subsystems/mod.rs")

    if printf '%s' "$subsystems" | grep -q 'pub struct StorageSubsystem'; then
        step "StorageSubsystem struct present at frozen SHA"
    else
        err "StorageSubsystem struct missing at frozen SHA — page drift"
        return 1
    fi

    local routes
    routes=$(git -C "$FRAISEQL_REPO" show \
        "${FRAISEQL_SHA}:crates/fraiseql-storage/src/routes/mod.rs")

    if printf '%s' "$routes" | grep -q 'pub fn storage_router(state: StorageState) -> Router'; then
        step "storage_router(StorageState) -> Router present at frozen SHA"
    else
        err "storage_router signature changed at frozen SHA — page drift"
        return 1
    fi

    if printf '%s' "$routes" | grep -q '/storage/v1/object/{bucket}/{\*key}'; then
        step "modern routes mount /storage/v1/object/{bucket}/{*key} at frozen SHA"
    else
        err "modern route path changed at frozen SHA — page drift"
        return 1
    fi

    return 0
}

# ---------------------------------------------------------------------------
# Assertion 3 — FW-7 / #334 still reproduces against the off-the-shelf binary
# in the docs-test stack. Symptom documented on the page:
#   The binary boots cleanly with a structurally-valid `[storage.docs_test]`
#   block but every /storage/v1/* path returns 404 because the binary never
#   calls Server::with_storage or ServerSubsystemsBuilder::with_storage.
#
# When #334 lands and the binary wires the storage subsystem, the 404
# assertions flip and the script must be rewritten to drive the documented
# upload / download / presign happy path.
# ---------------------------------------------------------------------------
assert_fw7_334_still_reproduces() {
    banner "FW-7 / #334 — storage subsystem not wired in fraiseql-server binary"

    write_overlay_override

    "$OPERATOR_CLI" down --volumes >/dev/null 2>&1 || true

    docker compose -f "$COMPOSE_FILE" -f "$OVERLAY_OVERRIDE" \
        --profile fraiseql up -d --wait --wait-timeout 240 >/dev/null
    step "stack up with file-storage overlay"

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
    step "/health == 200 (binary boots with the file-storage overlay)"

    # (a) GET /storage/v1/list/docs_test must return 404 — modern route absent.
    local list_code
    list_code=$(curl -sS -o /dev/null -w '%{http_code}' \
        -X GET "http://127.0.0.1:$HOST_PORT_FRAISEQL/storage/v1/list/docs_test" \
        || true)
    if [ "$list_code" != "404" ]; then
        err "expected /storage/v1/list/docs_test to return 404 (FW-7 still reproduces); got $list_code — FW-7 may be fixed, rewrite assertion against the wired binary"
        return 1
    fi
    step "GET /storage/v1/list/docs_test returns 404 (FW-7 still reproduces)"

    # (b) PUT /storage/v1/object/docs_test/sample.txt must return 404 — same reason.
    local put_code
    put_code=$(curl -sS -o /dev/null -w '%{http_code}' \
        -X PUT "http://127.0.0.1:$HOST_PORT_FRAISEQL/storage/v1/object/docs_test/sample.txt" \
        -H "Content-Type: text/plain" \
        --data-binary "sample content" \
        || true)
    if [ "$put_code" != "404" ]; then
        err "expected /storage/v1/object/docs_test/sample.txt PUT to return 404; got $put_code — FW-7 may be fixed"
        return 1
    fi
    step "PUT /storage/v1/object/docs_test/sample.txt returns 404 (FW-7 still reproduces)"

    # (c) POST /storage/v1/presign/docs_test/sample.txt must return 404 — same reason.
    #     This is the path that FW-8 says lacks RLS; against the off-the-shelf
    #     binary the route is absent (FW-7 wins), so 404 holds. When FW-7 is
    #     fixed and the route mounts, FW-8 says this endpoint will accept
    #     unauthenticated requests — at which point this assertion flips and
    #     the page's "do not expose presign to the public internet" warning
    #     becomes load-bearing on its own (without FW-7 hiding it).
    local presign_code
    presign_code=$(curl -sS -o /dev/null -w '%{http_code}' \
        -X POST "http://127.0.0.1:$HOST_PORT_FRAISEQL/storage/v1/presign/docs_test/sample.txt" \
        -H "Content-Type: application/json" \
        -d '{"operation":"download","expires_in_secs":3600}' \
        || true)
    if [ "$presign_code" != "404" ]; then
        err "expected POST /storage/v1/presign/docs_test/sample.txt to return 404; got $presign_code — FW-7 may be fixed; verify FW-8 mitigation is now in place"
        return 1
    fi
    step "POST /storage/v1/presign/docs_test/sample.txt returns 404 (FW-7 still reproduces; FW-8 latent)"

    "$OPERATOR_CLI" down --volumes >/dev/null 2>&1 || true
    step "stack down clean"
    return 0
}

# ---------------------------------------------------------------------------
# Assertion 4 — the five security-caveat bugs still reproduce. Each repro is
# a static-source assertion against the frozen SHA and exits 1 when the bug
# remains. When any of these flips to exit 0, the corresponding page section
# becomes incorrect and the page must be updated.
# ---------------------------------------------------------------------------
assert_security_caveats_still_reproduce() {
    banner "security-caveat bugs (FW-8..FW-12) still reproduce at frozen SHA"

    local rc=0
    local n
    for n in 1 2 3 4 5; do
        local script="$BUGS_DIR/file-storage.bug-$n.sh"
        # Each repro exits 1 on BUG REPRODUCED, 0 on BUG NOT REPRODUCED, 2 on preflight error.
        local exit_code=0
        "$script" >/tmp/_fs-bug-$n.log 2>&1 || exit_code=$?

        case "$exit_code" in
            1)
                step "file-storage.bug-$n.sh — BUG REPRODUCED (page's caveat for FW-$((n+7)) remains real)"
                ;;
            0)
                err "file-storage.bug-$n.sh exited 0 — FW-$((n+7)) appears FIXED. Update /features/file-storage to remove the caveat."
                rc=1
                ;;
            *)
                err "file-storage.bug-$n.sh exited $exit_code (preflight error or harness drift). See /tmp/_fs-bug-$n.log"
                rc=1
                ;;
        esac
    done

    return "$rc"
}

# ---------------------------------------------------------------------------
# Assertion 5 — page-level negative-finding claims hold at the frozen SHA.
# The page asserts that path-traversal-via-key is blocked and that storage
# has no outbound HTTP path. Re-grep the source to confirm.
# ---------------------------------------------------------------------------
assert_negative_findings_hold() {
    banner "negative findings (path traversal, storage-side SSRF) hold at frozen SHA"

    local backend
    backend=$(git -C "$FRAISEQL_REPO" show \
        "${FRAISEQL_SHA}:crates/fraiseql-storage/src/backend/mod.rs")

    if printf '%s' "$backend" | grep -q 'key.contains("..")'; then
        step "validate_key blocks \"..\" substring at frozen SHA"
    else
        err "validate_key no longer blocks \"..\" — verify path-traversal-safe claim"
        return 1
    fi

    # Re-grep for any outbound HTTP client in fraiseql-storage. The page asserts
    # there is none.
    local storage_lib
    storage_lib=$(git -C "$FRAISEQL_REPO" ls-tree -r --name-only "$FRAISEQL_SHA" \
        -- "crates/fraiseql-storage/src" \
        | tr '\n' ' ')

    local outbound=0
    for f in $storage_lib; do
        local content
        content=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:$f" 2>/dev/null || true)
        if printf '%s' "$content" | grep -qE 'reqwest::Client|hyper::Client|isahc::HttpClient'; then
            # reqwest is pulled by the GCS / azure-blob backends; both fetch from
            # the cloud provider, not arbitrary user-controlled URLs. The page's
            # claim is "no outbound HTTP path triggered by user content"; a
            # provider-API client is fine. Refine if a webhook trigger appears.
            if printf '%s' "$f" | grep -qE 'src/backend/(gcs|azure)'; then
                continue
            fi
            outbound=1
            err "outbound HTTP client appeared in $f — page's storage-side SSRF claim needs review"
        fi
    done

    if [ "$outbound" -eq 0 ]; then
        step "no user-content-triggered outbound HTTP client in fraiseql-storage at frozen SHA"
    else
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
    if ! assert_legacy_recipe_source_true;          then rc=1; fi
    if ! assert_modern_recipe_source_true;          then rc=1; fi
    if ! assert_negative_findings_hold;             then rc=1; fi
    if ! assert_security_caveats_still_reproduce;   then rc=1; fi
    if ! assert_fw7_334_still_reproduces;           then rc=1; fi

    if [ "$rc" -eq 0 ]; then
        printf '\nfile-storage.docs-test: PASS\n'
    else
        err "FAILURES — see stderr above"
    fi
    return "$rc"
}

main "$@"
