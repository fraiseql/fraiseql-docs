#!/usr/bin/env bash
#
# _smoke.docs-test.sh — Phase 00 Cycle 5 smoke reproduction.
#
# Reproduces the happy path of `src/content/docs/getting-started/quickstart.mdx`
# end-to-end against the docs-test harness, then proves the same per-DB SQL
# fixtures (Postgres, MySQL, SQLite, MSSQL) compile and return the documented
# JSON shape against each real database.
#
# Why `quickstart.mdx` and not `five-minute-quickstart.mdx`:
#   - The 5-minute quickstart depends on `fraiseql/fraiseql-starter-minimal`,
#     a separate (and currently published) repo that combines a pre-baked
#     fraiseql image + schema + migrations + compose file. It is the entry
#     point the live site advertises, but it is NOT reproducible from this
#     repo (the starter repo is not vendored here).
#   - `quickstart.mdx` (Manual Setup) is the canonical runnable, copy-pasteable
#     sequence: install schema → compile → boot server → run one query → assert
#     shape. It also has the per-DB tab structure (PG, MySQL, SQLite, SQL
#     Server), matching the cycle spec's "all four DB targets" requirement.
#
# Page-vs-framework gap (documented in handoff):
#   - The quickstart page's per-DB tabs imply runtime multi-DB support
#     (`database_target = "postgresql" | "mysql" | "sqlite" | "sqlserver"`).
#   - At the frozen FraiseQL SHA, the `fraiseql-server` binary is hardcoded
#     to `PostgresAdapter` (`crates/fraiseql-server/src/main.rs:L240-L260`).
#     The non-PG adapters (`MySqlAdapter`, `SqliteAdapter`, MSSQL via tiberius)
#     exist in `fraiseql-db` but the server binary does not dispatch on
#     `database_target`. Even `fraiseql run` uses `PostgresAdapter`
#     (`crates/fraiseql-cli/src/commands/run.rs:L27`).
#   - Consequence: the smoke drives PostgreSQL all the way through the
#     FraiseQL HTTP API. For MySQL, SQLite, and MSSQL it proves the page's
#     per-DB view SQL is correct against the real DB engine but cannot route
#     the GraphQL query through the FraiseQL server. The gap is the *server
#     binary*, not the page — the page is forward-looking but the runtime is
#     not there yet.
#
# Exit codes:
#   0  — all configured DBs PASS.
#   1  — any DB failed; stderr names which step in which DB.
#   2  — usage / preflight error (e.g. host docker not available).
#
# Time budget: <4 minutes on a developer laptop (Cycle 5 CLEANUP gate).
#   Cold first run requires the Cycle 2 image to already be built (handled
#   by Cycle 2's GREEN evidence). The smoke does NOT rebuild the image.
#
# source: src/content/docs/getting-started/quickstart.mdx:L1-L487 (full page)
# source: _internal/.plan/.phases/phase-00-foundation.md:L102-L108 (Cycle 5 spec)
# source: _internal/.plan/methodology.md § 6 (container harness conventions)

set -euo pipefail

# ---------------------------------------------------------------------------
# Self-locate. Always invoke docker compose from the docs-test root so
# relative build contexts resolve.
# ---------------------------------------------------------------------------
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
DOCS_TEST="$HERE"
OPERATOR_CLI="$DOCS_TEST/docs-test.sh"
COMPOSE_FILE="$DOCS_TEST/docker-compose.docs-test.yml"

# shellcheck source=../lib/assert.sh disable=SC1091
. "$DOCS_TEST/lib/assert.sh"

# Per-DB fixture file paths (verbatim per-DB SQL from quickstart.mdx).
FIXTURE_POSTGRES="$DOCS_TEST/fixtures/postgres/_smoke.sql"
FIXTURE_MYSQL="$DOCS_TEST/fixtures/mysql/_smoke.sql"
FIXTURE_SQLITE="$DOCS_TEST/fixtures/sqlite/_smoke.sql"
FIXTURE_MSSQL="$DOCS_TEST/fixtures/mssql/_smoke.sql"

