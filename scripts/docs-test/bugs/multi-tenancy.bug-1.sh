#!/usr/bin/env bash
#
# multi-tenancy.bug-1.sh — reproduction for FW-4.
#
# Filed: https://github.com/fraiseql/fraiseql/issues/331
# Registered: _internal/.plan/framework-qa-triage.md (FW-4)
#
# Persona: Bug-Finder (Opus 4.7), Phase 03 / Cycle 1 RED.
# Frozen FraiseQL SHA: d0a4ed4ec1770c70707f68fd9019f2b561d87461 (v2.3.2).
#
# ============================================================================
# Expected (per CHANGELOG v2.2.0 and per source comment in subscriptions.rs:181):
#
#   The WebSocket subscription endpoint resolves the tenant key the same way
#   the GraphQL handler does:
#     - JWT `tenant_id` claim has highest precedence
#     - X-Tenant-ID header is validated and used if no JWT
#     - Host header maps through the DomainRegistry if no JWT/X-Tenant-ID
#     - When the schema has RLS configured, cross-source conflicts are
#       rejected (strict mode) per `handler.rs:L506-L515`
#
# Actual (at frozen SHA, crates/fraiseql-server/src/routes/subscriptions.rs:L183):
#
#   The subscription handler calls
#     TenantKeyResolver::resolve(None, &headers, None, false)
#   regardless of:
#     - whether the request was authenticated (security_context = None always),
#     - whether the schema has RLS configured (strict = false always),
#     - whether a DomainRegistry is installed (domain_registry = None always).
#
# Consequence (security):
#   1. A WebSocket client can authenticate with a JWT whose `tenant_id` claim
#      says `bar` and still send `X-Tenant-ID: foo` over the upgrade request.
#      The subscription connection is tagged with tenant `foo`. The JWT claim
#      is silently discarded.
#   2. Even when the schema has RLS configured (which forces strict cross-source
#      validation on the GraphQL path), strict mode is unconditionally off here
#      — conflicting X-Tenant-ID and Host-mapped tenant values do not error.
#   3. The DomainRegistry is unreachable from subscriptions even when the host
#      binary installs one (`AppState::with_domain_registry`), because the
#      handler's call site hard-codes `None`.
#
# This script is a pure static-source reproduction: it confirms the divergence
# between the GraphQL handler and the subscription handler at the frozen SHA.
# The runtime binary does not wire the tenant registry by default (#330), so
# this static check is the most reliable signal until #330 lands.
#
# Exit codes:
#   0  — bug NOT reproduced (the subscription handler now matches the GraphQL
#        handler's resolver call shape) — file a follow-up to close FW-4.
#   1  — bug REPRODUCED (the divergence still exists at the frozen SHA).
# ============================================================================

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
FRAISEQL_REPO="$(cd "$HERE"/../../../fraiseql && pwd)"
FRAISEQL_SHA="$(cat "$HERE/FRAISEQL_SHA")"

echo "================================================================"
echo "FW-4 reproduction — WebSocket subscription bypasses JWT + strict mode"
echo "FraiseQL SHA: $FRAISEQL_SHA"
echo "================================================================"

if ! git -C "$FRAISEQL_REPO" cat-file -e "$FRAISEQL_SHA"; then
    echo "ERROR: frozen SHA $FRAISEQL_SHA not present in $FRAISEQL_REPO" >&2
    exit 2
fi

handler_line=$(
    git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/routes/graphql/handler.rs" |
        grep -n "TenantKeyResolver::resolve" |
        head -1 |
        cut -d: -f1
)
sub_line=$(
    git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/routes/subscriptions.rs" |
        grep -n "TenantKeyResolver::resolve" |
        head -1 |
        cut -d: -f1
)

if [[ -z "${handler_line:-}" || -z "${sub_line:-}" ]]; then
    echo "BUG NOT REPRODUCED (or source moved): TenantKeyResolver::resolve call not found in expected files." >&2
    echo "  handler.rs hit: ${handler_line:-MISSING}"
    echo "  subscriptions.rs hit: ${sub_line:-MISSING}"
    exit 0
fi

echo
echo "Handler call (handler.rs:$handler_line and following — expected: security_context.as_ref(), strict_tenant_validation):"
git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/routes/graphql/handler.rs" |
    sed -n "$((handler_line-3)),$((handler_line+8))p"

echo
echo "Subscription call (subscriptions.rs:$sub_line and following — expected to match handler, observed: None, None, false):"
git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/routes/subscriptions.rs" |
    sed -n "$((sub_line-2)),$((sub_line+4))p"

# The bug-shape we are asserting: subscriptions.rs passes literal `None, ..., None, false`.
# Use a very specific match so a fix (passing a real security context or a configurable
# strict flag) flips this script's exit code.
sub_call=$(
    git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/routes/subscriptions.rs" |
        sed -n "${sub_line}p"
)

echo
echo "================================================================"
echo "Bug-shape assertion:"
echo "================================================================"
echo "Subscription resolver call line: $sub_call"

if printf '%s' "$sub_call" | grep -Eq 'TenantKeyResolver::resolve\(None,[[:space:]]*&headers,[[:space:]]*None,[[:space:]]*false\)'; then
    cat <<MSG
BUG REPRODUCED.

The WebSocket subscription endpoint hard-codes:
  - security_context = None  (JWT tenant_id claim is dropped)
  - domain_registry  = None  (Host-header → tenant mapping unreachable)
  - strict           = false (cross-source conflicts are not enforced even when RLS is configured)

Compare with GraphQL handler (handler.rs:$handler_line region above) which passes
the real security_context, the installed domain_registry, and a strict flag that
follows schema.has_rls_configured().

Suggested fix: extract an AuthUser or SecurityContext from request extensions
(populated by the OIDC auth middleware when subscription_require_auth = true),
pass state.domain_registry() through to the resolver, and use the schema's
has_rls_configured() to drive strict mode — mirroring the GraphQL handler.

Affected page draft: /building/multi-tenancy "Dispatch sources" section must
note that the WebSocket subscription path silently drops JWT-derived tenant
context and disables strict validation at the frozen SHA.
MSG
    exit 1
fi

echo "BUG NOT REPRODUCED — subscription handler no longer matches the (None,_,None,false) shape. File a follow-up." >&2
exit 0
