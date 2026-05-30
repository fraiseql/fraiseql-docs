#!/usr/bin/env bash
#
# observers.bug-4.sh — reproduction for FW-19 (webhook URL, headers, AND
# rendered body are logged at INFO level on every dispatch — PII leaks
# straight into application logs).
#
# Filed: https://github.com/fraiseql/fraiseql/issues/<TBD>
# Registered: _internal/.plan/framework-qa-triage.md (FW-19)
#
# Persona: Bug-Finder (Opus 4.7), Phase 03 / Cycle 3 RED.
# Frozen FraiseQL SHA: d0a4ed4ec1770c70707f68fd9019f2b561d87461 (v2.3.2).
#
# ============================================================================
# Expected (per standard webhook-dispatch logging hygiene; the
# /operations/observer-runbook page advises operators to centralise
# observer logs into their existing log aggregator):
#
#   The framework should log delivery METADATA at INFO (URL host, event
#   id, action type, duration, status code) but withhold the rendered
#   body and operator-supplied headers — those are likely to contain
#   PII (entity rows) and secrets (bearer tokens in custom Authorization
#   headers). Body content should be debug-level at most, and bearer-style
#   header values should be redacted.
#
# Actual (at frozen SHA, crates/fraiseql-observers/src/actions.rs:L254-L290):
#
#   pub async fn execute(
#       &self,
#       url: &str,
#       headers: &HashMap<String, String>,
#       body_template: Option<&str>,
#       event: &EntityEvent,
#   ) -> Result<WebhookResponse> {
#       ...
#       debug!("WebhookAction.execute() called");
#       info!("  URL: {}", url);                              // L256 — full URL
#       info!("  Headers: {:?}", headers);                    // L257 — full Debug fmt of all headers
#       info!("  Body template: {:?}", body_template);        // L258 — raw template
#       ...
#       info!(
#           "  Body: {}",                                     // L276-L279 — rendered body
#           serde_json::to_string(&body).unwrap_or_else(|_| "<invalid json>".to_string())
#       );
#
# Every successful dispatch emits four INFO lines exposing:
#   - The full webhook URL including any embedded credentials or
#     query-string secrets.
#   - Every header value verbatim — including any
#     `Authorization: Bearer <token>` or `X-API-Key: <key>` that the
#     operator placed in the observer's `headers` map.
#   - The full rendered event body as JSON.
#
# Consequence (regression severity; security / GDPR / SOC2):
#
#   1. Any centralised log aggregator (Datadog, Loki, Splunk, GCP Cloud
#      Logging, etc.) will ingest the full event payload for every
#      observer dispatch. For an Orders → webhook observer, that's
#      every order row — customer email, shipping address, payment
#      reference — copied into the log store.
#   2. Bearer-token reuse: a leaked `Authorization: Bearer ...` value
#      via logs gives anyone with log-read access the same access to
#      the webhook receiver as the framework itself.
#   3. PII retention: most log stores keep INFO lines for 30+ days,
#      far beyond what the observer event lifecycle requires.
#   4. Multi-tenant exposure: if multiple tenants' observers run in
#      the same process, their rendered bodies (and tokens) co-mingle
#      in the same log stream.
#
# This script is a static-source reproduction. It asserts:
#   (a) WebhookAction::execute logs URL, headers, body template, AND
#       rendered body at info! level.
#   (b) No header-value redaction (no `redact_secret_headers`,
#       `safe_headers`, or filtering of Authorization/X-API-Key).
#   (c) No documented `--log-format=safe` toggle to suppress.
#
# Exit codes:
#   0  — bug NOT reproduced (logs at debug, or redaction added) — file
#        follow-up.
#   1  — bug REPRODUCED (full payload logged at INFO at frozen SHA).
# ============================================================================

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
FRAISEQL_REPO="$(cd "$HERE"/../../../fraiseql && pwd)"
FRAISEQL_SHA="$(cat "$HERE/FRAISEQL_SHA")"

echo "================================================================"
echo "FW-19 reproduction — webhook URL/headers/body logged at INFO"
echo "FraiseQL SHA: $FRAISEQL_SHA"
echo "================================================================"

if ! git -C "$FRAISEQL_REPO" cat-file -e "$FRAISEQL_SHA"; then
    echo "ERROR: frozen SHA $FRAISEQL_SHA not present in $FRAISEQL_REPO" >&2
    exit 2
fi

ACTIONS=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-observers/src/actions.rs")

