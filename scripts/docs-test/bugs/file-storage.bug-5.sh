#!/usr/bin/env bash
#
# file-storage.bug-5.sh — reproduction for FW-12 (LIKE-pattern injection in
# the storage metadata list query; client-supplied `prefix` is interpolated
# into a LIKE pattern without escaping `%` or `_`).
#
# Filed: https://github.com/fraiseql/fraiseql/issues/339
# Registered: _internal/.plan/framework-qa-triage.md (FW-12)
#
# Persona: Bug-Finder (Opus 4.7), Phase 03 / Cycle 2 RED.
# Frozen FraiseQL SHA: d0a4ed4ec1770c70707f68fd9019f2b561d87461 (v2.3.2).
#
# ============================================================================
# Expected (per the API surface implied by `ListQuery.prefix` at
# crates/fraiseql-storage/src/routes/mod.rs:L99-L106):
#
#   `prefix` is documented as "Filter by key prefix" — a literal prefix
#   match. A user requesting `prefix="docs/"` should see only keys
#   beginning with the literal string `docs/`.
#
# Actual (at frozen SHA, crates/fraiseql-storage/src/metadata/mod.rs:L166-L182):
#
#   The list query interpolates the client-supplied prefix into a LIKE
#   pattern WITHOUT escaping:
#
#       sqlx::query_as::<_, MetadataQueryRow>(
#           "SELECT ... FROM _fraiseql_storage_objects \
#            WHERE bucket = $1 AND key LIKE $2 \
#            ORDER BY key ASC \
#            LIMIT $3 OFFSET $4",
#       )
#       .bind(bucket)
#       .bind(format!("{pfx}%"))   // <-- {pfx} is not escaped for LIKE
#
#   PostgreSQL's LIKE treats `%` as "any sequence" and `_` as "any one
#   character". A client that supplies `prefix="%secret"` matches every key
#   ending with `secret` in the bucket — not just keys starting with that
#   literal string.
#
# Consequence (security / information disclosure on Private buckets):
#
#   1. `prefix="_"` matches every single-character key prefix in the
#      bucket — effectively a "list everything" wildcard.
#   2. `prefix="%"` matches every key in the bucket regardless of structure.
#   3. `prefix="%admin%"` finds every key containing the substring "admin"
#      anywhere — useful for reconnaissance against namespacing schemes
#      that put privileged identifiers in the key.
#   4. On a Private bucket, RLS filter_visible (rls/mod.rs:L91-L107) keeps
#      the user from seeing other owners' rows — but the SQL query itself
#      still hits every row in the bucket, and the (key, content-type,
#      size, etag, created_at) metadata for owned rows whose existence
#      the user is allowed to enumerate may include rows the user would
#      not have known to ask about by literal prefix.
#   5. On a PublicRead bucket, ALL matched rows are returned — full
#      enumeration is exposed.
#
#   The bug is bounded by the (limit, offset) pagination, but pagination
#   does not bound information disclosure — it just makes the attacker
#   page through the matches.
#
# This script is a static-source reproduction. It asserts that:
#   (a) `metadata::list` interpolates `prefix` into a LIKE pattern with no
#       escape helper for `%` / `_`.
#   (b) The route layer (`routes/mod.rs:L356-L368`) forwards the raw
#       client-supplied `query.prefix` without any sanitization.
#
# Exit codes:
#   0  — bug NOT reproduced (LIKE escape added, or prefix changed to a
#        literal-prefix match) — file follow-up.
#   1  — bug REPRODUCED (LIKE-pattern injection at frozen SHA).
# ============================================================================

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
FRAISEQL_REPO="$(cd "$HERE"/../../../fraiseql && pwd)"
FRAISEQL_SHA="$(cat "$HERE/FRAISEQL_SHA")"

echo "================================================================"
echo "FW-12 reproduction — LIKE-pattern injection in list query"
echo "FraiseQL SHA: $FRAISEQL_SHA"
echo "================================================================"

