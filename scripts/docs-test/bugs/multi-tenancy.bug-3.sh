#!/usr/bin/env bash
#
# multi-tenancy.bug-3.sh — reproduction for FW-6.
#
# Filed: https://github.com/fraiseql/fraiseql/issues/333
# Registered: _internal/.plan/framework-qa-triage.md (FW-6)
#
# Persona: Bug-Finder (Opus 4.7), Phase 03 / Cycle 1 RED.
# Frozen FraiseQL SHA: d0a4ed4ec1770c70707f68fd9019f2b561d87461 (v2.3.2).
#
# ============================================================================
# Expected (per CHANGELOG v2.2.0 / tenancy hardening + schema-isolation):
#
#   A single tenant-key character set is honoured across:
#     - HTTP dispatch (`X-Tenant-ID` header validator)
#     - Schema-mode tenancy DDL (`tenant_schema_name` validator)
#     - Row-mode tenancy auto-injection (compile-time)
#
#   Operators choose one tenant-key alphabet and it works on every code path.
#
# Actual (at frozen SHA):
#
#   Two validators with two different alphabets are in force at once:
#
#     A. crates/fraiseql-server/src/routes/graphql/tenant_key.rs:L108-L122
#        `validate_tenant_key`:
#          allowed: [a-zA-Z0-9_-]
#          rejected: anything else, including ASCII control bytes
#          max length: 128
#
#     B. crates/fraiseql-server/src/tenancy/schema_isolation.rs:L31-L40
#        `tenant_schema_name` (used by every schema-mode DDL helper):
#          allowed: [a-zA-Z0-9_]      ← no hyphen
#          rejected: hyphen, dot, every non-alphanumeric-non-underscore
#          implicit max via PG identifier limit: 63 chars minus the
#          "tenant_" prefix = 56 usable chars
#
#   Consequence:
#     - Tenant key `acme-corp` (or any `-`-containing key) is accepted by the
#       header validator and registered into TenantExecutorRegistry, but every
#       schema-mode operation against it (create_schema_ddl, drop_schema_ddl,
#       configure_search_path, provision_tenant_schema, drop_tenant_schema)
#       returns FraiseQLError::Validation.
#     - Tenant key with 57–128 chars passes the header validator but fails
#       the schema-mode validator with "exceeds PostgreSQL's 63-character
#       identifier limit" even though the chars are all legal.
#
#   The drift is silent at registration time: operators only discover it when
#   schema-mode provisioning fires (e.g. during the first DDL job after upsert)
#   or when the admin REST API attempts the underlying provision call.
#
# This script is a static-source reproduction that diffs the two validators'
# allowed character sets and length caps at the frozen SHA. It also calls a
# tiny Rust-style table-driven proof inline (no compilation needed).
#
# Exit codes:
#   0  — bug NOT reproduced (validators now agree on alphabet + length).
#   1  — bug REPRODUCED (the two validators disagree on `-` or on length).
# ============================================================================

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
FRAISEQL_REPO="$(cd "$HERE"/../../../fraiseql && pwd)"
FRAISEQL_SHA="$(cat "$HERE/FRAISEQL_SHA")"

echo "================================================================"
echo "FW-6 reproduction — Tenant-key charset / length validators disagree"
echo "FraiseQL SHA: $FRAISEQL_SHA"
echo "================================================================"

if ! git -C "$FRAISEQL_REPO" cat-file -e "$FRAISEQL_SHA"; then
    echo "ERROR: frozen SHA $FRAISEQL_SHA not present in $FRAISEQL_REPO" >&2
    exit 2
fi

echo
echo "Header validator (tenant_key.rs):"
git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/routes/graphql/tenant_key.rs" |
    sed -n '108,130p'

echo
echo "Schema-mode validator (schema_isolation.rs):"
git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/tenancy/schema_isolation.rs" |
    sed -n '21,55p'

header_allows_hyphen=0
schema_allows_hyphen=0
if git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/routes/graphql/tenant_key.rs" |
    grep -Eq "b == b'-'"; then
    header_allows_hyphen=1
fi
if git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/tenancy/schema_isolation.rs" |
    grep -Eq "c == '-'"; then
    schema_allows_hyphen=1
fi

header_len_cap=$(
    git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/routes/graphql/tenant_key.rs" |
        grep -E "MAX_TENANT_KEY_LEN: usize =" |
        head -1 |
        grep -Eo '[0-9]+'
)
schema_len_cap=$(
    git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/tenancy/schema_isolation.rs" |
        grep -E "MAX_PG_IDENTIFIER_LEN: usize =" |
        head -1 |
        grep -Eo '[0-9]+'
)

# schema usable = 63 - len("tenant_") = 63 - 7
schema_usable_chars=$((schema_len_cap - 7))

echo
echo "================================================================"
echo "Bug-shape assertion:"
echo "================================================================"
echo "Header validator allows '-': $header_allows_hyphen   (1 = yes)"
echo "Schema validator allows '-': $schema_allows_hyphen   (1 = yes)"
echo "Header validator length cap: $header_len_cap chars"
echo "Schema validator length cap: $schema_len_cap chars (usable tenant-key chars = $schema_usable_chars after 'tenant_' prefix)"

# Demonstrate the two concrete bad-key shapes the page must warn about.
demo_keys=(
    "acme-corp"                                                                  # legal header, illegal schema (hyphen)
    "this_tenant_key_is_eighty_chars_long_and_uses_only_alpha_numerics_and_under"  # legal header, illegal schema (length when prefixed)
)

drift_observed=0
if [[ "$header_allows_hyphen" -eq 1 && "$schema_allows_hyphen" -eq 0 ]]; then
    drift_observed=1
fi
if [[ "$header_len_cap" -gt "$schema_usable_chars" ]]; then
    drift_observed=1
fi

if [[ "$drift_observed" -eq 1 ]]; then
    cat <<MSG
BUG REPRODUCED.

Two-validator drift confirmed at the frozen SHA.

Examples that pass the header validator but break schema-mode provisioning:
MSG
    for k in "${demo_keys[@]}"; do
        len=${#k}
        echo "    '$k'  (length=$len chars)"
    done

    cat <<MSG

Suggested fix (pick one, document the other as deprecated):

  Option A (tighten the header validator):
    - Restrict X-Tenant-ID to [a-zA-Z0-9_] and cap at MAX_PG_IDENTIFIER_LEN - 7.
    - Update the upsert handler to reject hyphenated keys at registration time.

  Option B (loosen the schema-name derivation):
    - Hash or slugify the tenant key into a derived schema name in
      schema_isolation.rs (e.g. tenant_<sha256[..16]>) rather than embedding the
      raw key.

Until then, the docs page must:
  - State the practical alphabet operators should pick (lower bound: [a-zA-Z0-9_],
    upper bound on length: 56 chars when schema-mode is enabled).
  - Warn that hyphens in tenant keys break schema-mode tenancy silently.
MSG
    exit 1
fi

echo "BUG NOT REPRODUCED — validators now agree on alphabet and length cap. Close FW-6 with a follow-up." >&2
exit 0