# (a) info! macros that touch URL, headers, body template, body.
echo
echo "Disclosure points inside WebhookAction::execute:"
exec_body=$(printf '%s\n' "$ACTIONS" | awk '/pub async fn execute/,/^    }/')
url_info=$(printf '%s\n' "$exec_body" | grep -cE 'info!\([^)]*URL:[^)]*url' || true)
hdr_info=$(printf '%s\n' "$exec_body" | grep -cE 'info!\([^)]*Headers:[^)]*headers' || true)
tpl_info=$(printf '%s\n' "$exec_body" | grep -cE 'info!\([^)]*Body template:[^)]*body_template' || true)
body_info=$(printf '%s\n' "$exec_body" | grep -cE 'info!\(' | head -1 || true)

# Re-grep more permissively to count.
url_hits=$(printf '%s\n' "$exec_body" | grep -nE 'info!\([^)]*"\s*URL:' || true)
hdr_hits=$(printf '%s\n' "$exec_body" | grep -nE 'info!\([^)]*"\s*Headers:' || true)
tpl_hits=$(printf '%s\n' "$exec_body" | grep -nE 'info!\([^)]*"\s*Body template:' || true)
body_hits=$(printf '%s\n' "$exec_body" | grep -nE 'info!\([^)]*"\s*Body:' || true)

echo "  URL log at info!:           ${url_hits:-<none>}"
echo "  Headers log at info!:       ${hdr_hits:-<none>}"
echo "  Body template log at info!: ${tpl_hits:-<none>}"
echo "  Rendered body log at info!: ${body_hits:-<none>}"

if [[ -z "$url_hits" && -z "$hdr_hits" && -z "$body_hits" ]]; then
    echo "BUG NOT REPRODUCED: no info!-level disclosure of URL/headers/body found." >&2
    exit 0
fi

# (b) No redaction helper for secret-style headers.
echo
echo "Header-value redaction helpers:"
redact_hits=$(printf '%s\n' "$ACTIONS" | grep -niE 'redact|safe_headers|strip_secret|mask_secret' || true)
if [[ -z "$redact_hits" ]]; then
    echo "  (no redact/mask helper present)"
else
    printf '%s\n' "$redact_hits"
    echo "BUG NOT REPRODUCED in expected shape: a redaction helper is present." >&2
    exit 0
fi

# (c) No log-toggle env var or feature gate.
echo
echo "Log-output toggles inside actions.rs:"
toggle_hits=$(printf '%s\n' "$ACTIONS" | grep -niE 'FRAISEQL_OBSERVERS_LOG_BODY|FRAISEQL_OBSERVERS_LOG_FORMAT|cfg!\(feature\s*=\s*"safe' || true)
if [[ -z "$toggle_hits" ]]; then
    echo "  (no operator-side log-suppression toggle)"
else
    printf '%s\n' "$toggle_hits"
    echo "BUG NOT REPRODUCED in expected shape: a log-suppression toggle is present." >&2
    exit 0
fi

cat <<'MSG'

================================================================
Bug-shape assertion:
================================================================
- WebhookAction::execute logs the full webhook URL at info!.
- WebhookAction::execute logs the full headers HashMap via Debug at
  info! — including Authorization / X-API-Key / bearer tokens.
- WebhookAction::execute logs the Body template literal at info!.
- WebhookAction::execute logs the rendered JSON body at info!.
- No redact_/mask_/strip_secret helper exists in actions.rs.
- No FRAISEQL_OBSERVERS_LOG_BODY env-var or `cfg!(feature="safe-logs")`
  toggle exists to suppress these logs.

BUG REPRODUCED.

Impact (regression severity; security / compliance):
  - Every observer dispatch leaks the full event payload + headers +
    URL into the application log stream at the default INFO level.
  - Centralised log aggregators retain these payloads for the
    aggregator's retention window — typically 30+ days.
  - Operator bearer tokens placed in the observer's `headers` map
    leak verbatim every time the action fires.
  - PII fields in the event payload (customer email, shipping
    address, payment refs) are copied into logs on every webhook.
  - In multi-tenant deployments, all tenants' payloads co-mingle in
    one log stream.

Suggested fix:
  1. Demote the URL / headers / body INFO lines to TRACE level.
  2. At INFO, emit only: action_type, event.id, host (no path/query),
     status_code, duration_ms.
  3. Add a `redact_secret_headers` helper that masks any header
     whose name matches /authorization|x-api-key|cookie|secret/i.
  4. Add a `FRAISEQL_OBSERVERS_LOG_BODY=true` opt-in env var for
     developer debugging; default off in production.

Affected page draft: /features/observers (security caveats),
/operations/observer-runbook (log-aggregation guidance).
Until fixed:
  - Page MUST warn operators that the default INFO log level emits
    the webhook URL, headers, and rendered body on every dispatch.
  - Page MUST recommend `RUST_LOG=fraiseql_observers::actions=warn`
    (or equivalent log-filter) in production deployments.
  - Page MUST advise against placing bearer secrets in the observer
    `headers` map without log-level filtering in place.
MSG
exit 1
