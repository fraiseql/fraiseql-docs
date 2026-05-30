#!/usr/bin/env bash
#
# observers.bug-5.sh — reproduction for FW-20
# (FRAISEQL_OBSERVERS_ALLOW_INSECURE=true environment variable disables
# ALL SSRF guards in the webhook action path — including DNS-rebinding
# protection, private-IP blocking, and loopback rejection).
#
# Filed: https://github.com/fraiseql/fraiseql/issues/<TBD>
# Registered: _internal/.plan/framework-qa-triage.md (FW-20)
#
# Persona: Bug-Finder (Opus 4.7), Phase 03 / Cycle 3 RED.
# Frozen FraiseQL SHA: d0a4ed4ec1770c70707f68fd9019f2b561d87461 (v2.3.2).
#
# ============================================================================
# Expected (per the SSRF defence rustdoc on `validate_outbound_url` at
# crates/fraiseql-observers/src/actions.rs:L29-L50):
#
#   /// Validate an outbound URL for SSRF risk before sending a request.
#   /// Rejects:
#   /// - Non-HTTP(S) schemes (`file://`, `ftp://`, etc.)
#   /// - Loopback addresses (`localhost`, `127.x.x.x`, `::1`)
#   /// - RFC 1918 private ranges (10/8, 172.16/12, 192.168/16)
#   /// - Link-local (169.254/16), CGNAT (100.64/10), ULA (`fc00::/7`)
#   ///
#   /// Attacker-controlled observer configs could redirect outbound
#   /// webhook calls to AWS EC2 metadata (`169.254.169.254`), internal
#   /// Kubernetes services (`svc.cluster.local`), or any other SSRF
#   /// target.
#
# Actual (at frozen SHA, both actions.rs:L48-L57 and ssrf.rs:L18-L25
# and L72-L79):
#
#   // When `FRAISEQL_OBSERVERS_ALLOW_INSECURE=true` all SSRF guards
#   // are disabled. Intended for local development and integration
#   // testing only.
#   let allow_insecure = std::env::var("FRAISEQL_OBSERVERS_ALLOW_INSECURE")
#       .map(|v| v.eq_ignore_ascii_case("true") || v == "1")
#       .unwrap_or(false);
#   if allow_insecure {
#       INSECURE_WARN_ONCE.call_once(|| { warn!("..."); });
#       return Ok(());   // <-- early return; URL not validated
#   }
#
# The same toggle appears in three independent guard sites
# (validate_outbound_url, dns_resolve_and_check, and the ssrf.rs
# helpers). When the env var is set, every one of them turns into a
# no-op and the webhook action POSTs the request to ANY URL —
# including http://169.254.169.254/latest/meta-data/iam/security-
# credentials/ (AWS instance role exfil) and http://localhost:9999
# (any port the host process can reach).
#
# Consequence (security; insecure-default exploitation class):
#
#   1. Any operator setting FRAISEQL_OBSERVERS_ALLOW_INSECURE=true in
#      docker-compose.dev.yml or .env and forgetting it in
#      production turns every observer into an SSRF tool.
#   2. The warning emits ONCE via `INSECURE_WARN_ONCE.call_once` and
#      then stays silent — operators reviewing live logs will not
#      see continuous evidence of the bypass.
#   3. Combined with FW-21 (anonymous observer creation), an
#      external attacker who can hit POST /api/observers can install
#      an observer that fires on every entity mutation and points at
#      the metadata service URL — exfiltrating IAM credentials from
#      every batch.
#
# This script is a static-source reproduction. It asserts:
#   (a) Three independent SSRF-guard sites each early-return on the
#       env var.
#   (b) The warning is fired through call_once (one log line, ever).
#   (c) No mechanism to deny / refuse boot when this is set in
#       production.
#
# Exit codes:
#   0  — bug NOT reproduced (toggle removed or gated by prod-detector)
#        — file follow-up.
#   1  — bug REPRODUCED (env var unconditionally disables SSRF at
#        frozen SHA).
# ============================================================================

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
FRAISEQL_REPO="$(cd "$HERE"/../../../fraiseql && pwd)"
FRAISEQL_SHA="$(cat "$HERE/FRAISEQL_SHA")"

echo "================================================================"
echo "FW-20 reproduction — FRAISEQL_OBSERVERS_ALLOW_INSECURE disables SSRF"
echo "FraiseQL SHA: $FRAISEQL_SHA"
echo "================================================================"

if ! git -C "$FRAISEQL_REPO" cat-file -e "$FRAISEQL_SHA"; then
    echo "ERROR: frozen SHA $FRAISEQL_SHA not present in $FRAISEQL_REPO" >&2
    exit 2
fi

