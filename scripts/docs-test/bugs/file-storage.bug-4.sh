#!/usr/bin/env bash
#
# file-storage.bug-4.sh — reproduction for FW-11 (server-wide
# `max_request_body_bytes = 1 MB` default silently caps every storage
# upload; per-route / per-bucket size limits are unreachable until the
# operator raises the global cap).
#
# Filed: https://github.com/fraiseql/fraiseql/issues/338
# Registered: _internal/.plan/framework-qa-triage.md (FW-11)
#
# Persona: Bug-Finder (Opus 4.7), Phase 03 / Cycle 2 RED.
# Frozen FraiseQL SHA: d0a4ed4ec1770c70707f68fd9019f2b561d87461 (v2.3.2).
#
# ============================================================================
# Expected (per StorageRouteState::DEFAULT_MAX_UPLOAD_BYTES = 100 MB at
# crates/fraiseql-server/src/routes/storage/mod.rs:L32 and per per-bucket
# `max_object_bytes` documentation at crates/fraiseql-storage/src/config/mod.rs:L46):
#
#   An operator who deploys with default config can upload files up to the
#   storage layer's documented 100 MB cap on the legacy route, and up to
#   any per-bucket `max_object_bytes` on the modern route (unlimited when
#   None). The size cap is enforced at the storage layer.
#
# Actual (at frozen SHA):
#
#   1. crates/fraiseql-server/src/server_config/defaults.rs:L32-L36
#      defines `default_max_request_body_bytes() -> 1_048_576` (1 MB).
#
#   2. crates/fraiseql-server/src/server/routing/middleware.rs:L39-L45
#      applies that limit GLOBALLY to every route:
#
#          app = app.layer(DefaultBodyLimit::max(self.config.max_request_body_bytes));
#
#   3. The legacy storage route at crates/fraiseql-server/src/routes/storage/mod.rs
#      declares DEFAULT_MAX_UPLOAD_BYTES = 100 MB and checks `body.len() > state.max_upload_bytes`
#      at L164 — but axum's DefaultBodyLimit fires first, returning a generic
#      413 with no FileError::TooLarge body. The 100 MB cap is unreachable.
#
#   4. The modern storage route at crates/fraiseql-storage/src/routes/mod.rs:L167-L182
#      checks `bucket.max_object_bytes` against body.len() — same problem:
#      the global 1 MB cap intercepts uploads first.
#
#   5. The body is extracted as `body: Bytes` (routes/mod.rs:L148 and
#      routes/storage/mod.rs:L158) — fully buffered into memory before the
#      per-route or per-bucket check runs. If the operator raises
#      `max_request_body_bytes` to 1 GB to accommodate large uploads on
#      a storage bucket, EVERY OTHER ROUTE (GraphQL, REST, admin, RBAC, ...)
#      also accepts 1 GB request bodies — a denial-of-service amplifier.
#
# Consequence:
#
#   1. Documentation discoverability: the storage page must instruct the
#      operator to raise `max_request_body_bytes` to match the largest
#      bucket's `max_object_bytes`. The stale page does not.
#
#   2. Defence-in-depth gap: there is no per-route body limit. Raising
#      max_request_body_bytes for storage opens every other route. The
#      framework needs `BodyLimitLayer` applied per-route — currently
#      only `DefaultBodyLimit::max` is used.
#
#   3. DoS surface: with operator-recommended config for typical storage
#      (e.g., 100 MB), GraphQL endpoint accepts 100 MB query bodies — well
#      above the protective `default_max_get_query_bytes() = 100 KB` cap
#      for GET queries, but POST GraphQL is unprotected.
#
# This script is a static-source reproduction. Asserts:
#   (a) default_max_request_body_bytes() returns 1_048_576.
#   (b) DefaultBodyLimit::max is applied at the router level (global), not
#       per-route.
#   (c) DEFAULT_MAX_UPLOAD_BYTES in legacy storage route is 100 * 1024 * 1024
#       (proving the divergence is real).
#   (d) Modern storage route extracts body as Bytes (full buffering before
#       per-bucket size check).
#
# Exit codes:
#   0  — bug NOT reproduced (defaults aligned, or per-route limit added) — follow-up.
#   1  — bug REPRODUCED (default mismatch + global-only enforcement at frozen SHA).
# ============================================================================

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
FRAISEQL_REPO="$(cd "$HERE"/../../../fraiseql && pwd)"
FRAISEQL_SHA="$(cat "$HERE/FRAISEQL_SHA")"

echo "================================================================"
echo "FW-11 reproduction — global 1 MB body limit silently caps storage"
echo "FraiseQL SHA: $FRAISEQL_SHA"
echo "================================================================"

