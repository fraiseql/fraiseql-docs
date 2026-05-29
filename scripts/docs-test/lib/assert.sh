#!/usr/bin/env bash
#
# assert.sh — assertion helpers for `pages/*.docs-test.sh` and `pages/_smoke.docs-test.sh`.
#
# Four helpers, each loud-but-terse on success (one line per assertion) and
# loud-with-a-copy-pasteable-diff on failure (non-zero exit, both observed
# and expected printed so the operator can reproduce by hand).
#
# Usage:
#   # shellcheck source=lib/assert.sh
#   . "$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)/lib/assert.sh"
#
#   assert_http_2xx "GET http://localhost:8080/health" "$status_code"
#   assert_json_shape "$response_body" '.data.posts | length == 0'
#   assert_eq "users.count" "$observed" "0"
#   assert_contains "$response_body" '"posts"'
#
# Conventions (so output is uniform across pages):
#   - Each helper takes a `label` as its first argument (except `assert_json_shape`
#     where the jq filter doubles as the label). The label is what shows up on
#     the success / failure line, so make it descriptive.
#   - On success: prints `  ✓ <label>` to stdout and returns 0.
#   - On failure: prints `  ✗ <label>` plus a diff block to stderr and exits the
#     calling shell with status 1 (via `return 1` so `set -e` callers honour it).
#   - All helpers are idempotent and side-effect-free.
#
# Dependencies (must be on PATH inside the caller — the smoke runs on the host,
# not inside a container, so the host needs these):
#   - jq          (for assert_json_shape)
#   - GNU diff    (for the diff block on string mismatches)
#
# source: _internal/.plan/.phases/phase-00-foundation.md (cycle 5 REFACTOR step)

# Guard against double-sourcing.
if [ "${_FRAISEQL_DOCS_ASSERT_SH_LOADED:-0}" = "1" ]; then
    return 0 2>/dev/null
fi
_FRAISEQL_DOCS_ASSERT_SH_LOADED=1

# ---------------------------------------------------------------------------
# Internal — print a copy-pasteable diff block when an assertion fails.
# ---------------------------------------------------------------------------
_assert_diff() {
    local label="$1" observed="$2" expected="$3"
    {
        printf '  ✗ %s\n' "$label"
        printf '    observed: %s\n' "$observed"
        printf '    expected: %s\n' "$expected"
        if command -v diff >/dev/null 2>&1; then
            printf '    diff (observed → expected):\n'
            diff <(printf '%s\n' "$observed") <(printf '%s\n' "$expected") \
                | sed 's/^/      /'
        fi
    } >&2
}

# ---------------------------------------------------------------------------
# assert_http_2xx — assert an HTTP status code is in [200,300).
#
# Args:
#   $1 — label (descriptive, e.g. "GET /health")
#   $2 — observed HTTP status code (integer string)
#
# Example:
#   status=$(curl -sS -o /dev/null -w '%{http_code}' http://localhost:8080/health)
#   assert_http_2xx "GET /health" "$status"
# ---------------------------------------------------------------------------
assert_http_2xx() {
    local label="$1" code="$2"
    if [ -z "$code" ]; then
        {
            printf '  ✗ %s\n' "$label"
            printf '    observed: <empty>\n'
            printf '    expected: HTTP 2xx\n'
        } >&2
        return 1
    fi
    if [ "$code" -ge 200 ] && [ "$code" -lt 300 ] 2>/dev/null; then
        printf '  ✓ %s (HTTP %s)\n' "$label" "$code"
        return 0
    fi
    _assert_diff "$label" "HTTP $code" "HTTP 2xx"
    return 1
}

# ---------------------------------------------------------------------------
# assert_json_shape — assert that a `jq -e` filter holds against a JSON blob.
#
# Args:
#   $1 — JSON string (the response body)
#   $2 — jq filter, must evaluate to a truthy value (use `==`, `length > 0`, etc.)
#   $3 — (optional) label override; defaults to the filter itself.
#
# Example:
#   assert_json_shape "$body" '.data.posts | type == "array"'
#   assert_json_shape "$body" '.data.users | length == 3' "users seed count"
#
# Uses `jq -e` which exits non-zero when the filter produces `false` or `null`.
# Captures the filter's stdout for the failure-mode diff so the operator can
# see what `jq` actually returned.
# ---------------------------------------------------------------------------
assert_json_shape() {
    local body="$1" filter="$2" label="${3:-$2}"
    if ! command -v jq >/dev/null 2>&1; then
        printf '  ✗ %s — jq not on PATH\n' "$label" >&2
        return 1
    fi
    local result
    if result=$(printf '%s' "$body" | jq -e "$filter" 2>&1); then
        printf '  ✓ %s\n' "$label"
        return 0
    fi
    {
        printf '  ✗ %s\n' "$label"
        printf '    filter:   %s\n' "$filter"
        printf '    jq says:  %s\n' "$result"
        printf '    body:     %s\n' "$body"
    } >&2
    return 1
}

# ---------------------------------------------------------------------------
# assert_eq — assert two strings are equal.
#
# Args:
#   $1 — label
#   $2 — observed value
#   $3 — expected value
#
# Example:
#   assert_eq "schema_hash" "$hash" "316c9100f7a872c8c411033ac2a00066"
# ---------------------------------------------------------------------------
assert_eq() {
    local label="$1" observed="$2" expected="$3"
    if [ "$observed" = "$expected" ]; then
        printf '  ✓ %s (= %s)\n' "$label" "$expected"
        return 0
    fi
    _assert_diff "$label" "$observed" "$expected"
    return 1
}

# ---------------------------------------------------------------------------
# assert_contains — assert that <haystack> contains <needle> as a substring.
#
# Args:
#   $1 — label
#   $2 — haystack
#   $3 — needle
#
# Example:
#   assert_contains "version header" "$resp" '"version":"2.3'
# ---------------------------------------------------------------------------
assert_contains() {
    local label="$1" haystack="$2" needle="$3"
    case "$haystack" in
        *"$needle"*)
            printf '  ✓ %s (contains %s)\n' "$label" "$needle"
            return 0
            ;;
    esac
    {
        printf '  ✗ %s\n' "$label"
        printf '    haystack: %s\n' "$haystack"
        printf '    needle:   %s\n' "$needle"
    } >&2
    return 1
}