# PostgreSQL-only: a pre-compiled schema we bind-mount into the fraiseql
# container so the server boots with a real (User, Post, users, posts) schema
# instead of the baked-in empty one. The page documents `fraiseql compile` as
# the producer of this artefact; since the docs-test image does NOT ship the
# `fraiseql` CLI binary (only `fraiseql-server`), we hand-author the compiled
# JSON matching the page's Python `@fraiseql.type` blocks.
SMOKE_COMPILED_SCHEMA="$DOCS_TEST/fixtures/postgres/_smoke.compiled.json"

# Compose override that bind-mounts the smoke-compiled schema over the image's
# baked /etc/fraiseql/schema.compiled.json. Generated into a tmp file because
# Compose v2 needs the override on disk.
SMOKE_OVERRIDE=""

# Default host port (overridable via .env; we read whatever docs-test.sh
# uses). The Compose default is 8080.
HOST_PORT_FRAISEQL="${HOST_PORT_FRAISEQL:-8080}"

# Time budget instrumentation.
T_TOTAL_START=0
declare -A T_PER_DB

# Argument-driven DB selection (default: all four).
DBS=()

# ---------------------------------------------------------------------------
# Logging.
# ---------------------------------------------------------------------------
banner() {
    printf '\n=== smoke: %s ===\n' "$1"
}

step() {
    # `assert_*` helpers already prefix `  ✓` / `  ✗`. Use `step` for
    # progress lines that aren't assertions (timings, info).
    printf '  · %s\n' "$*"
}

err() {
    printf '_smoke: %s\n' "$*" >&2
}

die() {
    err "$*"
    exit 2
}

now_ms() {
    # GNU date supports %N (nanoseconds). Macs need coreutils gdate; we
    # assume Linux for the docs-test host (Cycle 1 declared the host arch).
    date +%s%3N
}

# ---------------------------------------------------------------------------
# Preflight — make sure docker, jq, the operator CLI, and the Cycle 2 image
# are all in place. Fail loudly if not.
# ---------------------------------------------------------------------------
preflight() {
    command -v docker >/dev/null || die "docker not on PATH"
    command -v jq     >/dev/null || die "jq not on PATH (assert_json_shape requires it)"
    [ -x "$OPERATOR_CLI" ]       || die "operator CLI missing or not executable: $OPERATOR_CLI"
    [ -r "$COMPOSE_FILE" ]       || die "compose file missing: $COMPOSE_FILE"

    # The image must already be built (Cycle 2 GREEN evidence proves this on
    # this host). Smoke does not build it — that's a one-time operator step.
    if ! docker image inspect fraiseql-docs-test-fraiseql:latest >/dev/null 2>&1; then
        die "image fraiseql-docs-test-fraiseql:latest not present; run \`docker compose -f $COMPOSE_FILE build fraiseql\` once before the smoke"
    fi

    # Per-DB fixtures must all be present even if we skip a DB later.
    for f in "$FIXTURE_POSTGRES" "$FIXTURE_MYSQL" "$FIXTURE_SQLITE" "$FIXTURE_MSSQL" "$SMOKE_COMPILED_SCHEMA"; do
        [ -r "$f" ] || die "fixture missing or unreadable: $f"
    done
}

# ---------------------------------------------------------------------------
# Compose override generation — bind-mounts the smoke compiled schema into
# the fraiseql service. Written to a tmp file so this stays read-only-clean.
# ---------------------------------------------------------------------------
write_smoke_override() {
    SMOKE_OVERRIDE="$(mktemp -t fraiseql-docs-smoke-override.XXXXXX.yml)"
    cat >"$SMOKE_OVERRIDE" <<EOF
# Generated by scripts/docs-test/pages/_smoke.docs-test.sh — do not commit.
# Bind-mounts the smoke's pre-compiled User/Post schema over the image's
# baked empty schema so the fraiseql server boots with a queryable surface.
services:
  fraiseql:
    volumes:
      - $SMOKE_COMPILED_SCHEMA:/etc/fraiseql/schema.compiled.json:ro
EOF
}

