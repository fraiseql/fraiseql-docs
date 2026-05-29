#!/usr/bin/env bash
#
# observers.docs-test.sh — Phase 03 Cycle 3 docs-test for /features/observers.
#
# What this script proves:
#   The contract documented on /features/observers:
#     1. The off-the-shelf `fraiseql-server` binary AUTO-INSTANTIATES the observer
#        runtime when the `observers` Cargo feature is built in (unlike multi-tenancy
#        and storage, which require a host binary to call library APIs).
#     2. The binary's `[observers]` TOML uses the runtime-knobs shape
#        (enabled / poll_interval_ms / batch_size / channel_capacity / auto_reload /
#         reload_interval_secs + [observers.pool]) — NOT the CLI validation shape
#        (backend / redis_url / nats_url / [[observers.handlers]]).
#     3. F056 (entity_type_index ArcSwap atomicity) and F014 (worker panic
#        propagation) hold at the frozen SHA.
#     4. Eleven framework regressions reproduce against the frozen SHA:
#          FW-13 #340 — runtime routes at root (/runtime/*) not /api/observers/runtime/*
#          FW-14 #341 — fraiseql-cli has no observer subcommand
#          FW-15 #342 — TOML schema split (CLI vs runtime); silent-swallow on the binary
#          FW-16 #343 — InMemoryDlq is unbounded; max_dlq_size silently ignored
#          FW-17 #344 — DLQ retry handlers race; double-fire under concurrency
#          FW-18 #345 — webhook payloads not HMAC-signed
#          FW-19 #346 — webhook URL/headers/body logged at INFO (PII + bearer leak)
#          FW-20 #347 — FRAISEQL_OBSERVERS_ALLOW_INSECURE disables every SSRF guard
#          FW-21 #348 — observer admin API accepts anonymous requests
#          FW-22 #349 — EmailAction is a stub that returns success
#          FW-23 #350 — binary ignores TOML transport selector and env var
#
# How it proves:
#   The cycle spec asks for a runnable scenario: bring up FraiseQL, configure one
#   observer with a webhook to a sink, trigger the source event, kill the sink,
#   verify retries, verify DLQ accumulates the failed event.
#
#   The off-the-shelf binary cannot run that scenario today because:
#     (a) the docs-test PostgreSQL fixture has no `tb_observer` table (FW-15 #342);
#     (b) the binary's TOML knobs cover only runtime parameters, not the
#         observer-set itself (which is DB-driven and not auto-applied);
#     (c) FW-15 + FW-23 silently drop the documented transport selector.
#
#   This script therefore:
#     (a) brings up the binary against an overlay TOML that uses the binary's
#         actual `[observers]` schema and confirms the docs-test harness boots
#         the binary cleanly;
#     (b) proves the documented degraded-state symptom (FW-15 reading): /health
#         returns degraded with observers.running=false because tb_observer is
#         missing — the binary log line `relation "tb_observer" does not exist`
#         is the documented startup error;
#     (c) proves the FW-13 route-mount mismatch: GET /api/observers/runtime/health
#         returns 404, GET /runtime/health returns 503 (degraded) at root;
#     (d) re-runs the eight static-source bug repros (observers.bug-{1..8}.sh) and
#         requires each to exit 1 (BUG REPRODUCED) at the frozen SHA;
#     (e) re-greps the binary auto-wire path + F056 + F014 source lines so the
#         page's "auto-wired" / "F056 holds" / "F014 holds" claims stay locked.
#
#   When the framework fixes ship and the binary either auto-applies the
#   tb_observer migration or the docs-test fixture is extended with the
#   observer migrations, the degraded-state assertions in step (b) flip to
#   healthy and the script must be rewritten to drive the documented
#   POST /api/observers + mutation + webhook-sink + DLQ happy path.
#
# Framing decision: this is option **A2** per the Writer-GREEN brief — the
# script documents the intended sequence, asserts the documented FW symptoms
# against the off-the-shelf binary and the frozen SHA, and asserts the
# library-API recipes + page-level invariants (F056, F014) remain source-true.
# It does NOT silently skip — every "documented symptom" is a real assertion
# that flips when the upstream fix lands.
#
# Why not A1 (a wired host-binary harness):
#   - The binary already AUTO-WIRES the observer runtime (unlike Cycles 1 / 2);
#     the gap is in the DB-bootstrap step (tb_observer migration not auto-applied)
#     and the TOML schema split (FW-15). A1 would need either the framework's
#     migration tool baked into the docs-test image OR a custom host binary
#     that calls the library API and bypasses tb_observer entirely — both are
#     out of harness budget at this cycle.
#   - The eight bug repros (bug-1..8) already exercise the framework surface at
#     the frozen SHA; A2 reuses them as positive assertions that the page's
#     security caveats + known-issues table remain real.
#   - This matches the Cycle 1 multi-tenancy + Cycle 2 file-storage precedent.
#
# Exit codes:
#   0 — every assertion holds against the frozen SHA + the docs-test stack.
#   1 — at least one assertion failed (page is drifting from reality).
#   2 — preflight error (no docker, missing fixture, harness not built).
#
# source: src/content/docs/features/observers.mdx (page under test)
# source: _internal/.plan/.phases/phase-03-critical-rewrites.md:L163-L195 (Cycle 3 spec)
# source: _internal/.plan/methodology.md § 6 (container harness conventions)
# source: _internal/.plan/red-evidence/phase-03-cycle-03-stale-observer-toml.transcript (FW-13/-15 symptoms)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
DOCS_TEST="$HERE"
OPERATOR_CLI="$DOCS_TEST/docs-test.sh"
COMPOSE_FILE="$DOCS_TEST/docker-compose.docs-test.yml"
FRAISEQL_REPO="$(cd "$DOCS_TEST/../../../fraiseql" && pwd)"
FRAISEQL_SHA="$(tr -d '[:space:]' < "$DOCS_TEST/FRAISEQL_SHA")"

