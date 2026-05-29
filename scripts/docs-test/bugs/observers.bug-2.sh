#!/usr/bin/env bash
#
# observers.bug-2.sh — reproduction for FW-17 (DLQ retry handlers are not
# atomic; two concurrent retries on the same item double-fire the action).
#
# Filed: https://github.com/fraiseql/fraiseql/issues/<TBD>
# Registered: _internal/.plan/framework-qa-triage.md (FW-17)
#
# Persona: Bug-Finder (Opus 4.7), Phase 03 / Cycle 3 RED.
# Frozen FraiseQL SHA: d0a4ed4ec1770c70707f68fd9019f2b561d87461 (v2.3.2).
#
# ============================================================================
# Expected (per the at-least-once delivery contract advertised by both
# /features/observers and /operations/observer-runbook, and the standard
# DLQ-retry pattern where the dequeue → process → ack sequence is an
# atomic claim):
#
#   `POST /api/observers/dlq/{id}/retry` should process the item at most
#   once per HTTP request, even when invoked concurrently. A second
#   request arriving while the first is processing should observe
#   "already being retried" / "not found" and skip — not re-process the
#   same payload.
#
#   `POST /api/observers/dlq/retry-all` should not double-process items
#   that `dlq/{id}/retry` is concurrently handling.
#
# Actual (at frozen SHA,
# crates/fraiseql-server/src/observers/dlq_handlers/mod.rs:L209-L290 for
# the single-item retry, L290-L350 for retry-all):
#
#   dlq_retry_handler does:
#
#       let dlq = runtime.dlq();
#       let Some(item) = dlq.get(id) else { ... NOT_FOUND };
#       let executor_guard = runtime.executor_ref().read().await;
#       let Some(executor) = executor_guard.as_ref() else { ... };
#       match executor.process_event(&item.event).await {
#           Ok(_) => { dlq.remove(id); ... },   // 200 OK
#           Err(e) => { ... 500 Internal },
#       }
#
#   There is NO lock between `dlq.get(id)` and `dlq.remove(id)`. Two
#   concurrent retries on the same id BOTH succeed `dlq.get(id)`, BOTH
#   call `executor.process_event(&item.event)` (which dispatches the
#   action — e.g., HTTP POST to the webhook URL), and BOTH attempt
#   `dlq.remove(id)` (the second is a no-op because items.retain
#   already filtered it).
#
#   The downstream observer SEES THE EVENT TWICE. For a webhook with
#   side effects (charge a card, send an email, push to a queue) this
#   violates the at-least-once → at-least-twice in the retry-race case.
#
#   dlq_retry_all_handler is worse: it iterates `items.clone()` and
#   processes each. If a concurrent `dlq/{id}/retry` arrives mid-loop
#   on item N, item N is processed by BOTH paths.
#
# Consequence (regression severity, contract violation):
#
#   1. Two clicks on an operator "Retry" button cause the webhook to
#      fire twice.
#   2. An operator clicking "Retry all" concurrently with another
#      operator clicking "Retry" on a specific item fires that item's
#      action twice.
#   3. Automation polling /dlq + invoking /dlq/{id}/retry on each entry
#      WHILE another instance polls /dlq/retry-all delivers each event
#      twice.
#
# This script is a static-source reproduction. It asserts:
#   (a) dlq_retry_handler has no claim/lock between get and remove.
#   (b) dlq_retry_all_handler has no per-item claim/lock either.
#   (c) `InMemoryDlq` exposes no `try_claim` / `lock` / atomic-dequeue
#       primitive.
#
# Exit codes:
#   0  — bug NOT reproduced (claim/lock added) — file follow-up.
#   1  — bug REPRODUCED (non-atomic retry at frozen SHA).
# ============================================================================

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
FRAISEQL_REPO="$(cd "$HERE"/../../../fraiseql && pwd)"
FRAISEQL_SHA="$(cat "$HERE/FRAISEQL_SHA")"

echo "================================================================"
echo "FW-17 reproduction — DLQ retry handlers race; double-dispatch"
echo "FraiseQL SHA: $FRAISEQL_SHA"
echo "================================================================"

if ! git -C "$FRAISEQL_REPO" cat-file -e "$FRAISEQL_SHA"; then
    echo "ERROR: frozen SHA $FRAISEQL_SHA not present in $FRAISEQL_REPO" >&2
    exit 2
fi

DLQ=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/observers/dlq_handlers/mod.rs")
RUNTIME=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/observers/runtime.rs")

