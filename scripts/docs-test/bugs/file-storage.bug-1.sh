#!/usr/bin/env bash
#
# file-storage.bug-1.sh — reproduction for FW-8 (presigned URL bypass).
#
# Filed: https://github.com/fraiseql/fraiseql/issues/335
# Registered: _internal/.plan/framework-qa-triage.md (FW-8)
#
# Persona: Bug-Finder (Opus 4.7), Phase 03 / Cycle 2 RED.
# Frozen FraiseQL SHA: d0a4ed4ec1770c70707f68fd9019f2b561d87461 (v2.3.2).
#
# ============================================================================
# Expected (per StorageRlsEvaluator design, crates/fraiseql-storage/src/rls/mod.rs:L17-L107):
#
#   Access to private bucket objects requires an authenticated user whose
#   `user_id` matches the object's `owner_id`, OR the `admin` role. Public
#   buckets allow anonymous reads but writes require authentication. The
#   presigned-URL endpoint grants direct backend access bypassing the
#   server's auth, RLS, MIME-type check, and size cap — so it MUST itself
#   be gated by RLS before issuing the URL.
#
# Actual (at frozen SHA, crates/fraiseql-storage/src/routes/mod.rs:L373-L434):
#
#   `presign_handler` has the following signature:
#
#       async fn presign_handler(
#           State(state): State<StorageState>,
#           Path((bucket_name, key)): Path<(String, String)>,
#           axum::Json(request): axum::Json<PresignRequest>,
#       ) -> Response
#
#   Note the ABSENCE of `user: Option<Extension<StorageUser>>` — the parameter
#   present in `put_handler`, `get_handler`, `delete_handler`, and `list_handler`.
#   The handler:
#     1. Looks up the bucket (404 on missing).
#     2. Validates `operation` ∈ {"upload","download"}.
#     3. Validates `expires_in_secs` ∈ (0, 86400].
#     4. Calls `state.backend.presign_put` / `presign_get` directly.
#
#   At NO POINT does it call `state.rls.can_read(...)` or `state.rls.can_write(...)`.
#   No metadata lookup is performed (so even owner-id matching is impossible).
#
# Consequence (security — critical):
#
#   1. Anonymous client → POST /storage/v1/presign/private-bucket/secret.pdf
#      with body `{"operation":"download","expires_in_secs":86400}` →
#      receives a 24-hour valid presigned URL that GETs the object directly
#      from S3 without further checks.
#
#   2. Anonymous client → same endpoint with `"operation":"upload"` →
#      receives a presigned PUT URL allowing them to overwrite ANY object
#      in ANY bucket, including private buckets owned by other users, with
#      arbitrary content.
#
#   3. The legacy server route (`crates/fraiseql-server/src/routes/storage/mod.rs`)
#      has no RLS at all — but the `legacy` path is what the page would have
#      documented; the modern crate is what the CHANGELOG entry at L66-L69
#      promotes ("storage subsystem with RLS-enforced access control"). The
#      modern crate's presign path is the contradiction.
#
# This script is a static-source reproduction (per FW-7 #334, the binary
# doesn't auto-wire the storage routes, so a live HTTP repro requires a
# host-binary patch — out of scope for the Bug-Finder persona). The
# assertion is: the source at the frozen SHA has no `rls.can_` call inside
# `presign_handler`'s function body.
#
# Exit codes:
#   0  — bug NOT reproduced (presign_handler now invokes RLS — file follow-up).
#   1  — bug REPRODUCED (presign_handler still skips RLS at frozen SHA).
# ============================================================================

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
FRAISEQL_REPO="$(cd "$HERE"/../../../fraiseql && pwd)"
FRAISEQL_SHA="$(cat "$HERE/FRAISEQL_SHA")"

echo "================================================================"
echo "FW-8 reproduction — presign_handler bypasses StorageRlsEvaluator"
echo "FraiseQL SHA: $FRAISEQL_SHA"
echo "================================================================"

if ! git -C "$FRAISEQL_REPO" cat-file -e "$FRAISEQL_SHA"; then
    echo "ERROR: frozen SHA $FRAISEQL_SHA not present in $FRAISEQL_REPO" >&2
    exit 2
fi

SRC=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-storage/src/routes/mod.rs")