if ! git -C "$FRAISEQL_REPO" cat-file -e "$FRAISEQL_SHA"; then
    echo "ERROR: frozen SHA $FRAISEQL_SHA not present in $FRAISEQL_REPO" >&2
    exit 2
fi

META=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-storage/src/metadata/mod.rs")
ROUTES=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-storage/src/routes/mod.rs")

# (a) metadata::list interpolates prefix into LIKE without escaping.
echo
echo "Relevant metadata::list slice (frozen SHA):"
printf '%s\n' "$META" | grep -nE 'WHERE bucket = \$1 AND key LIKE|format!\("\{pfx\}%"\)|\.bind\(format!\("\{pfx\}' || true

if ! printf '%s\n' "$META" | grep -qE 'format!\("\{pfx\}%"\)'; then
    echo "BUG NOT REPRODUCED: metadata::list no longer interpolates {pfx} into a LIKE format!." >&2
    exit 0
fi

# Defence check: ESCAPE clause present?
if printf '%s\n' "$META" | grep -qE "LIKE\s+\\\$2\s+ESCAPE"; then
    echo "BUG NOT REPRODUCED: LIKE pattern now uses ESCAPE." >&2
    exit 0
fi

# Defence check: any pre-bind escape of % and _?
if printf '%s\n' "$META" | grep -qE 'replace\("%"\s*,\s*"\\\\\\\\%"\)|replace\("_",'; then
    echo "BUG NOT REPRODUCED: prefix appears to be escaped before binding." >&2
    exit 0
fi

# (b) Route layer forwards the raw prefix without normalisation.
list_block=$(printf '%s\n' "$ROUTES" | awk '/^async fn list_handler/,/^}/')
if ! printf '%s\n' "$list_block" | grep -q 'query.prefix.as_deref()'; then
    echo "BUG NOT REPRODUCED: list_handler no longer forwards query.prefix verbatim." >&2
    exit 0
fi

if printf '%s\n' "$list_block" | grep -qE 'sanitize_prefix|escape_like|escape_prefix'; then
    echo "BUG NOT REPRODUCED: list_handler now sanitises the prefix." >&2
    exit 0
fi

cat <<'MSG'

================================================================
Bug-shape assertion:
================================================================
- metadata::list interpolates the user-supplied prefix into a LIKE
  pattern with format!("{pfx}%") and no ESCAPE clause.
- list_handler in routes/mod.rs forwards query.prefix.as_deref() unmodified.
- No `replace("%", ...)` or `replace("_", ...)` defence is present.

BUG REPRODUCED.

Proof-of-impact queries (against a PublicRead bucket):
  GET /storage/v1/list/<bucket>?prefix=%25            → lists every key
  GET /storage/v1/list/<bucket>?prefix=_              → lists every key with
                                                        a single-character prefix
  GET /storage/v1/list/<bucket>?prefix=%25admin%25    → enumerates keys
                                                        containing "admin"

Impact (regression severity, information disclosure on PublicRead
buckets; weaker enumeration on Private buckets where filter_visible
still gates the rows returned):
  - Bucket-wide key enumeration bypassing any client-side prefix scheme.
  - Reconnaissance against bucket namespacing patterns that encode
    privileged identifiers in the key.
  - On Private buckets, the SQL still touches every matching row even
    though `filter_visible` drops them post-query — wasted DB work
    bounded by limit+offset.

Suggested fix:
  1. Escape `%`, `_`, and the LIKE escape character before binding,
     OR
  2. Add an ESCAPE clause to the LIKE expression and pre-escape
     special characters, OR
  3. Replace `LIKE` with `key >= $2 AND key < <next-prefix>` using
     PostgreSQL's prefix-range trick — a true literal prefix match.

Workaround for docs (Phase 03):
  - Page MUST describe the `prefix` argument as a "LIKE pattern" (the
    actual behaviour) until the framework fix lands, OR
  - Page MUST warn operators that `list{Bucket}Objects` and
    `GET /storage/v1/list/{bucket}?prefix=...` accept LIKE wildcards
    and that PublicRead buckets are enumerable.
MSG
exit 1
