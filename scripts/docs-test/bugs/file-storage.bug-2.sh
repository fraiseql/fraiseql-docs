#!/usr/bin/env bash
#
# file-storage.bug-2.sh — reproduction for FW-9 (bucket name dropped in
# backend storage path; cross-bucket key collisions corrupt content).
#
# Filed: https://github.com/fraiseql/fraiseql/issues/336
# Registered: _internal/.plan/framework-qa-triage.md (FW-9)
#
# Persona: Bug-Finder (Opus 4.7), Phase 03 / Cycle 2 RED.
# Frozen FraiseQL SHA: d0a4ed4ec1770c70707f68fd9019f2b561d87461 (v2.3.2).
#
# ============================================================================
# Expected (per CHANGELOG v2.3 storage subsystem entry and per the
# `t_storage_<bucket>` per-bucket type generation at
# crates/fraiseql-storage/src/graphql/mod.rs:L99,L175):
#
#   Buckets are an isolation boundary. An object at (bucket=A, key=x) and an
#   object at (bucket=B, key=x) are distinct objects with independent content,
#   independent access policies, and independent owners. The backend layer
#   must store them at distinct backend keys; otherwise the metadata layer
#   says they are distinct but the bytes are shared.
#
# Actual (at frozen SHA, crates/fraiseql-storage/src/routes/mod.rs):
#
#   put_handler   (L208): state.backend.upload(&key, &body, content_type)
#   get_handler   (L266): state.backend.download(&key)
#   delete_handler(L319): state.backend.delete(&key)
#   presign       (L414): state.backend.presign_put(&key, ...)
#                 (L416): state.backend.presign_get(&key, ...)
#
#   In every call, ONLY the path-extracted `key` is forwarded — the
#   `bucket_name` segment is discarded. The metadata table (`_fraiseql_storage_objects`,
#   `migrations/mod.rs:L36-L48`) records the bucket column and enforces a
#   UNIQUE(bucket,key), so the METADATA layer keeps the buckets distinct.
#   The BACKEND layer treats them as the same object.
#
# Consequence:
#
#   1. Data corruption: two tenants upload `report.pdf` to two different
#      buckets ("acme-private" and "nova-public"). The backend stores both
#      at key `report.pdf`. The second upload silently overwrites the first.
#      A subsequent GET /storage/v1/object/acme-private/report.pdf returns
#      Nova's file content with Acme's metadata (size, etag, owner_id) —
#      classic data-integrity hazard.
#
#   2. Cross-bucket read amplification: if bucket "private" is RLS=Private
#      and bucket "public" is RLS=PublicRead, an attacker can upload arbitrary
#      content to `public/<victim-key>` and corrupt the victim's `private/<key>`
#      backend bytes — even though they cannot directly read `private/<key>`.
#
#   3. Delete-cascade across buckets: DELETE /storage/v1/object/public/report.pdf
#      removes the backend bytes that the metadata for `private/report.pdf`
#      still references → subsequent download returns FileError::NotFound
#      even though the metadata row is intact. Inconsistent state.
#
#   4. Presigned-URL amplification (compounds bug-1): an anonymous client
#      who obtains a presigned URL for `public/<victim-key>` (bug-1) can use
#      it to overwrite or delete the victim's bytes in a private bucket they
#      share a key name with.
#
# This script is a static-source reproduction. The assertion is that the
# string `bucket_name` (or the bucket variable) is NOT passed to any of
# the backend methods.
#
# Exit codes:
#   0  — bug NOT reproduced (bucket name now forwarded to backend) — file follow-up.
#   1  — bug REPRODUCED (bucket name dropped at frozen SHA).
# ============================================================================

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
FRAISEQL_REPO="$(cd "$HERE"/../../../fraiseql && pwd)"
FRAISEQL_SHA="$(cat "$HERE/FRAISEQL_SHA")"

echo "================================================================"
echo "FW-9 reproduction — bucket name dropped before backend call"
echo "FraiseQL SHA: $FRAISEQL_SHA"
echo "================================================================"

if ! git -C "$FRAISEQL_REPO" cat-file -e "$FRAISEQL_SHA"; then
    echo "ERROR: frozen SHA $FRAISEQL_SHA not present in $FRAISEQL_REPO" >&2
    exit 2
fi

SRC=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-storage/src/routes/mod.rs")

# Extract every backend.* invocation.
echo
echo "Every backend.* call in routes/mod.rs at frozen SHA:"
printf '%s\n' "$SRC" | grep -nE 'state\.backend\.(upload|download|delete|presign_put|presign_get)\(' || true

# Bug-shape assertion: in EVERY backend.<op> call, the first argument must
# be `&key` (or `key`) with no bucket-name component composed.
fail=0
for line in $(printf '%s\n' "$SRC" | grep -nE 'state\.backend\.(upload|download|delete|presign_put|presign_get)\(' | cut -d: -f1); do
    call_line=$(printf '%s\n' "$SRC" | sed -n "${line}p")
    # Look at the next 4 lines (Rust formatter may break long signatures).
    region=$(printf '%s\n' "$SRC" | sed -n "${line},$((line+4))p")
    if printf '%s\n' "$region" | grep -Eq 'state\.backend\.(upload|download|delete|presign_put|presign_get)\([^)]*bucket'; then
        echo "BUG NOT REPRODUCED at line $line: backend call appears to include bucket — $call_line" >&2
        fail=1
        break
    fi
done

if [[ "$fail" -eq 1 ]]; then
    exit 0
fi

# Confirm the metadata table DOES key on (bucket, key) so the divergence is real.
MIG=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-storage/src/migrations/mod.rs")
if ! printf '%s\n' "$MIG" | grep -q 'UNIQUE (bucket, key)'; then
    echo "BUG NOT REPRODUCED in expected shape: metadata table does not key on (bucket,key) — different bug." >&2
    exit 0
fi

cat <<'MSG'

================================================================
Bug-shape assertion:
================================================================
- Every backend.{upload,download,delete,presign_put,presign_get} call in
  routes/mod.rs passes only the path key — no bucket-name composition.
- The metadata table (_fraiseql_storage_objects) has UNIQUE(bucket, key),
  so the metadata layer keeps buckets distinct but the backend does not.

BUG REPRODUCED.

Impact (security / data integrity, regression severity):
  - Cross-bucket key collisions silently overwrite content.
  - Metadata (size / etag / owner_id / content_type) for bucket A's key K
    can describe bucket B's K bytes after a collision.
  - Authenticated user with write access to a PublicRead bucket can corrupt
    a Private bucket's content sharing the same key name (when the same
    backend is used for both buckets — the default deployment).

Suggested fix (one of):
  a) Forward a composed key like `{bucket}/{key}` to the backend in every
     call site. Mirror the legacy server route's `prefixed_key` helper.
  b) Provide a per-bucket backend (currently `StorageState.backend` is one
     Arc<StorageBackend>) so backend-level isolation matches metadata-level
     isolation.
  c) For S3-family backends, use a distinct backend bucket per logical
     bucket; for local, scope each logical bucket to a distinct subdirectory.

Workaround for docs (Phase 03):
  - Page MUST warn that bucket names in the modern routes do NOT translate
    to backend prefixes; deployments using a single backend bucket for
    multiple logical buckets are vulnerable to cross-bucket key-name
    collisions.
  - Page SHOULD recommend either (a) one logical bucket per backend bucket,
    or (b) including the bucket name as a prefix in every client-side key.
MSG
exit 1