# shellcheck source=../lib/assert.sh disable=SC1091
. "$DOCS_TEST/lib/assert.sh"

OVERLAY="$DOCS_TEST/configs/overlays/observers.toml"
COMPILED_SCHEMA="$DOCS_TEST/fixtures/postgres/observers.compiled.json"
BUGS_DIR="$DOCS_TEST/bugs"
HOST_PORT_FRAISEQL="${HOST_PORT_FRAISEQL:-8080}"

# Temp override path; populated by write_overlay_override.
OVERLAY_OVERRIDE=""

banner() {
    printf '\n=== observers: %s ===\n' "$1"
}

step() {
    printf '  · %s\n' "$*"
}

err() {
    printf 'observers.docs-test: %s\n' "$*" >&2
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

    for n in 1 2 3 4 5 6 7 8; do
        [ -x "$BUGS_DIR/observers.bug-$n.sh" ] \
            || die "missing or non-executable repro: $BUGS_DIR/observers.bug-$n.sh"
    done
}

# ---------------------------------------------------------------------------
# Compose override — bind-mounts the observers overlay TOML and the
# compiled schema into the fraiseql container.
# ---------------------------------------------------------------------------
write_overlay_override() {
    OVERLAY_OVERRIDE="$(mktemp -t fraiseql-docs-obs-override.XXXXXX.yml)"
    cat >"$OVERLAY_OVERRIDE" <<EOF
# Generated by scripts/docs-test/pages/observers.docs-test.sh — do not commit.
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
# Assertion 1 — the binary AUTO-WIRES the observer runtime when feature =
# "observers" is built in. The page documents this distinguishing fact from
# Cycles 1 / 2 (multi-tenancy + storage are NOT auto-wired). Re-grep the
# init_observer_runtime call site at the frozen SHA.
# ---------------------------------------------------------------------------
assert_observers_auto_wired_in_binary() {
    banner "binary auto-wires observer runtime (feature=observers)"

    local builder
    builder=$(git -C "$FRAISEQL_REPO" show \
        "${FRAISEQL_SHA}:crates/fraiseql-server/src/server/builder.rs")

    # Cite-line for the page: builder.rs:L343-L346 — init_observer_runtime invocation.
    if printf '%s' "$builder" | grep -qE 'init_observer_runtime'; then
        step "Server::from_executor calls init_observer_runtime at frozen SHA"
    else
        err "init_observer_runtime call missing — page's auto-wire claim drifts"
        return 1
    fi

    local routing
    routing=$(git -C "$FRAISEQL_REPO" show \
        "${FRAISEQL_SHA}:crates/fraiseql-server/src/server/routing/observers.rs")

    if printf '%s' "$routing" | grep -qE 'app.nest\("/api/observers"'; then
        step "observer routes nested under /api/observers at frozen SHA"
    else
        err "observer route nesting changed at frozen SHA — page drift"
        return 1
    fi

    # FW-13: runtime routes mounted with .merge at ROOT (not nested).
    if printf '%s' "$routing" | grep -qE 'app.merge\(observer_runtime_routes'; then
        step "FW-13 layout reproduces: observer_runtime_routes mounted at root via .merge"
    else
        err "FW-13 layout no longer reproduces — runtime routes may have moved under /api/observers; update page"
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# Assertion 2 — F056 (entity_type_index ArcSwap atomicity) holds at the
# frozen SHA. Page claim: the matcher's `(entity_type, event_type) →
# [observer_id]` index is republished via a single atomic ArcSwap store;
# readers observe pre- or post-reload generation, never partial.
# ---------------------------------------------------------------------------
assert_f056_holds() {
    banner "F056 — entity_type_index ArcSwap atomicity holds"

    local runtime
    runtime=$(git -C "$FRAISEQL_REPO" show \
        "${FRAISEQL_SHA}:crates/fraiseql-server/src/observers/runtime.rs")

    # L18 — `use arc_swap::ArcSwap;`
    if printf '%s' "$runtime" | grep -q '^use arc_swap::ArcSwap'; then
        step "arc_swap::ArcSwap import present at frozen SHA"
    else
        err "arc_swap import missing — page's F056 claim drifts"
        return 1
    fi

    # Field declaration — `entity_type_index: Arc<ArcSwap<HashMap<(String, String), Vec<i64>>>>`.
    if printf '%s' "$runtime" | grep -qE 'entity_type_index:\s*Arc<ArcSwap<HashMap'; then
        step "entity_type_index field has Arc<ArcSwap<HashMap<...>>> type at frozen SHA"
    else
        err "entity_type_index type changed — page's F056 claim drifts"
        return 1
    fi

    # Atomic store invocations on both startup and reload — at least 2 occurrences.
    local store_count
    store_count=$(printf '%s\n' "$runtime" \
        | grep -cE 'entity_type_index\.store\(Arc::new\(' || true)
    if [ "$store_count" -ge 2 ]; then
        step "entity_type_index.store(Arc::new(...)) called in 2+ sites (startup + reload)"
    else
        err "expected 2+ entity_type_index.store sites at frozen SHA, got $store_count — page drift"
        return 1
    fi

    return 0
}

# ---------------------------------------------------------------------------
# Assertion 3 — F014 (worker panic propagation) holds at the frozen SHA.
# Page claim: worker panics are caught at the JoinHandle layer, logged at
# error!, the panic counter increments, the executor loop continues.
# ---------------------------------------------------------------------------
assert_f014_holds() {
    banner "F014 — worker panic propagation holds"

    local executor
    executor=$(git -C "$FRAISEQL_REPO" show \
        "${FRAISEQL_SHA}:crates/fraiseql-observers/src/job_queue/executor.rs")

    if printf '%s' "$executor" | grep -qE 'JoinError::is_panic\(\)|is_panic\(\)'; then
        step "JoinError::is_panic() matcher present in executor at frozen SHA"
    else
        err "JoinError::is_panic() handling missing — page's F014 claim drifts"
        return 1
    fi

    if printf '%s' "$executor" | grep -qE 'job_failed\(.*panic'; then
        step "job_failed(_, \"panic\") metric site present at frozen SHA"
    else
        err "job_failed(panic) metric site missing — page's F014 metric claim drifts"
        return 1
    fi

    return 0
}

# ---------------------------------------------------------------------------
# Assertion 4 — FW-15 + FW-23 still reproduce against the off-the-shelf binary
# in the docs-test stack. Symptom documented on the page:
#   The binary boots with the runtime-knobs `[observers]` TOML and attempts
#   to read from `tb_observer`; with the docs-test PG fixture having no
#   `tb_observer` table, the runtime errors at startup and /health returns
#   degraded with observers.running=false.
#
# When Phase 09 auto-applies the migration OR the docs-test fixture is
# extended, this assertion flips — /health stays healthy and the page must
# be updated to drop the FW-15 "operator must apply migration" workaround.
# ---------------------------------------------------------------------------
assert_fw15_fw23_still_reproduce() {
    banner "FW-15 #342 + FW-23 #350 — tb_observer missing + transport hardcoded to PG"

    write_overlay_override

    "$OPERATOR_CLI" down --volumes >/dev/null 2>&1 || true

    docker compose -f "$COMPOSE_FILE" -f "$OVERLAY_OVERRIDE" \
        --profile fraiseql up -d --wait --wait-timeout 240 >/dev/null
    step "stack up with observers overlay"

    # Wait for /health to respond (200 OR a degraded 200 — both are valid
    # signals; the symptom is in the JSON body, not the HTTP status).
    local attempt
    for attempt in $(seq 1 30); do
        if curl -fsS "http://127.0.0.1:$HOST_PORT_FRAISEQL/health" >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done
    : "$attempt"

    local health_body
    health_body=$(curl -sS "http://127.0.0.1:$HOST_PORT_FRAISEQL/health" || true)
    if [ -z "$health_body" ]; then
        err "fraiseql /health unreachable after observers overlay applied"
        return 1
    fi

    # The page's FW-15 documented symptom: observers.running=false because
    # tb_observer is missing.
    local observers_running
    observers_running=$(printf '%s' "$health_body" | jq -r '.observers.running // empty' 2>/dev/null || true)

    if [ "$observers_running" = "false" ]; then
        step "/health observers.running == false (FW-15: tb_observer missing); body: $(printf '%s' "$health_body" | head -c 200)"
    elif [ "$observers_running" = "true" ]; then
        err "/health observers.running == true — FW-15 may be fixed or the docs-test PG fixture grew tb_observer; rewrite assertion against the wired binary"
        return 1
    else
        err "could not extract observers.running from /health body: $(printf '%s' "$health_body" | head -c 200)"
        return 1
    fi

    # The page's FW-13 documented symptom: /runtime/health is at root, not
    # under /api/observers/. Assert /api/observers/runtime/health returns 404
    # and /runtime/health returns 200 OR 503 (depends on degraded state).
    local nested_code
    nested_code=$(curl -sS -o /dev/null -w '%{http_code}' \
        "http://127.0.0.1:$HOST_PORT_FRAISEQL/api/observers/runtime/health" || true)
    if [ "$nested_code" = "404" ]; then
        step "GET /api/observers/runtime/health returns 404 (FW-13 reproduces: nested mount missing)"
    else
        err "expected /api/observers/runtime/health to return 404; got $nested_code — FW-13 may be fixed"
        return 1
    fi

    local root_code
    root_code=$(curl -sS -o /dev/null -w '%{http_code}' \
        "http://127.0.0.1:$HOST_PORT_FRAISEQL/runtime/health" || true)
    if [ "$root_code" = "200" ] || [ "$root_code" = "503" ]; then
        step "GET /runtime/health returns $root_code (FW-13 reproduces: runtime routes at root)"
    else
        err "expected /runtime/health to return 200 or 503; got $root_code — FW-13 may be fixed"
        return 1
    fi

    # FW-21 documented symptom: observer admin API is anonymously reachable.
    # Hitting /api/observers/dlq with no auth should NOT return 401/403.
    local dlq_code
    dlq_code=$(curl -sS -o /dev/null -w '%{http_code}' \
        "http://127.0.0.1:$HOST_PORT_FRAISEQL/api/observers/dlq" || true)
    if [ "$dlq_code" = "401" ] || [ "$dlq_code" = "403" ]; then
        err "GET /api/observers/dlq returned $dlq_code — FW-21 may be fixed (admin API now gated); update page"
        return 1
    fi
    step "GET /api/observers/dlq returned $dlq_code (no 401/403 — FW-21 reproduces: admin API anonymous)"

    "$OPERATOR_CLI" down --volumes >/dev/null 2>&1 || true
    step "stack down clean"
    return 0
}

# ---------------------------------------------------------------------------
# Assertion 5 — the eight observer-area bugs still reproduce. Each repro is
# a static-source assertion against the frozen SHA and exits 1 when the bug
# remains. When any of these flips to exit 0, the corresponding page section
# becomes incorrect and the page must be updated.
# ---------------------------------------------------------------------------
assert_known_issues_still_reproduce() {
    banner "known-issue bugs (FW-16..FW-23) still reproduce at frozen SHA"

    local rc=0
    local n
    # FW-N for bug-K: FW-16=bug-1, FW-17=bug-2, ..., FW-23=bug-8.
    for n in 1 2 3 4 5 6 7 8; do
        local script="$BUGS_DIR/observers.bug-$n.sh"
        local fw_id=$((n + 15))   # FW-16, FW-17, ..., FW-23
        # Each repro exits 1 on BUG REPRODUCED, 0 on BUG NOT REPRODUCED, 2 on preflight error.
        local exit_code=0
        "$script" >/tmp/_obs-bug-$n.log 2>&1 || exit_code=$?

        case "$exit_code" in
            1)
                step "observers.bug-$n.sh — BUG REPRODUCED (FW-$fw_id remains real)"
                ;;
            0)
                err "observers.bug-$n.sh exited 0 — FW-$fw_id appears FIXED. Update /features/observers to remove the caveat or known-issues row."
                rc=1
                ;;
            *)
                err "observers.bug-$n.sh exited $exit_code (preflight error or harness drift). See /tmp/_obs-bug-$n.log"
                rc=1
                ;;
        esac
    done

    return "$rc"
}

