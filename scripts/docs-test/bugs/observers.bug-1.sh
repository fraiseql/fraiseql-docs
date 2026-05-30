#!/usr/bin/env bash
#
# observers.bug-1.sh — reproduction for FW-16 (InMemoryDlq is unbounded; the
# documented `max_dlq_size` cap is never honoured by the binary).
#
# Filed: https://github.com/fraiseql/fraiseql/issues/<TBD>
# Registered: _internal/.plan/framework-qa-triage.md (FW-16)
#
# Persona: Bug-Finder (Opus 4.7), Phase 03 / Cycle 3 RED.
# Frozen FraiseQL SHA: d0a4ed4ec1770c70707f68fd9019f2b561d87461 (v2.3.2).
#
# ============================================================================
# Expected (per the doc comment on ObserverRuntimeConfig.max_dlq_size at
# crates/fraiseql-observers/src/config/runtime.rs:L55-L66):
#
#   /// Maximum number of entries the dead letter queue may hold.
#   ///
#   /// When the DLQ reaches this limit, the newest entry is dropped (the
#   /// current failing action is discarded) and a warning is logged. This
#   /// prevents unbounded memory growth under sustained action failures.
#   ///
#   /// Default: `None` (unbounded — matches previous behaviour for
#   /// backwards compatibility).
#   ///
#   /// Recommended production value: `10_000`.
#   #[serde(default)]
#   pub max_dlq_size: Option<usize>,
#
# That promise creates a reader expectation that setting `max_dlq_size =
# 10_000` caps memory growth.
#
# Actual (at frozen SHA):
#
#   1. The binary's `ObserverConfig` (server_config/observers.rs:L99-L130)
#      does NOT expose a `max_dlq_size` field. The library-level
#      `ObserverRuntimeConfig` (which DOES expose it) is not consumed by
#      the binary at all (the binary builds its own `ObserverRuntimeConfig`
#      in extensions.rs:L362-L389 — a server-local type, not the library
#      one).
#
#   2. The binary's DLQ implementation `InMemoryDlq` lives at
#      `crates/fraiseql-server/src/observers/runtime.rs:L687-L772`. Its
#      `push` method is:
#
#          async fn push(...) -> Result<Uuid> {
#              let id = uuid::Uuid::new_v4();
#              let item = DlqItem { ... };
#              let mut items = self.items.lock().expect("...");
#              items.push(item);      // <-- unconditional Vec::push
#              Ok(id)
#          }
#
#      There is no cap check, no eviction, no warning log, no metric.
#      The Vec grows without bound as long as the binary keeps running
#      and webhook deliveries keep failing.
#
#   3. The `validate()` method on the library-level
#      ObserverRuntimeConfig (`config/runtime.rs:L74-L88`) only validates
#      `max_dlq_size > 0` — it never reaches the binary because the
#      binary doesn't deserialise into that type.
#
# Consequence (regression severity, DoS amplifier):
#
#   On a binary with one or more observers whose webhook destinations are
#   down, every failed delivery accumulates a DlqItem in process memory.
#   At a sustained rate of N failed events per second and an average
#   DlqItem footprint of ~1 KB (event payload + action config + error
#   string), the process leaks ~3.6 GB per hour at 1000 events/s. There
#   is no operator escape valve short of restarting the process — which
#   loses every DLQ item (InMemoryDlq does not persist across restarts).
#
# Additional finding — the InMemoryDlq's `mark_retry_failed` method
# REMOVES the item from the DLQ on retry failure (runtime.rs:L760-L771):
#
#       async fn mark_retry_failed(...) -> Result<()> {
#           let mut items = ...;
#           items.retain(|i| i.id != id);   // <-- silently drops the item
#           Ok(())
#       }
#
# The reader expectation (and the field's name) is that a failed retry
# updates the attempt count and re-queues; instead it deletes the item.
# Once a retry fails, that DLQ entry is gone — the operator cannot
# inspect it later or retry again.
#
# Exit codes:
#   0  — bug NOT reproduced (cap honoured) — file follow-up.
#   1  — bug REPRODUCED (unbounded growth at frozen SHA).
# ============================================================================

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
FRAISEQL_REPO="$(cd "$HERE"/../../../fraiseql && pwd)"
FRAISEQL_SHA="$(cat "$HERE/FRAISEQL_SHA")"

echo "================================================================"
echo "FW-16 reproduction — InMemoryDlq unbounded; max_dlq_size ignored"
echo "FraiseQL SHA: $FRAISEQL_SHA"
echo "================================================================"

