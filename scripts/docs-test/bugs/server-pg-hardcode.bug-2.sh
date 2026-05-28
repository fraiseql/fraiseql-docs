#!/usr/bin/env bash
#
# server-pg-hardcode.bug-2.sh — reproduction for FW-2.
#
# Filed: https://github.com/fraiseql/fraiseql/issues/327
# Registered: _internal/.plan/framework-qa-triage.md (FW-2)
#
# Summary:
#   The fraiseql-server binary at the frozen SHA hardcodes PostgresAdapter
#   (crates/fraiseql-server/src/main.rs:L240-L260). Even if we point its
#   database_url at a non-PG service, it ignores the scheme and attempts a
#   PG connection. The quickstart page's multi-DB tabs are therefore
#   unreachable through the server binary.
#
# What this script proves:
#   1. Boot the harness with only the MySQL backend (no postgres profile).
#   2. Override the fraiseql baseline.toml's database_url to a mysql://… URL.
#   3. The server fails to start OR logs a PG-specific error — proving the
#      adapter selection is hardcoded, not scheme-derived.
#
# Run:
#   scripts/docs-test/bugs/server-pg-hardcode.bug-2.sh
#
# Exit codes:
#   0  — bug reproduced (server logs PG-specific behaviour against a mysql URL)
#   1  — bug NOT reproduced (server somehow worked) — file a follow-up
#
# This script is read-only on the framework checkout; it only edits a tmp
# overlay file on the docs-test side.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
OPERATOR_CLI="$HERE/docs-test.sh"
COMPOSE_FILE="$HERE/docker-compose.docs-test.yml"

TMP_TOML="$(mktemp -t fraiseql-bug2-baseline.XXXXXX.toml)"
TMP_OVERRIDE="$(mktemp -t fraiseql-bug2-override.XXXXXX.yml)"

# shellcheck disable=SC2329 # invoked indirectly via `trap`
cleanup() {
    rm -f "$TMP_TOML" "$TMP_OVERRIDE"
    "$OPERATOR_CLI" down --volumes >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Author a baseline.toml that points fraiseql at the MySQL service (not PG).
cat >"$TMP_TOML" <<'EOF'
bind_addr   = "0.0.0.0:8080"
database_url = "mysql://fraiseql:fraiseql_docs_test@mysql:3306/fraiseql"
schema_path = "/etc/fraiseql/schema.compiled.json"
cors_enabled = true
cors_origins = ["http://localhost:8080"]
health_path = "/health"
playground_enabled = false
metrics_enabled = false
admin_api_enabled = false
introspection_enabled = false
pool_min_size = 5
pool_max_size = 20
pool_timeout_secs = 30
EOF

cat >"$TMP_OVERRIDE" <<EOF
services:
  fraiseql:
    depends_on:
      mysql:
        condition: service_healthy
    profiles: ["bug2"]
    volumes:
      - $TMP_TOML:/etc/fraiseql/fraiseql.toml:ro
EOF

"$OPERATOR_CLI" down --volumes >/dev/null 2>&1 || true

# Boot mysql first.
docker compose -f "$COMPOSE_FILE" --profile mysql up -d --wait --wait-timeout 120 >/dev/null

# Boot fraiseql with the mysql:// URL override.
docker compose -f "$COMPOSE_FILE" -f "$TMP_OVERRIDE" \
    --profile bug2 up -d --wait --wait-timeout 60 >/dev/null 2>&1 || true

sleep 3

# Capture the server's startup logs. Look for PG-specific evidence.
LOGS=$(docker compose -f "$COMPOSE_FILE" -f "$TMP_OVERRIDE" logs fraiseql 2>&1)

echo "================================================================"
echo "FW-2 reproduction — server logs (first 30 lines + PG evidence):"
echo "================================================================"
printf '%s\n' "$LOGS" | head -30
echo
echo "================================================================"
echo "Grepping logs for PG-specific evidence:"
echo "================================================================"
if printf '%s\n' "$LOGS" | grep -E "PostgreSQL|PgPool|postgres adapter|database_type.*PostgreSQL" >/dev/null; then
    echo "BUG REPRODUCED — server logged PG-specific behaviour while pointed at a mysql:// URL."
    printf '%s\n' "$LOGS" | grep -E "PostgreSQL|PgPool|postgres" | head -10
    exit 0
fi

# Alternative: server crashed because tokio-postgres can't parse mysql://.
if printf '%s\n' "$LOGS" | grep -iE "tokio.?postgres|invalid url|missing.*host" >/dev/null; then
    echo "BUG REPRODUCED — server attempted PG-specific URL parsing on mysql://."
    printf '%s\n' "$LOGS" | grep -iE "tokio.?postgres|invalid url|missing.*host" | head -10
    exit 0
fi

echo "BUG NOT REPRODUCED — server logs do not match expected PG-hardcode pattern."
echo "Either the bug was fixed, or this script needs updating."
exit 1