# Locate `async fn presign_handler` and extract its body. The body ends at the
# first line matching `^}` after the opening `{`.
start_line=$(printf '%s\n' "$SRC" | grep -n '^async fn presign_handler' | head -1 | cut -d: -f1)
if [[ -z "${start_line:-}" ]]; then
    echo "BUG NOT REPRODUCED: presign_handler signature not found at the expected location." >&2
    exit 0
fi

# Print signature + first 12 lines so the reader can see the missing user param.
echo
echo "Signature (lines ${start_line}..$((start_line+10))):"
printf '%s\n' "$SRC" | sed -n "${start_line},$((start_line+10))p"

# Function body ends at first standalone "^}" after start.
end_line=$(printf '%s\n' "$SRC" | awk -v s="$start_line" 'NR>=s && /^}/{print NR; exit}')
body=$(printf '%s\n' "$SRC" | sed -n "${start_line},${end_line}p")

# Bug-shape assertion 1 — the function signature must NOT contain `StorageUser`.
sig_block=$(printf '%s\n' "$body" | sed -n '1,8p')
if printf '%s\n' "$sig_block" | grep -q 'StorageUser'; then
    echo "BUG NOT REPRODUCED: presign_handler now extracts a StorageUser parameter." >&2
    exit 0
fi

# Bug-shape assertion 2 — the body must contain no `rls.can_` call.
if printf '%s\n' "$body" | grep -Eq 'rls\.(can_read|can_write|can_delete|filter_visible)'; then
    echo "BUG NOT REPRODUCED: presign_handler now invokes the RLS evaluator." >&2
    exit 0
fi

# Bug-shape assertion 3 — the body must contain no `metadata.get(` call (which
# would be required for any owner-id check).
if printf '%s\n' "$body" | grep -Eq 'metadata\.(get|list)\s*\('; then
    echo "BUG NOT REPRODUCED: presign_handler now performs a metadata lookup (path to owner check)." >&2
    exit 0
fi

# Confirm peer handlers DO check RLS (so the divergence is real).
peer_check=$(printf '%s\n' "$SRC" | grep -c 'state\.rls\.can_')
if (( peer_check < 3 )); then
    echo "BUG NOT REPRODUCED in expected shape: peer handlers also skip RLS (different bug)." >&2
    exit 0
fi

cat <<MSG

================================================================
Bug-shape assertion:
================================================================
- presign_handler signature lacks user: Option<Extension<StorageUser>>
- presign_handler body contains no state.rls.can_{read,write,delete} call
- presign_handler body contains no state.metadata.get(...) call (so owner_id
  matching is unreachable)
- Peer handlers (put/get/delete) DO check RLS — observed ${peer_check} calls
  to state.rls.can_ across the file. The divergence is real.

BUG REPRODUCED.

Impact (security, critical severity):
  - Anonymous POST /storage/v1/presign/<any-bucket>/<any-key>
    {"operation":"download","expires_in_secs":86400}
    issues a 24h-valid presigned GET URL for ANY object in ANY bucket,
    including objects in private buckets owned by other users.
  - Anonymous POST /storage/v1/presign/<any-bucket>/<any-key>
    {"operation":"upload","content_type":"...","expires_in_secs":86400}
    issues a presigned PUT URL allowing arbitrary overwrite of ANY object
    in ANY bucket — bypassing all bucket-level MIME / size constraints
    (those checks live in put_handler, not on the S3 presigned URL).

Suggested fix:
  - Add user: Option<Extension<StorageUser>> to presign_handler.
  - For operation="download": metadata.get(bucket,key), then can_read.
  - For operation="upload":  can_write check (with bucket's MIME/size
    constraints encoded into the presign_put request itself if the
    backend supports it; otherwise reject upload presigns for buckets
    that have MIME/size restrictions configured, or document the
    by-design bypass).

Affected page draft: /features/file-storage. Until fixed:
  - Page MUST warn that the presign endpoint is unauthenticated and the
    presigned URL bypasses every server-side check.
  - Page SHOULD recommend host-binary middleware that wraps the
    storage_router and rejects /storage/v1/presign/* without auth, OR
    deploys the storage routes behind a separate auth gate.
MSG
exit 1