# (a) dlq_retry_handler body — extract from `pub async fn dlq_retry_handler` to next `^}`.
echo
echo "dlq_retry_handler body (key lines):"
retry_body=$(printf '%s\n' "$DLQ" | awk '/pub async fn dlq_retry_handler/,/^}$/')
printf '%s\n' "$retry_body" | grep -nE 'dlq\.get|dlq\.remove|executor\.process_event|try_claim|claim|lock' | head -20

# Look for any claim/lock primitive between dlq.get and dlq.remove.
if printf '%s\n' "$retry_body" | grep -qE 'try_claim|atomic_dequeue|lock_item|reserve'; then
    echo "BUG NOT REPRODUCED: dlq_retry_handler now uses an atomic claim primitive." >&2
    exit 0
fi

# (b) dlq_retry_all_handler — same check.
echo
echo "dlq_retry_all_handler body (key lines):"
retry_all_body=$(printf '%s\n' "$DLQ" | awk '/pub async fn dlq_retry_all_handler/,/^}$/')
printf '%s\n' "$retry_all_body" | grep -nE 'list_all|process_event|remove|try_claim' | head -20

if printf '%s\n' "$retry_all_body" | grep -qE 'try_claim|reserve|drain_atomic'; then
    echo "BUG NOT REPRODUCED: dlq_retry_all_handler now uses an atomic claim primitive." >&2
    exit 0
fi

# (c) InMemoryDlq exposes no try_claim / atomic-dequeue.
echo
echo "InMemoryDlq impl block surface:"
impl_block=$(printf '%s\n' "$RUNTIME" | awk '/impl InMemoryDlq/,/^}/')
printf '%s\n' "$impl_block" | grep -nE 'fn ' | head -20

if printf '%s\n' "$impl_block" | grep -qE 'fn (try_claim|reserve|atomic_dequeue|lock_item)'; then
    echo "BUG NOT REPRODUCED: InMemoryDlq now exposes a claim primitive." >&2
    exit 0
fi

cat <<'MSG'

================================================================
Bug-shape assertion:
================================================================
- dlq_retry_handler: dlq.get(id) → executor.process_event(&item.event)
  → dlq.remove(id). No lock between get and remove. Two concurrent
  retries on the same id both succeed get(), both dispatch the
  action, both attempt remove() (second is a no-op).
- dlq_retry_all_handler: list_all() snapshot, then iterate process_event
  + remove per item. Concurrent with /dlq/{id}/retry on item N, item
  N's action fires twice.
- InMemoryDlq has no try_claim / reserve / atomic_dequeue method.

BUG REPRODUCED.

Race-window proof-of-impact:
  1. Operator A: POST /api/observers/dlq/<UUID>/retry      (t=0)
  2. Operator B: POST /api/observers/dlq/<UUID>/retry      (t=ε)
     # Both pass dlq.get(<UUID>) successfully
     # Both call executor.process_event(&item.event)
     # → webhook destination receives the SAME event payload TWICE
  3. Operator A: dlq.remove(<UUID>) → succeeds
  4. Operator B: dlq.remove(<UUID>) → no-op (already removed)

Impact (regression severity, contract violation):
  - At-least-once delivery contract slips to at-least-twice in the
    retry race case. For idempotent webhook receivers this is benign;
    for non-idempotent receivers (charge a card, send an email, push
    a queue), every "Retry" double-click is a duplicate side-effect.
  - Same race applies between /dlq/{id}/retry and /dlq/retry-all when
    they overlap on the same item.

Suggested fix:
  1. Add an atomic-claim primitive to InMemoryDlq, e.g.:
        try_claim(id: Uuid) -> Option<DlqItem>
     that removes-and-returns under the mutex; subsequent retries
     observe None.
  2. Or wrap each DLQ entry in an Arc<Mutex<DlqClaim>> with a
     pending_retry: bool flag, set under the items-mutex during the
     get call; release on completion.
  3. Retry-all should drain via try_claim, not iterate over a
     list_all() snapshot.

Affected page draft: /features/observers, /operations/observer-runbook
(retry runbook + DLQ section).
Until fixed:
  - Page MUST warn that concurrent /dlq/{id}/retry calls on the same
    item double-fire the action.
  - Page MUST recommend serialising retry calls (operator-side lock,
    single-replica routing, or running retries from a single admin
    instance).
  - Page MUST NOT advise running /dlq/retry-all concurrently with
    per-item retries.
MSG
exit 1