if ! git -C "$FRAISEQL_REPO" cat-file -e "$FRAISEQL_SHA"; then
    echo "ERROR: frozen SHA $FRAISEQL_SHA not present in $FRAISEQL_REPO" >&2
    exit 2
fi

RUNTIME=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/observers/runtime.rs")
SERVER_CFG=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/server_config/observers.rs")
LIB_CFG=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-observers/src/config/runtime.rs")

# (a) Library-side `max_dlq_size` field exists with a documented cap promise.
echo
echo "Library-side field (config/runtime.rs):"
printf '%s\n' "$LIB_CFG" | grep -nE 'max_dlq_size' | head -5

if ! printf '%s\n' "$LIB_CFG" | grep -q 'pub max_dlq_size: Option<usize>'; then
    echo "BUG NOT REPRODUCED: max_dlq_size field no longer present in the library config." >&2
    exit 0
fi

# (b) Binary-side ObserverConfig has NO max_dlq_size field — silent drop.
echo
echo "Binary-side ObserverConfig fields (server_config/observers.rs):"
printf '%s\n' "$SERVER_CFG" | grep -E '^\s*pub\s+\w+:' | head -10

if printf '%s\n' "$SERVER_CFG" | grep -q 'max_dlq_size'; then
    echo "BUG NOT REPRODUCED: server ObserverConfig now exposes max_dlq_size." >&2
    exit 0
fi

# (c) InMemoryDlq::push has no cap check.
echo
echo "InMemoryDlq impl (runtime.rs):"
push_block=$(printf '%s\n' "$RUNTIME" | awk '/async fn push/,/^    }/' | head -25)
printf '%s\n' "$push_block"

if printf '%s\n' "$push_block" | grep -qE 'max_dlq_size|capacity|truncate|pop_front|drain'; then
    echo "BUG NOT REPRODUCED: InMemoryDlq::push now performs a cap check." >&2
    exit 0
fi

# (d) mark_retry_failed silently drops the item.
echo
echo "InMemoryDlq::mark_retry_failed (runtime.rs):"
mrf_block=$(printf '%s\n' "$RUNTIME" | awk '/async fn mark_retry_failed/,/^    }/' | head -15)
printf '%s\n' "$mrf_block"

if ! printf '%s\n' "$mrf_block" | grep -q 'items.retain'; then
    echo "WARN: mark_retry_failed no longer uses retain(); shape changed." >&2
fi

cat <<'MSG'

================================================================
Bug-shape assertion:
================================================================
- Library-side ObserverRuntimeConfig exposes max_dlq_size: Option<usize>
  with a documented "drop newest + warn" semantics
  (config/runtime.rs:L55-L66).
- Binary-side ObserverConfig (the one the binary actually reads from
  fraiseql.toml) does NOT expose max_dlq_size at all
  (server_config/observers.rs:L99-L130).
- InMemoryDlq::push() does Vec::push() with no cap, no eviction,
  no warning log, no metric.
- InMemoryDlq::mark_retry_failed() silently drops the item from the
  Vec — operator cannot inspect a once-failed retry, cannot retry it
  again, has no audit trail.

BUG REPRODUCED.

Impact (regression severity, DoS amplifier on memory):
  - At sustained webhook delivery failure, the binary's DLQ grows
    without bound until OOM.
  - Restart loses every DLQ item (no persistence).
  - mark_retry_failed deletes the row on failure — there is no
    second chance at a single DLQ entry; the operator must catch
    the failure window before retry-all is invoked.

Suggested fix:
  1. Add `max_dlq_size: Option<usize>` to server `ObserverConfig`,
     thread it into `ObserverRuntime::new`, store it on `InMemoryDlq`.
  2. In `InMemoryDlq::push`: if items.len() >= max, drop newest and
     log warn (matching the library doc-comment contract).
  3. In `InMemoryDlq::mark_retry_failed`: bump `attempts` and keep
     the item, instead of removing it; only remove on operator
     `DELETE /api/observers/dlq/{id}` or on `mark_success`.

Affected page draft: /features/observers + /operations/observer-runbook.
Until fixed:
  - Page MUST state that the binary's DLQ is in-process, unbounded,
    and lost on restart.
  - Page MUST NOT promise `max_dlq_size` as an operator knob.
  - Operations runbook MUST recommend external monitoring on
    `dlq_count` from /api/observers/delivery/health and a manual
    `DELETE` flow.
MSG
exit 1
