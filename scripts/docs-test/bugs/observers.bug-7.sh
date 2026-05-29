#!/usr/bin/env bash
#
# observers.bug-7.sh — reproduction for FW-22 (`ActionConfig::Email`
# observers report "success" without sending any email — the
# `EmailAction::execute` body is a stub that returns Ok(...) immediately
# with a freshly-generated UUID, never opening an SMTP connection).
#
# Filed: https://github.com/fraiseql/fraiseql/issues/<TBD>
# Registered: _internal/.plan/framework-qa-triage.md (FW-22)
#
# Persona: Bug-Finder (Opus 4.7), Phase 03 / Cycle 3 RED.
# Frozen FraiseQL SHA: d0a4ed4ec1770c70707f68fd9019f2b561d87461 (v2.3.2).
#
# ============================================================================
# Expected (per the v2.3 CHANGELOG observer-actions block and the
# ActionConfig::Email variant at crates/fraiseql-observers/src/config/
# runtime.rs:L290-L308, which carries `to`, `to_template`, `subject`,
# `subject_template`, `body_template`, `reply_to` fields — a shape
# that promises full email composition):
#
#   An observer with `actions = [{type = "email", to = "...",
#   subject = "...", body_template = "..."}]` should send an email
#   on each matching event, via SMTP or a transactional-email
#   provider integration.
#
# Actual (at frozen SHA, crates/fraiseql-observers/src/actions.rs:
# L484-L505 — the entire EmailAction impl):
#
#       pub struct EmailAction {
#           // Placeholder for SMTP client
#       }
#       impl EmailAction {
#           pub const fn new() -> Self { Self {} }
#           #[allow(clippy::unused_async)] // ...
#           pub async fn execute(
#               &self,
#               _to: &str,
#               _subject: &str,
#               _body_template: Option<&str>,
#               _event: &EntityEvent,
#           ) -> Result<EmailResponse> {
#               // Stub implementation
#               Ok(EmailResponse {
#                   success:     true,
#                   message_id:  Some(uuid::Uuid::new_v4().to_string()),
#                   duration_ms: 10.0,
#               })
#           }
#       }
#
#   Every input parameter is prefixed with `_` (unused). The function
#   returns success with a UUID message_id without any SMTP-side work.
#   The summary path bumps `successful_actions` and the metrics
#   registry's `action_executed` counter; the observer log row is
#   written with `status = 'success'`. From the operator's
#   perspective, the email "succeeded" — they only discover the
#   bug when their customers report missing notifications.
#
# Consequence (regression severity; correctness):
#
#   1. Any observer with an Email action is a silent no-op. Welcome
#      emails, password-reset confirmations, billing receipts —
#      all green-checkmarked as "delivered" while never actually
#      hitting an SMTP server.
#   2. The metrics counters report 100 % delivery success — observability
#      cannot detect this.
#   3. The DLQ never receives Email items (since execute returns Ok).
#
# This script is a static-source reproduction. It asserts:
#   (a) EmailAction::execute is a stub that ignores every argument
#       and returns Ok.
#   (b) The struct contains no SMTP client field, only a placeholder
#       comment.
#   (c) No `lettre`, `email_address`, `mail`, or transactional-email
#       crate dependency in the observer crate.
#
# Exit codes:
#   0  — bug NOT reproduced (real SMTP integration added) — file
#        follow-up.
#   1  — bug REPRODUCED (stub at frozen SHA).
# ============================================================================

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
FRAISEQL_REPO="$(cd "$HERE"/../../../fraiseql && pwd)"
FRAISEQL_SHA="$(cat "$HERE/FRAISEQL_SHA")"

echo "================================================================"
echo "FW-22 reproduction — EmailAction is a silent stub"
echo "FraiseQL SHA: $FRAISEQL_SHA"
echo "================================================================"

if ! git -C "$FRAISEQL_REPO" cat-file -e "$FRAISEQL_SHA"; then
    echo "ERROR: frozen SHA $FRAISEQL_SHA not present in $FRAISEQL_REPO" >&2
    exit 2
fi

ACTIONS=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-observers/src/actions.rs")

