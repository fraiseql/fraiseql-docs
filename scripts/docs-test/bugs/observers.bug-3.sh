#!/usr/bin/env bash
#
# observers.bug-3.sh — reproduction for FW-18 (webhook actions are NOT
# signed; receivers have no way to verify the event came from FraiseQL).
#
# Filed: https://github.com/fraiseql/fraiseql/issues/<TBD>
# Registered: _internal/.plan/framework-qa-triage.md (FW-18)
#
# Persona: Bug-Finder (Opus 4.7), Phase 03 / Cycle 3 RED.
# Frozen FraiseQL SHA: d0a4ed4ec1770c70707f68fd9019f2b561d87461 (v2.3.2).
#
# ============================================================================
# Expected (per /building/observer-webhook-patterns.mdx, which the docs
# pages today document as the "receiver-side HMAC verification" pattern
# — see e.g. typical webhook-signature schemes such as Stripe's
# `Stripe-Signature` or GitHub's `X-Hub-Signature-256` header):
#
#   The framework should sign every outbound webhook with HMAC over
#   the body, using a per-observer or per-deployment secret, and emit
#   an `X-FraiseQL-Signature` / `X-Webhook-Signature` / equivalent
#   header. Receivers verify the signature before trusting the body.
#
#   Without signing, a webhook receiver has no way to distinguish a
#   FraiseQL-issued event from a forgery posted by any client with
#   network access to the receiver URL.
#
# Actual (at frozen SHA):
#
#   WebhookAction::execute at crates/fraiseql-observers/src/actions.rs:
#   L241-L300 sends an unsigned POST. The full code path:
#
#       let mut request = self.client.post(url);
#       for (key, value) in headers {           # operator-supplied only
#           request = request.header(key, value);
#       }
#       request.json(&body).send().await
#
#   There is NO HMAC computation, NO signature header injection, NO
#   `Authorization` header set by the framework. Whatever the operator
#   places in the per-observer `headers` map is what the receiver gets
#   — and those headers are stored in plaintext in `tb_observer`.
#
#   A grep across the whole fraiseql-observers crate (src/, excluding
#   benches and docs) returns ZERO hits for `hmac`, `signature`,
#   `Sha256`, or `X-Webhook-Signature` in any non-test source file.
#   (The crate does not depend on the `hmac` or `sha2` crates.)
#
# Consequence (regression severity, contract violation; security):
#
#   1. The /building/observer-webhook-patterns page documents a
#      verification pattern that cannot be implemented on the
#      receiver side because there is no signing input from FraiseQL.
#   2. Any attacker who can guess the webhook URL can forge events.
#      If the receiver acts on the body (charges a card, ships a
#      product, sends a confirmation email), forged events trigger
#      those side effects.
#   3. The operator's only mitigation is mTLS or shared-secret
#      bearer auth via the `headers` map — both of which require the
#      secret to travel through `tb_observer` (where it is stored in
#      plaintext JSONB, and exposed via `GET /api/observers/{id}`).
#
# This script is a static-source reproduction. It asserts:
#   (a) `WebhookAction::execute` has no HMAC/signature-header path.
#   (b) The entire `fraiseql-observers` crate `src/` contains zero
#       references to HMAC or signature primitives.
#   (c) The crate's Cargo.toml does not depend on `hmac` or `sha2`.
#
# Exit codes:
#   0  — bug NOT reproduced (HMAC signing now present) — file follow-up.
#   1  — bug REPRODUCED (no signing at frozen SHA).
# ============================================================================

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
FRAISEQL_REPO="$(cd "$HERE"/../../../fraiseql && pwd)"
FRAISEQL_SHA="$(cat "$HERE/FRAISEQL_SHA")"

echo "================================================================"
echo "FW-18 reproduction — webhook payloads are NOT signed by FraiseQL"
echo "FraiseQL SHA: $FRAISEQL_SHA"
echo "================================================================"

if ! git -C "$FRAISEQL_REPO" cat-file -e "$FRAISEQL_SHA"; then
    echo "ERROR: frozen SHA $FRAISEQL_SHA not present in $FRAISEQL_REPO" >&2
    exit 2
fi

ACTIONS=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-observers/src/actions.rs")