# ---------------------------------------------------------------------------
# Teardown — called on EXIT (including SIGINT). Tears down all profiles,
# wipes volumes, removes the tmp override.
# ---------------------------------------------------------------------------
cleanup() {
    set +e
    if [ -n "${SMOKE_OVERRIDE:-}" ] && [ -f "$SMOKE_OVERRIDE" ]; then
        rm -f "$SMOKE_OVERRIDE"
    fi
    # Best-effort teardown so a Ctrl-C mid-smoke doesn't leave orphan stacks.
    "$OPERATOR_CLI" down --volumes >/dev/null 2>&1 || true
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# tear_down — between-iteration cleanup. Wipes volumes so each DB starts
# from a known-empty state (Cycle 5 spec: "per-DB fixture isolation").
# ---------------------------------------------------------------------------
tear_down() {
    "$OPERATOR_CLI" down --volumes >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# DB iteration #1 — PostgreSQL (full end-to-end through fraiseql-server).
#
# Sequence (matches quickstart.mdx Steps 2 / 5 / 6):
#   1. Tear down previous state.
#   2. Boot `--profile fraiseql` (includes postgres + redis per compose).
#   3. Bind-mount the smoke compiled schema over the image's baked one
#      (this is the harness equivalent of `fraiseql compile`, per the
#      page-vs-image gap note in this file's header).
#   4. Apply fixtures/postgres/_smoke.sql via `docs-test.sh exec postgres`.
#   5. Restart fraiseql so it reloads the bind-mounted schema and connects to
#      the now-seeded DB.
#   6. Query GraphQL: `{ posts { id title author { name } } }`.
#   7. Assert documented shape (matches quickstart.mdx Steps 5 + 6 outputs).
#
# source: src/content/docs/getting-started/quickstart.mdx:L66-L102 (Step 2 PG views)
# source: src/content/docs/getting-started/quickstart.mdx:L348-L393 (Step 5/6 query + response shape)
# ---------------------------------------------------------------------------
smoke_postgres() {
    banner "postgres"
    local t0; t0=$(now_ms)

    tear_down

    # Use the smoke override so the fraiseql container picks up the real
    # User/Post compiled schema instead of the empty baked one.
    local up_t0; up_t0=$(now_ms)
    docker compose -f "$COMPOSE_FILE" -f "$SMOKE_OVERRIDE" \
        --profile fraiseql up -d --wait --wait-timeout 240 >/dev/null
    assert_eq "stack up exit code" "$?" "0"
    step "stack up ($(( ($(now_ms) - up_t0) / 1000 ))s)"

    # Apply the per-DB fixture (tables + views + seed). Use `docs-test.sh exec`
    # so the smoke goes through Cycle 4's operator surface, not raw docker.
    "$OPERATOR_CLI" exec postgres -- \
        psql -U fraiseql -d fraiseql -v ON_ERROR_STOP=1 -f - \
        < "$FIXTURE_POSTGRES" >/dev/null
    assert_eq "schema installed (postgres)" "$?" "0"

    # The fraiseql server caches the schema at startup. The compiled schema
    # is bind-mounted from the host, so a restart is the cleanest way to
    # ensure it observes the seeded views. Container restart is fast (~3s)
    # because the binary's startup is dominated by the PG pool prewarm.
    docker compose -f "$COMPOSE_FILE" -f "$SMOKE_OVERRIDE" \
        restart fraiseql >/dev/null
    # Wait for /health to flip back to 200 (Compose's restart doesn't wait).
    local attempt
    for attempt in $(seq 1 30); do
        if curl -fsS "http://127.0.0.1:$HOST_PORT_FRAISEQL/health" >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done
    : "$attempt"  # silence shellcheck (counter used implicitly to bound loop)
    local health_body health_code
    health_code=$(curl -sS -o /tmp/_smoke-pg-health.json -w '%{http_code}' \
        "http://127.0.0.1:$HOST_PORT_FRAISEQL/health" || true)
    health_body=$(cat /tmp/_smoke-pg-health.json 2>/dev/null || echo '')
    assert_http_2xx "/health" "$health_code" || return 1
    assert_json_shape "$health_body" '.status == "healthy"' "health.status == healthy"
    assert_json_shape "$health_body" '.database.connected == true' "health.database.connected"
    assert_json_shape "$health_body" '.database.database_type == "PostgreSQL"' "health.database.database_type"

    # Documented query — quickstart.mdx Step 5 / Step 6 shape.
    # source: src/content/docs/getting-started/quickstart.mdx:L57-L65 (5-min query example, same shape)
    # source: src/content/docs/getting-started/quickstart.mdx:L399-L419 (quickstart Step 6 response shape)
    local body
    body=$(curl --fail-with-body -sS \
        -X POST "http://127.0.0.1:$HOST_PORT_FRAISEQL/graphql" \
        -H 'Content-Type: application/json' \
        -d '{"query":"{ posts { id title content author { id name email } } }"}')
    assert_eq "graphql query exit code" "$?" "0" || return 1

    # Shape assertions — the page says `{ "data": { "posts": [ … ] } }` with
    # each post carrying id/title/content/author. The fixture seeds exactly
    # one post by one user.
    assert_json_shape "$body" '.errors == null'                       "no graphql errors"
    assert_json_shape "$body" '.data.posts | type == "array"'         "data.posts is array"
    assert_json_shape "$body" '.data.posts | length == 1'             "data.posts has 1 element"
    assert_json_shape "$body" '.data.posts[0].title == "Hello FraiseQL"'           "post[0].title"
    assert_json_shape "$body" '.data.posts[0].author.name == "Alice Smith"'        "post[0].author.name"
    assert_json_shape "$body" '.data.posts[0].author.email == "alice@example.com"' "post[0].author.email"

    tear_down
    step "stack down clean"

    T_PER_DB[postgres]=$(( $(now_ms) - t0 ))
    return 0
}

# ---------------------------------------------------------------------------
# DB iteration #2 — MySQL (page-side SQL only; no FraiseQL routing).
#
# Why this iteration is structured differently from PG: the fraiseql-server
# binary at the frozen SHA does not dispatch to MySQL (see file header).
# This iteration proves the *page's* per-DB SQL is correct by:
#   1. Tearing down + booting only the mysql profile.
#   2. Applying fixtures/mysql/_smoke.sql.
#   3. Running the documented JSON_OBJECT view query directly via mysql.
#   4. Asserting the view returns the expected JSON shape (the same shape
#      FraiseQL would marshal if the adapter were wired into the server).
#
# This is a *page-correctness* assertion, not a FraiseQL routing assertion.
# The handoff entry records the gap (page advertises multi-DB; server is
# PG-only at this SHA).
#
# source: src/content/docs/getting-started/quickstart.mdx:L104-L131 (MySQL views)
# source: crates/fraiseql-server/src/main.rs:L240-L260 (PostgresAdapter hardcode)
# ---------------------------------------------------------------------------
smoke_mysql() {
    banner "mysql"
    local t0; t0=$(now_ms)

    tear_down

    local up_t0; up_t0=$(now_ms)
    docker compose -f "$COMPOSE_FILE" --profile mysql up -d --wait --wait-timeout 240 >/dev/null
    step "stack up ($(( ($(now_ms) - up_t0) / 1000 ))s)"

    # shellcheck disable=SC2016 # variables intentionally expand inside the container, not on the host
    "$OPERATOR_CLI" exec mysql -- \
        sh -c 'exec mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"' \
        < "$FIXTURE_MYSQL" >/dev/null
    assert_eq "schema installed (mysql)" "$?" "0" || return 1

    # Query the view directly. The output is one JSON document per row; we
    # ask for both rows joined into a JSON array on the server side so we
    # can assert shape with jq.
    local body
    # shellcheck disable=SC2016 # variables intentionally expand inside the container, not on the host
    body=$("$OPERATOR_CLI" exec mysql -- \
        sh -c 'exec mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" --batch --raw -e "SELECT JSON_ARRAYAGG(data) AS posts FROM v_post;"' \
        | tail -n +2)
    # The output is a single line of JSON. The query column is `posts`.
    body="{\"data\":{\"posts\":$body}}"

    # source: src/content/docs/getting-started/quickstart.mdx:L118-L131 (v_post shape)
    assert_json_shape "$body" '.data.posts | type == "array"'         "data.posts is array"
    assert_json_shape "$body" '.data.posts | length == 1'             "data.posts has 1 element"
    assert_json_shape "$body" '.data.posts[0].title == "Hello FraiseQL"'         "post[0].title"
    assert_json_shape "$body" '.data.posts[0].author.name == "Alice Smith"'      "post[0].author.name"

    tear_down
    step "stack down clean"

    T_PER_DB[mysql]=$(( $(now_ms) - t0 ))
    return 0
}

# ---------------------------------------------------------------------------
# DB iteration #3 — SQLite. Same shape as MySQL iteration. The sqlite-init
# one-shot materialises /data/fraiseql.db; we then exec a second one-shot
# alpine container to apply the fixture and run the documented json_object
# query.
#
# source: src/content/docs/getting-started/quickstart.mdx:L134-L162 (SQLite views)
# ---------------------------------------------------------------------------
smoke_sqlite() {
    banner "sqlite"
    local t0; t0=$(now_ms)

    tear_down

    # Cycle 1 / Cycle 4 contract: `docs-test.sh up --profile sqlite` runs the
    # one-shot init via `compose run --rm sqlite-init`. The volume is then
    # available for other one-shot containers to mount.
    "$OPERATOR_CLI" up --profile sqlite >/dev/null
    step "sqlite volume materialised"

    # Apply the fixture and assert via a fresh alpine one-shot that mounts
    # the sqlite-data volume and runs sqlite3.
    "$OPERATOR_CLI" up --profile sqlite >/dev/null
    docker run --rm \
        -v fraiseql-docs-test_sqlite-data:/data \
        -v "$FIXTURE_SQLITE":/fixture.sql:ro \
        alpine:3.20@sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc \
        sh -c 'apk add --no-cache sqlite >/dev/null && sqlite3 /data/fraiseql.db ".read /fixture.sql"' \
        >/dev/null
    assert_eq "schema installed (sqlite)" "$?" "0" || return 1

    # Query v_post directly. SQLite json_object returns text; json_group_array
    # builds a JSON array of those documents.
    local body
    body=$(docker run --rm \
        -v fraiseql-docs-test_sqlite-data:/data:ro \
        alpine:3.20@sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc \
        sh -c "apk add --no-cache sqlite >/dev/null && sqlite3 /data/fraiseql.db \"SELECT json_group_array(json(data)) FROM v_post;\"")
    body="{\"data\":{\"posts\":$body}}"

    # source: src/content/docs/getting-started/quickstart.mdx:L148-L161 (v_post shape)
    assert_json_shape "$body" '.data.posts | type == "array"'         "data.posts is array"
    assert_json_shape "$body" '.data.posts | length == 1'             "data.posts has 1 element"
    assert_json_shape "$body" '.data.posts[0].title == "Hello FraiseQL"'         "post[0].title"
    assert_json_shape "$body" '.data.posts[0].author.name == "Alice Smith"'      "post[0].author.name"

    tear_down
    step "stack down clean"

    T_PER_DB[sqlite]=$(( $(now_ms) - t0 ))
    return 0
}

# ---------------------------------------------------------------------------
# DB iteration #4 — MSSQL (FOR JSON PATH). Slowest cold boot (~30 s start_period).
#
# source: src/content/docs/getting-started/quickstart.mdx:L164-L190 (SQL Server views)
# ---------------------------------------------------------------------------
smoke_mssql() {
    banner "mssql"
    local t0; t0=$(now_ms)

    tear_down

    local up_t0; up_t0=$(now_ms)
    docker compose -f "$COMPOSE_FILE" --profile mssql up -d --wait --wait-timeout 240 >/dev/null
    step "stack up ($(( ($(now_ms) - up_t0) / 1000 ))s)"

    # MSSQL container ships master only; the fixture starts with CREATE DATABASE.
    # Use the legacy mssql-tools sqlcmd path (Cycle 1's healthcheck fix path).
    # shellcheck disable=SC2016 # MSSQL_SA_PASSWORD expands inside the container, not on the host
    "$OPERATOR_CLI" exec mssql -- \
        sh -c '/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -d master -b -i /dev/stdin' \
        < "$FIXTURE_MSSQL" >/dev/null
    assert_eq "schema installed (mssql)" "$?" "0" || return 1

    # Query v_post; FOR JSON returns a single text column. Use STRING_AGG to
    # join multiple rows' JSON into an array shape.
    local raw
    raw=$("$OPERATOR_CLI" exec mssql -- \
        sh -c "/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P \"\$MSSQL_SA_PASSWORD\" -d fraiseql -h -1 -W -Q \"SET NOCOUNT ON; SELECT '[' + STRING_AGG(CAST(data AS NVARCHAR(MAX)), ',') + ']' FROM dbo.v_post;\"")
    # sqlcmd prints a trailing newline and possibly leading whitespace. Trim.
    raw=$(printf '%s' "$raw" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | head -n 1)
    local body="{\"data\":{\"posts\":$raw}}"

    # source: src/content/docs/getting-started/quickstart.mdx:L178-L189 (v_post shape)
    assert_json_shape "$body" '.data.posts | type == "array"'        "data.posts is array"
    assert_json_shape "$body" '.data.posts | length == 1'            "data.posts has 1 element"
    assert_json_shape "$body" '.data.posts[0].title == "Hello FraiseQL"'        "post[0].title"
    assert_json_shape "$body" '.data.posts[0].author.name == "Alice Smith"'     "post[0].author.name"

    tear_down
    step "stack down clean"

    T_PER_DB[mssql]=$(( $(now_ms) - t0 ))
    return 0
}

# ---------------------------------------------------------------------------
# Argument parsing — `_smoke.docs-test.sh [DB ...]`. Default: all four.
# ---------------------------------------------------------------------------
parse_args() {
    if [ $# -eq 0 ]; then
        DBS=(postgres mysql sqlite mssql)
        return
    fi
    for arg in "$@"; do
        case "$arg" in
            postgres|mysql|sqlite|mssql) DBS+=("$arg") ;;
            -h|--help)
                cat <<'EOF'
_smoke.docs-test.sh — Phase 00 Cycle 5 smoke reproduction.

Usage:
  scripts/docs-test/pages/_smoke.docs-test.sh [DB ...]

Without arguments, runs all four DBs: postgres, mysql, sqlite, mssql.
DB selection (e.g. `_smoke.docs-test.sh postgres mysql`) restricts the
iteration to a subset; useful for debugging a single backend.

Exits 0 if every requested DB passes; 1 on any failure; 2 on preflight error.
EOF
                exit 0
                ;;
            *) die "unknown DB '$arg' (expected: postgres|mysql|sqlite|mssql)" ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# main.
# ---------------------------------------------------------------------------
main() {
    parse_args "$@"
    preflight
    write_smoke_override

    T_TOTAL_START=$(now_ms)
    local overall_rc=0

    for db in "${DBS[@]}"; do
        case "$db" in
            postgres) if ! smoke_postgres; then overall_rc=1; fi ;;
            mysql)    if ! smoke_mysql;    then overall_rc=1; fi ;;
            sqlite)   if ! smoke_sqlite;   then overall_rc=1; fi ;;
            mssql)    if ! smoke_mssql;    then overall_rc=1; fi ;;
        esac
    done

    # Final summary.
    local total_ms=$(( $(now_ms) - T_TOTAL_START ))
    printf '\n=== summary ===\n'
    for db in "${DBS[@]}"; do
        local ms="${T_PER_DB[$db]:-0}"
        local marker
        if [ "$ms" -gt 0 ]; then
            marker="✓"
        else
            marker="✗"
        fi
        printf '  %s %-9s %d.%03ds\n' "$marker" "$db" "$(( ms / 1000 ))" "$(( ms % 1000 ))"
    done
    printf '  total      %d.%03ds (budget: <240s)\n' "$(( total_ms / 1000 ))" "$(( total_ms % 1000 ))"

    if [ "$overall_rc" -ne 0 ]; then
        err "FAILURES — see stderr above"
    fi

    return "$overall_rc"
}

main "$@"