# (a) EmailAction::execute is a stub: parameters all underscore-prefixed,
#     no SMTP send, returns Ok with a UUID.
echo
echo "EmailAction impl block:"
email_block=$(printf '%s\n' "$ACTIONS" | awk '/pub struct EmailAction/,/impl Default for EmailAction/')
printf '%s\n' "$email_block"

# Check that every input is prefixed with _ (unused).
unused_count=$(printf '%s\n' "$email_block" | grep -cE '_(to|subject|body_template|event):' || true)
if [[ "$unused_count" -lt 3 ]]; then
    echo "BUG NOT REPRODUCED: EmailAction::execute now uses at least one of its arguments." >&2
    exit 0
fi

# Check that the body contains 'Stub implementation' or returns a hardcoded Ok.
if ! printf '%s\n' "$email_block" | grep -qE 'Stub implementation|Placeholder for SMTP'; then
    echo "BUG NOT REPRODUCED in expected shape: stub comment no longer present." >&2
    exit 0
fi

# (b) No SMTP send call — `lettre`, mailer.send, etc.
#
# Note: actions.rs contains the literal string "Placeholder for SMTP client"
# and the module doc-comment "Send emails via SMTP" — those are
# documentation of the placeholder, NOT actual integration. The signal we
# care about is a function call (`.send()`, `Transport::send(...)`,
# `Client::send_email`), or a `use` import of an actual mailer crate.
echo
echo "Actual SMTP / transactional-email send-call sites in EmailAction:"
send_hits=$(printf '%s\n' "$ACTIONS" | grep -niE 'use lettre|Mailer::|SmtpTransport|Transport::send|Client::send_email|lettre::Message' || true)
if [[ -z "$send_hits" ]]; then
    echo "  (no SMTP / email-provider integration code in actions.rs — only doc-comment placeholders)"
else
    printf '%s\n' "$send_hits"
    echo "BUG NOT REPRODUCED: SMTP / email-provider integration found." >&2
    exit 0
fi

# (c) No email crate dependency.
echo
echo "fraiseql-observers Cargo.toml deps on email crates:"
CARGO=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-observers/Cargo.toml")
email_dep=$(printf '%s\n' "$CARGO" | grep -iE '^(lettre|email_address|mail|sendgrid|mailgun|aws-sdk-sesv2)\s*=' || true)
if [[ -z "$email_dep" ]]; then
    echo "  (no lettre / email_address / mail / sendgrid / mailgun / aws-sdk-sesv2 dependency)"
else
    printf '%s\n' "$email_dep"
    echo "BUG NOT REPRODUCED: email crate dependency present." >&2
    exit 0
fi

cat <<'MSG'

================================================================
Bug-shape assertion:
================================================================
- EmailAction::execute prefixes every argument with `_` (unused),
  contains the comment "Stub implementation", and returns Ok with
  a freshly-generated UUID and duration_ms = 10.0.
- actions.rs has no `lettre::*` / `smtp::*` / `EmailClient::*` use.
- The crate's Cargo.toml does not depend on any email-sending crate.

BUG REPRODUCED.

Impact (regression severity; correctness):
  - Every observer with `actions = [{type = "email", ...}]` is a
    silent no-op.
  - The action records `success = true`, increments the
    `action_executed` Prometheus counter, and writes
    `tb_observer_log.status = 'success'` — observability cannot
    detect the bug.
  - User-facing flows that depend on email (welcome, password
    reset, billing) silently fail; customers report the issue
    days or weeks later.

Suggested fix:
  1. Integrate `lettre` (or AWS SES SDK) and wire SMTP credentials
     through `ObserverRuntimeConfig` (env-var-backed).
  2. Until then, mark EmailAction as #[deprecated] with a message
     directing operators to use the webhook action against their
     existing transactional-email provider's HTTP API.
  3. Or: make EmailAction::execute return
     `Err(ActionPermanentlyFailed { reason: "EmailAction is not
     implemented yet; use webhook instead" })` so the failure is
     visible.

Affected page draft: /features/observers (action-type catalogue),
/building/observers (worked examples).
Until fixed:
  - Page MUST NOT include any Email-action examples that suggest
    delivery actually happens.
  - Page MUST cross-link FW-22 from the Email action row and direct
    readers to the Webhook action pointing at their transactional
    email provider's API.
MSG
exit 1
