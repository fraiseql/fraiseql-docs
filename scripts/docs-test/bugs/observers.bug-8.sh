#!/usr/bin/env bash
#
# observers.bug-8.sh — reproduction for FW-23 (the binary's observer
# runtime is hard-wired to Postgres LISTEN/NOTIFY — the
# FRAISEQL_OBSERVER_TRANSPORT env var and the library-level
# `[observers.transport]` shape are silently ignored, even when the
# `observers-nats` Cargo feature is compiled in).
#
# Filed: https://github.com/fraiseql/fraiseql/issues/<TBD>
# Registered: _internal/.plan/framework-qa-triage.md (FW-23)
#
# Persona: Bug-Finder (Opus 4.7), Phase 03 / Cycle 3 RED.
# Frozen FraiseQL SHA: d0a4ed4ec1770c70707f68fd9019f2b561d87461 (v2.3.2).
#
# ============================================================================
# Expected (per the library API surface that the docs pages and
# CHANGELOG advertise — `TransportKind` enum with `Postgres`, `Nats`,
# `InMemory` variants at crates/fraiseql-observers/src/config/
# transport.rs:L15-L26, the `FRAISEQL_OBSERVER_TRANSPORT` env var
# parser at L28-L40, and the `observers-nats` Cargo feature on
# `fraiseql-server`):
#
#   An operator with `cargo build --features observers-nats` and
#   `FRAISEQL_OBSERVER_TRANSPORT=nats` set should see the binary's
#   observer runtime subscribe to NATS instead of polling
#   `tb_entity_change_log`.
#
# Actual (at frozen SHA, crates/fraiseql-server/src/observers/
# runtime.rs:L262-L582 — the binary's ObserverRuntime::start):
#
#   The server's `ObserverRuntimeConfig` is a struct DIFFERENT from
#   the library's `ObserverRuntimeConfig` (different module: server/
#   server_config/observers.rs::ObserverConfig vs.
#   observers/src/config/runtime.rs::ObserverRuntimeConfig). The
#   server's version has these fields:
#
#       pool: PgPool,
#       poll_interval_ms: u64,
#       batch_size: usize,
#       channel_capacity: usize,
#       auto_reload: bool,
#       reload_interval_secs: u64,
#
#   There is NO `transport` field. The server unconditionally creates
#   a `ChangeLogListener` (PG LISTEN/NOTIFY poller) at L302-L304:
#
#       let listener_config = ChangeLogListenerConfig::new(self.config.pool.clone())
#           .with_poll_interval(self.config.poll_interval_ms)
#           .with_batch_size(self.config.batch_size);
#
#   The `FRAISEQL_OBSERVER_TRANSPORT` env var read at
#   `crates/fraiseql-observers/src/config/transport.rs:L28-L40` is
#   never consumed by the server binary — the binary doesn't go
#   through `ObserverRuntimeConfig::with_env_overrides`, and doesn't
#   construct a `TransportConfig` at all.
#
#   The `observers-nats` Cargo feature on `fraiseql-server` only adds
#   `fraiseql-observers/nats` to the dependency chain — it does not
#   change the binary's runtime wiring.
#
# Consequence (regression severity, library-vs-binary class):
#
#   1. Documentation pages that advertise `[observers] backend = "nats"`
#      / `FRAISEQL_OBSERVER_TRANSPORT=nats` mislead the reader. The
#      binary boots, swallows the config silently (FW-15), and starts
#      the Postgres listener anyway.
#   2. There is no diagnostic — no `WARN` log saying "you set
#      FRAISEQL_OBSERVER_TRANSPORT but the binary ignores it" — so
#      the operator believes NATS dispatch is happening.
#   3. Same library-vs-binary class as FW-3 (multi-tenancy not auto-
#      wired), FW-7 (storage not auto-wired), FW-15 (TOML schema
#      split). Sibling pattern.
#
# This script is a static-source reproduction. It asserts:
#   (a) The server's `ObserverConfig` (the TOML-deserialised type) has
#       no `transport` / `nats_url` / `backend` field.
#   (b) The server's `init_observer_runtime` unconditionally calls
#       `ObserverRuntimeConfig::new(pool)` — no transport selection.
#   (c) The server's `ObserverRuntime::start` unconditionally creates
#       a `ChangeLogListener` — no `TransportKind` match.
#   (d) The server source never reads `FRAISEQL_OBSERVER_TRANSPORT`.
#
# Exit codes:
#   0  — bug NOT reproduced (transport surfaced through binary) — file
#        follow-up.
#   1  — bug REPRODUCED (binary hard-wired to Postgres at frozen SHA).
# ============================================================================

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
FRAISEQL_REPO="$(cd "$HERE"/../../../fraiseql && pwd)"
FRAISEQL_SHA="$(cat "$HERE/FRAISEQL_SHA")"

echo "================================================================"
echo "FW-23 reproduction — binary ignores FRAISEQL_OBSERVER_TRANSPORT"
echo "FraiseQL SHA: $FRAISEQL_SHA"
echo "================================================================"

if ! git -C "$FRAISEQL_REPO" cat-file -e "$FRAISEQL_SHA"; then
    echo "ERROR: frozen SHA $FRAISEQL_SHA not present in $FRAISEQL_REPO" >&2
    exit 2
fi

SERVER_CFG=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/server_config/observers.rs")
EXT=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/server/extensions.rs")
RUNTIME=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/observers/runtime.rs")