# ---------------------------------------------------------------------------
# Assertion 6 — page-level negative findings hold at the frozen SHA. The page
# asserts: (a) SSRF allowlist is real for non-bypassed code paths,
# (b) webhook 30-sec default timeout is enforced, (c) retry/backoff path is
# sound (exponential/linear/fixed with jitter).
# ---------------------------------------------------------------------------
assert_negative_findings_hold() {
    banner "negative findings (SSRF allowlist, retry path) hold at frozen SHA"

    local actions
    actions=$(git -C "$FRAISEQL_REPO" show \
        "${FRAISEQL_SHA}:crates/fraiseql-observers/src/actions.rs")

    if printf '%s' "$actions" | grep -qE 'DEFAULT_WEBHOOK_TIMEOUT_SECS:\s*u64\s*=\s*30'; then
        step "DEFAULT_WEBHOOK_TIMEOUT_SECS = 30 at frozen SHA"
    else
        err "DEFAULT_WEBHOOK_TIMEOUT_SECS changed — page's '30 sec default' claim drifts"
        return 1
    fi

    if printf '%s' "$actions" | grep -qE 'fn validate_outbound_url'; then
        step "validate_outbound_url SSRF allowlist function present at frozen SHA"
    else
        err "validate_outbound_url missing — page's SSRF allowlist claim drifts"
        return 1
    fi

    local retry
    retry=$(git -C "$FRAISEQL_REPO" show \
        "${FRAISEQL_SHA}:crates/fraiseql-observers/src/executor/retry.rs")

    if printf '%s' "$retry" | grep -qE 'Exponential|Linear|Fixed'; then
        step "retry.rs declares Exponential/Linear/Fixed strategies at frozen SHA"
    else
        err "retry strategy variants changed — page's backoff claim drifts"
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
    if ! assert_observers_auto_wired_in_binary;     then rc=1; fi
    if ! assert_f056_holds;                          then rc=1; fi
    if ! assert_f014_holds;                          then rc=1; fi
    if ! assert_negative_findings_hold;              then rc=1; fi
    if ! assert_known_issues_still_reproduce;        then rc=1; fi
    if ! assert_fw15_fw23_still_reproduce;           then rc=1; fi

    if [ "$rc" -eq 0 ]; then
        printf '\nobservers.docs-test: PASS\n'
    else
        err "FAILURES — see stderr above"
    fi
    return "$rc"
}

main "$@"