# (a) WebhookAction::execute has no HMAC path.
echo
echo "WebhookAction::execute body (key lines):"
exec_body=$(printf '%s\n' "$ACTIONS" | awk '/pub async fn execute/,/^    }/')
hmac_hits=$(printf '%s\n' "$exec_body" | grep -nE 'hmac|signature|sha256|X-Webhook|X-FraiseQL-Signature' || true)
if [[ -z "$hmac_hits" ]]; then
    echo "  (no matches — no signing)"
else
    printf '%s\n' "$hmac_hits"
fi

if printf '%s\n' "$exec_body" | grep -qiE 'hmac::|sign_payload|x-webhook-signature|x-fraiseql-signature'; then
    echo "BUG NOT REPRODUCED: WebhookAction::execute now signs payloads." >&2
    exit 0
fi

# (b) Whole-crate grep for HMAC / signature primitives (src only).
echo
echo "Cross-crate grep for HMAC / signature primitives in src/:"
hits=$(git -C "$FRAISEQL_REPO" grep -niE "hmac::|sha2::|sign_payload|x-webhook-signature|x-fraiseql-signature" "$FRAISEQL_SHA" -- 'crates/fraiseql-observers/src/' 2>&1 | grep -v '^$' || true)
if [[ -n "$hits" ]]; then
    echo "$hits"
    echo "BUG NOT REPRODUCED: HMAC / signature primitive found in observer crate src/." >&2
    exit 0
fi
echo "  (zero hits in crates/fraiseql-observers/src/)"

# (c) Cargo.toml does not depend on hmac.
#
# Note: `sha2` is a legitimate dependency for the cache key-hashing path
# (used in cache/mod.rs as a key-derivation function for the action-result
# cache, NOT for webhook signing). The signing test is hmac — a sha2 hash
# is not by itself a MAC. We assert specifically on `hmac` here.
echo
echo "fraiseql-observers Cargo.toml dependencies on hmac:"
CARGO=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-observers/Cargo.toml")
printf '%s\n' "$CARGO" | grep -iE '^hmac\s*=' || echo "  (no hmac dependency)"

if printf '%s\n' "$CARGO" | grep -qiE '^hmac\s*='; then
    echo "BUG NOT REPRODUCED: observer crate now depends on hmac." >&2
    exit 0
fi

# (d) Cross-crate, confirm `sha2` usage is for cache keys (cache/mod.rs),
# NOT for webhook signing.
echo
echo "sha2 actual usage sites:"
git -C "$FRAISEQL_REPO" grep -nE "use sha2|sha2::|Sha256::" "$FRAISEQL_SHA" -- 'crates/fraiseql-observers/src/' 2>&1 | head -10 || true

cat <<'MSG'

================================================================
Bug-shape assertion:
================================================================
- WebhookAction::execute has no HMAC computation, no signature
  header injection, no body-digest header.
- The whole fraiseql-observers src/ tree has zero references to
  hmac, sha2, X-Webhook-Signature, or X-FraiseQL-Signature.
- The crate does not depend on the `hmac` or `sha2` crates.

BUG REPRODUCED.

Impact (regression severity; security):
  - The /building/observer-webhook-patterns page advertises a
    receiver-side HMAC verification pattern that has no FraiseQL-side
    signing input to verify against.
  - Receivers cannot distinguish a FraiseQL-issued webhook from a
    forgery posted by any client with the receiver URL.
  - Operators' only mitigation is per-observer bearer secrets in the
    `headers` map, which travel through tb_observer in plaintext JSONB
    and are exposed via GET /api/observers/{id}.

Suggested fix:
  1. Add an optional `signing_secret_env: String` (env-var name) to
     ObserverDefinition or ActionConfig::Webhook.
  2. On dispatch, compute `HMAC-SHA256(body_bytes, secret)` and inject
     header `X-FraiseQL-Signature-256: t=<unix_ts>,v1=<hex>` (Stripe-
     compatible shape).
  3. Document the receiver-side verification snippet in
     /building/observer-webhook-patterns with a concrete example.

Affected page draft: /features/observers, /building/observer-webhook-
patterns, /operations/observer-runbook.
Until fixed:
  - /features/observers MUST state "webhook payloads are NOT signed
    today (FW-18)" — no HMAC, no `X-FraiseQL-Signature` header.
  - /building/observer-webhook-patterns MUST recommend operator-side
    bearer secrets via the `headers` map + reverse-proxy mTLS as the
    only verification path, AND document the plaintext-storage
    caveat.
  - The page MUST NOT lean on a "verify the HMAC" pattern that cannot
    be implemented today.
MSG
exit 1