if ! git -C "$FRAISEQL_REPO" cat-file -e "$FRAISEQL_SHA"; then
    echo "ERROR: frozen SHA $FRAISEQL_SHA not present in $FRAISEQL_REPO" >&2
    exit 2
fi

DEFAULTS=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/server_config/defaults.rs")
MIDDLEWARE=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/server/routing/middleware.rs")
LEGACY_STORAGE=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-server/src/routes/storage/mod.rs")
MODERN_STORAGE=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-storage/src/routes/mod.rs")

# (a) default_max_request_body_bytes returns 1_048_576 (multi-line fn body).
default_value=$(printf '%s\n' "$DEFAULTS" | awk '
    /pub const fn default_max_request_body_bytes/ {grab=1; next}
    grab && /^}/ {grab=0}
    grab && /[0-9_]+/ {gsub(/[^0-9_]/, ""); if (length($0)) {print; exit}}
')
if [[ "$default_value" != "1_048_576" ]]; then
    echo "BUG NOT REPRODUCED: default_max_request_body_bytes() no longer returns 1_048_576 (observed: $default_value)." >&2
    exit 0
fi

# (b) DefaultBodyLimit::max applied at app level (global), not per route.
if ! printf '%s\n' "$MIDDLEWARE" | grep -q 'app = app.layer(DefaultBodyLimit::max'; then
    echo "BUG NOT REPRODUCED: DefaultBodyLimit::max no longer applied at the app/router level." >&2
    exit 0
fi

# Confirm no per-route body limit on /storage/v1/object.
if printf '%s\n' "$LEGACY_STORAGE" "$MODERN_STORAGE" | grep -qE 'DefaultBodyLimit|RequestBodyLimitLayer'; then
    echo "BUG NOT REPRODUCED: per-route body limit added in storage routes." >&2
    exit 0
fi

# (c) Legacy DEFAULT_MAX_UPLOAD_BYTES = 100 * 1024 * 1024
if ! printf '%s\n' "$LEGACY_STORAGE" | grep -qE 'DEFAULT_MAX_UPLOAD_BYTES.*100.*1024'; then
    echo "BUG NOT REPRODUCED: legacy DEFAULT_MAX_UPLOAD_BYTES no longer 100 MB." >&2
    exit 0
fi

# (d) Modern routes use body: Bytes (full buffering).
if ! printf '%s\n' "$MODERN_STORAGE" | grep -qE 'body:\s*Bytes'; then
    echo "BUG NOT REPRODUCED: modern routes no longer use Bytes for body." >&2
    exit 0
fi

cat <<'MSG'

================================================================
Bug-shape assertion:
================================================================
- server_config/defaults.rs: default_max_request_body_bytes() = 1_048_576 (1 MB).
- server/routing/middleware.rs: DefaultBodyLimit::max applied at the app
  layer — every route inherits the same limit.
- routes/storage/mod.rs (legacy): DEFAULT_MAX_UPLOAD_BYTES = 100 MB —
  unreachable behind the 1 MB global cap.
- routes/mod.rs (modern): body extracted as Bytes (full buffering) before
  bucket.max_object_bytes is consulted.
- No per-route body limit applied to /storage/v1/object/* in either path.

BUG REPRODUCED.

Impact (regression severity):
  - With default config, every storage upload >1 MB returns axum's generic
    413 with no FileError::TooLarge body — confusing for clients expecting
    the documented FileError envelope (CHANGELOG v2.3 L66-L69).
  - Operators raising max_request_body_bytes to accommodate storage uploads
    expose every other route (GraphQL, REST, admin, RBAC) to the same
    elevated body cap — broad DoS amplifier.
  - The body: Bytes extractor fully buffers the upload before any size
    check; the actual memory exhaustion bound is the operator-configured
    max_request_body_bytes, multiplied by concurrent uploads.

Suggested fix:
  1. Apply a per-route DefaultBodyLimit::max to the storage router,
     sized from StorageRouteState::max_upload_bytes (legacy) or the
     maximum of bucket.max_object_bytes across configured buckets (modern).
     Override the global limit when storage is mounted.
  2. Document the global-limit / storage-limit interaction in the
     CHANGELOG entry. The current entry promises a typed FileError but
     the typical user hits a generic 413 long before FileError fires.
  3. Consider streaming uploads (body: BodyStream) for large objects to
     bound per-request memory.

Workaround for docs (Phase 03):
  - Page MUST instruct operators to set max_request_body_bytes to at least
    the largest expected upload size + a small overhead.
  - Page SHOULD warn that raising max_request_body_bytes affects every
    other route and recommend deploying the storage routes on a separate
    server instance with their own body-limit configuration when very
    large uploads are required.
MSG
exit 1