# (a) Server's ObserverConfig has no transport / nats_url / backend.
echo
echo "Server ObserverConfig field list (server_config/observers.rs):"
fields=$(printf '%s\n' "$SERVER_CFG" | grep -E '^\s*pub\s+\w+:' | head -20)
printf '%s\n' "$fields"

if printf '%s\n' "$fields" | grep -qE 'transport|nats_url|backend|TransportKind'; then
    echo "BUG NOT REPRODUCED: server ObserverConfig now exposes a transport field." >&2
    exit 0
fi

# (b) init_observer_runtime unconditionally constructs Postgres-poll config.
echo
echo "init_observer_runtime body (server/extensions.rs):"
init_body=$(printf '%s\n' "$EXT" | awk '/pub\(super\) async fn init_observer_runtime/,/^    }/')
printf '%s\n' "$init_body" | grep -nE 'ObserverRuntimeConfig::new|with_poll_interval|TransportKind|with_env_overrides' || true

if printf '%s\n' "$init_body" | grep -qE 'TransportKind|with_env_overrides|TransportConfig'; then
    echo "BUG NOT REPRODUCED: init_observer_runtime now constructs a TransportConfig." >&2
    exit 0
fi

# (c) ObserverRuntime::start constructs ChangeLogListener unconditionally.
echo
echo "ObserverRuntime::start listener construction (runtime.rs):"
start_listener=$(printf '%s\n' "$RUNTIME" | grep -nE 'ChangeLogListener|ChangeLogListenerConfig' | head -10)
printf '%s\n' "$start_listener"

if ! printf '%s\n' "$start_listener" | grep -q 'ChangeLogListenerConfig::new'; then
    echo "BUG NOT REPRODUCED: ChangeLogListener no longer unconditionally constructed." >&2
    exit 0
fi

# (d) Server source never reads FRAISEQL_OBSERVER_TRANSPORT.
echo
echo "FRAISEQL_OBSERVER_TRANSPORT reads in crates/fraiseql-server/:"
srv_reads=$(git -C "$FRAISEQL_REPO" grep -nE "FRAISEQL_OBSERVER_TRANSPORT" "$FRAISEQL_SHA" -- 'crates/fraiseql-server/' || true)
if [[ -z "$srv_reads" ]]; then
    echo "  (zero reads in crates/fraiseql-server/)"
else
    printf '%s\n' "$srv_reads"
    echo "BUG NOT REPRODUCED: the server crate now reads the transport env var." >&2
    exit 0
fi

# Cross-check: it IS read in the observer library (transport.rs).
echo
echo "FRAISEQL_OBSERVER_TRANSPORT reads in crates/fraiseql-observers/:"
lib_reads=$(git -C "$FRAISEQL_REPO" grep -nE "FRAISEQL_OBSERVER_TRANSPORT" "$FRAISEQL_SHA" -- 'crates/fraiseql-observers/src/' || true)
printf '%s\n' "$lib_reads"

cat <<'MSG'

================================================================
Bug-shape assertion:
================================================================
- Server-side `ObserverConfig` (the TOML-deserialised type) has no
  `transport` field. Only poll_interval_ms / batch_size /
  channel_capacity / auto_reload / reload_interval_secs / pool.
- `init_observer_runtime` constructs the server's
  `ObserverRuntimeConfig` with `.with_poll_interval()` only — no
  `TransportConfig`, no `with_env_overrides()`.
- `ObserverRuntime::start` unconditionally builds a
  `ChangeLogListener` (PG LISTEN/NOTIFY) from the pool.
- `FRAISEQL_OBSERVER_TRANSPORT` is read ONLY in the library
  (transport.rs) — the server crate never references it.

BUG REPRODUCED.

Impact (regression severity; library-vs-binary class):
  - Operator workflow:
      $ export FRAISEQL_OBSERVER_TRANSPORT=nats
      $ fraiseql-server --config fraiseql.toml
    Expected: NATS transport.
    Actual:   silent fallback to Postgres LISTEN/NOTIFY; the env
              var is dropped.
  - No diagnostic log line surfaces the mismatch. The operator
    discovers it only when they notice NATS isn't receiving events.
  - The `observers-nats` Cargo feature changes nothing at the binary's
    runtime wiring — only its dependency closure.

Suggested fix:
  1. Add `transport: TransportConfig` to the server's `ObserverConfig`
     (server_config/observers.rs).
  2. In `init_observer_runtime`, build the library-side
     `ObserverRuntimeConfig` via `.with_env_overrides()` so
     `FRAISEQL_OBSERVER_TRANSPORT` is honoured.
  3. Pick the listener (Postgres / NATS / InMemory) based on the
     transport variant in `ObserverRuntime::start`.

Affected page draft: /features/observers (transport / backend
catalogue), /operations/observer-runbook (env-var reference).
Until fixed:
  - Page MUST state that the off-the-shelf binary supports only the
    Postgres LISTEN/NOTIFY transport.
  - Page MUST NOT advertise `[observers] backend = "nats"` or
    `FRAISEQL_OBSERVER_TRANSPORT=nats` as runtime knobs against the
    binary.
  - The NATS / In-memory paths are library-API only and require a
    host-binary that wires `ObserverRuntimeConfig::with_env_overrides`
    against its own runtime — same library-vs-binary class as FW-3
    (multi-tenancy), FW-7 (storage), and FW-15 (TOML schema split).
MSG
exit 1