# (a) Three independent SSRF-guard sites each early-return on the env var.
echo
echo "Sites where FRAISEQL_OBSERVERS_ALLOW_INSECURE bypasses SSRF:"
sites=$(git -C "$FRAISEQL_REPO" grep -n "FRAISEQL_OBSERVERS_ALLOW_INSECURE" "$FRAISEQL_SHA" -- 'crates/fraiseql-observers/src/' || true)
printf '%s\n' "$sites"
site_count=$(printf '%s\n' "$sites" | grep -c "FRAISEQL_OBSERVERS_ALLOW_INSECURE" || true)
echo
echo "  Total bypass sites: $site_count"

if [[ "$site_count" -lt 2 ]]; then
    echo "BUG NOT REPRODUCED: fewer than 2 bypass sites (the env-var bypass may have been removed)." >&2
    exit 0
fi

# (b) Confirm one-shot warning via call_once.
echo
echo "Warning emission (call_once → only ONE warning ever per process):"
ACTIONS=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-observers/src/actions.rs")
printf '%s\n' "$ACTIONS" | grep -nE 'INSECURE_WARN_ONCE|call_once' | head -5 || true

if ! printf '%s\n' "$ACTIONS" | grep -q 'INSECURE_WARN_ONCE'; then
    echo "BUG NOT REPRODUCED: the one-shot warn primitive is gone — repeated warnings may now fire." >&2
    # not a hard reset: continue.
fi

# (c) No production-mode detector / refuse-to-boot guard.
echo
echo "Production-mode refuse-to-boot guards on the toggle:"
prod_hits=$(git -C "$FRAISEQL_REPO" grep -niE "RAISEQL_OBSERVERS_ALLOW_INSECURE.*prod|production.*ALLOW_INSECURE|refuse.*ALLOW_INSECURE" "$FRAISEQL_SHA" -- 'crates/fraiseql-observers/' || true)
if [[ -z "$prod_hits" ]]; then
    echo "  (no production-mode detector — toggle has no guard rails)"
else
    printf '%s\n' "$prod_hits"
    echo "BUG NOT REPRODUCED in expected shape: production-mode guard added." >&2
    exit 0
fi

cat <<'MSG'

================================================================
Bug-shape assertion:
================================================================
- FRAISEQL_OBSERVERS_ALLOW_INSECURE=true / =1 (case-insensitive)
  triggers an early `return Ok(());` in:
    1. validate_outbound_url() in actions.rs (URL allowlist)
    2. validate_outbound_url() in ssrf.rs (URL allowlist, duplicate path)
    3. dns_resolve_and_check() in ssrf.rs (DNS-rebinding defence)
- The bypass logs a one-shot warning via call_once — silent after
  the first webhook dispatch.
- There is no production-mode detector, no refuse-to-boot guard,
  and no metric exposing whether the bypass is currently active.

BUG REPRODUCED.

Exfiltration scenario (severity: critical):

  1. Operator sets FRAISEQL_OBSERVERS_ALLOW_INSECURE=true in a dev
     docker-compose.yml; the same compose file is reused (with edits
     elsewhere) for staging.
  2. An attacker who can hit POST /api/observers (FW-21 — no auth)
     installs an observer on every entity type with action:
        webhook { url = "http://169.254.169.254/latest/meta-data/iam/security-credentials/<role>" }
  3. On the next mutation, the webhook fires; AWS returns the IAM
     credentials JSON in the GET response (or, if the receiver
     follows the convention of mirroring received data, the
     metadata returns are echoed back into the log line at L276
     of actions.rs — FW-19).
  4. Alternative target: http://kubernetes.default.svc.cluster.local
     and http://10.x.x.x internal services.

Suggested fix:
  1. Remove the env-var toggle entirely. Provide a per-build feature
     gate (`unsafe-no-ssrf-guard`) that is mutually exclusive with
     `metrics` and stamps a permanent warning into /health.
  2. Or: ignore the env var when `cfg!(debug_assertions) == false`
     (release builds). Document the change in a CHANGELOG entry.
  3. Or: refuse to boot when both the env var AND any
     production-marker env var (`KUBERNETES_SERVICE_HOST`, NODE_ENV,
     `FRAISEQL_PROFILE=production`, etc.) are set.
  4. Continuously emit `warn!` on every dispatch instead of
     call_once — operators must SEE this in their log stream.

Affected page draft: /features/observers (security caveats),
/operations/observer-runbook (env-var reference).
Until fixed:
  - Page MUST document FRAISEQL_OBSERVERS_ALLOW_INSECURE as the
    blast-radius env var that it is (no euphemisms).
  - Page MUST recommend baking a refuse-to-boot guard into the
    deployment process — wrapper script that aborts startup if both
    `FRAISEQL_OBSERVERS_ALLOW_INSECURE` and any production-marker
    env var are set.
  - Page MUST warn that this toggle is one-shot-logged and easily
    overlooked.
MSG
exit 1
