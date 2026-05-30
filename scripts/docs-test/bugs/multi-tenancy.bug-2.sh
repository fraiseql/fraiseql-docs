#!/usr/bin/env bash
#
# multi-tenancy.bug-2.sh — reproduction for FW-5.
#
# Filed: https://github.com/fraiseql/fraiseql/issues/332
# Registered: _internal/.plan/framework-qa-triage.md (FW-5)
#
# Persona: Bug-Finder (Opus 4.7), Phase 03 / Cycle 1 RED.
# Frozen FraiseQL SHA: d0a4ed4ec1770c70707f68fd9019f2b561d87461 (v2.3.2).
#
# ============================================================================
# Expected (per CHANGELOG v2.2.0 "Added — Multi-tenancy support" and per
# tenant_registry.rs:L99 + L167-L182):
#
#   "Tenant is suspended — data requests return 503 with `Retry-After: 60`."
#
#   The registry layer makes that promise explicit: `executor_for(Some(key))`
#   on a registered-but-suspended tenant returns
#     FraiseQLError::ServiceUnavailable { retry_after: Some(60), .. }
#
# Actual (at frozen SHA, crates/fraiseql-server/src/routes/graphql/handler.rs:L577-L583):
#
#   The GraphQL handler maps EVERY error from `executor_for_tenant(...)` to
#   `ErrorCode::Forbidden` regardless of the underlying FraiseQLError variant.
#   The `retry_after` payload on `FraiseQLError::ServiceUnavailable` is
#   silently discarded; no `Retry-After: 60` HTTP header is emitted on the
#   response.
#
# Consequence (operational + spec drift):
#   1. Operators who promised their downstream clients "honour Retry-After on
#      503 to back off" get nothing — the 503 is reshaped to 403.
#   2. The visible HTTP status no longer distinguishes "tenant unknown"
#      (403, retry pointless) from "tenant suspended" (503, retry in 60s).
#      Monitoring and runbooks that key on those codes (per the CHANGELOG
#      contract) silently break.
#   3. The same shape leaks for any future ServiceUnavailable variant routed
#      through `executor_for_tenant` (e.g. registry health-check signalling).
#
# This script is a pure static-source reproduction. The runtime registry that
# would emit the suspended path is not wired into the off-the-shelf binary
# (#330), so a runtime curl reproduction is unreachable until #330 lands.
# The static shape is sufficient to demonstrate the mapping is incorrect for
# the suspend/resume lifecycle the CHANGELOG ships as v2.2.0.
#
# Exit codes:
#   0  — bug NOT reproduced (the handler now maps ServiceUnavailable separately
#        from Authorization).
#   1  — bug REPRODUCED (every executor_for_tenant error becomes Forbidden).
# ============================================================================

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
FRAISEQL_REPO="$(cd "$HERE"/../../../fraiseql && pwd)"
FRAISEQL_SHA="$(cat "$HERE/FRAISEQL_SHA")"

echo "================================================================"
echo "FW-5 reproduction — Suspended tenant returns 403, drops Retry-After: 60"
echo "FraiseQL SHA: $FRAISEQL_SHA"
echo "================================================================"

if ! git -C "$FRAISEQL_REPO" cat-file -e "$FRAISEQL_SHA"; then
    echo "ERROR: frozen SHA $FRAISEQL_SHA not present in $FRAISEQL_REPO" >&2
    exit 2
fi

# 1. Confirm the registry's promise: executor_for(Suspended) returns ServiceUnavailable + retry_after=60.
echo
echo "Registry-layer promise (tenant_registry.rs):"
git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/routes/graphql/tenant_registry.rs" |
    grep -nE "SUSPENDED_RETRY_AFTER_SECS|ServiceUnavailable|retry_after" |
    head -10

# 2. Confirm the handler discards the variant and forces Forbidden.
handler_lines=$(
    git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/routes/graphql/handler.rs" |
        grep -n "executor_for_tenant" |
        head -1 |
        cut -d: -f1
)
if [[ -z "${handler_lines:-}" ]]; then
    echo "BUG NOT REPRODUCED (or source moved): executor_for_tenant call site missing in handler.rs." >&2
    exit 0
fi

echo
echo "Handler mapping (handler.rs:$handler_lines and following):"
git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/routes/graphql/handler.rs" |
    sed -n "${handler_lines},$((handler_lines+8))p"

# 3. Look across the handler for ANY ServiceUnavailable-aware branch in the
#    surrounding 30 lines. Absence is the bug signal.
handler_window=$(
    git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/routes/graphql/handler.rs" |
        sed -n "$((handler_lines-2)),$((handler_lines+15))p"
)

echo
echo "================================================================"
echo "Bug-shape assertion:"
echo "================================================================"

forbidden_hit=$(printf '%s\n' "$handler_window" | grep -c 'ErrorCode::Forbidden' || true)
service_unavailable_hit=$(printf '%s\n' "$handler_window" | grep -c 'ServiceUnavailable\|ErrorCode::ServiceUnavailable\|retry_after' || true)

echo "Forbidden mappings in the executor_for_tenant window: $forbidden_hit"
echo "ServiceUnavailable / retry_after branches in same window: $service_unavailable_hit"

if [[ "$forbidden_hit" -ge 1 && "$service_unavailable_hit" -eq 0 ]]; then
    cat <<MSG
BUG REPRODUCED.

The handler maps every variant of FraiseQLError out of
state.executor_for_tenant(...) to ErrorCode::Forbidden. The registry's
SUSPENDED_RETRY_AFTER_SECS (= 60) constant is unreachable from the GraphQL
response path; no Retry-After: 60 header is emitted on a suspended-tenant
query.

Suggested fix: match the FraiseQLError variant returned by executor_for_tenant:
  - FraiseQLError::Authorization → ErrorCode::Forbidden (HTTP 403, no retry)
  - FraiseQLError::ServiceUnavailable { retry_after, .. } → ErrorCode::ServiceUnavailable
    (HTTP 503; propagate retry_after as a Retry-After response header)

Affected page draft: /building/multi-tenancy "Suspend / resume lifecycle"
section must NOT promise 503 + Retry-After against the off-the-shelf binary
at this SHA; it can promise it against the library API (the registry layer
honours the contract) but the HTTP edge collapses both errors to 403.
MSG
    exit 1
fi

echo "BUG NOT REPRODUCED — handler now distinguishes ServiceUnavailable; close FW-5 with a follow-up." >&2
exit 0
