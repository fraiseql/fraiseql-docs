# Container verification template — `<page-slug>`

Used to author a new `scripts/docs-test/pages/<page-slug>.docs-test.sh`.

---

## Inputs

- **Page:** `src/content/docs/<path>.md(x)`
- **Feature(s) exercised:** `<list>`
- **DB matrix:** `<PG / MySQL / SQLite / MSSQL>`
- **Auxiliary services:** `<Redis / NATS / MinIO / Azurite / fake-GCS / ...>`
- **Feature flags required:** `<arrow / rest / observers-nats / ...>`

## Skeleton

```bash
#!/usr/bin/env bash
# Container verification for `<page-slug>`
# Verifies every documented claim against a fresh stack.
# Exits non-zero on any divergence.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PAGE_SLUG="<page-slug>"
PROFILES="postgres"   # adjust: postgres,mysql,sqlite,mssql,redis,nats,minio,azurite,fake-gcs

cleanup() {
  cd "$ROOT"
  docker compose -f docker-compose.docs-test.yml --profile "$PROFILES" down -v --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

cd "$ROOT"

# 1. Fresh stack
docker compose -f docker-compose.docs-test.yml --profile "$PROFILES" up -d --wait

# 2. Apply the documented setup steps verbatim (the "what the reader does")
#    Each step must reproduce a snippet from the page. Do not abbreviate.
#    If a step does not appear on the page, do not run it here.

# Example: apply schema
docker compose exec -T postgres psql -U fraiseql -d fraiseql_docs \
  < fixtures/postgres/<page-slug>.sql

# Example: install config overlay
cp configs/overlays/<page-slug>.toml /tmp/fraiseql.toml
docker cp /tmp/fraiseql.toml fraiseql-server:/etc/fraiseql/fraiseql.toml

# Example: restart server with new config
docker compose restart fraiseql

# Wait for /health
for i in {1..30}; do
  if curl -fsS http://localhost:8080/health >/dev/null 2>&1; then break; fi
  sleep 1
done
curl -fsS http://localhost:8080/health >/dev/null

# 3. Reproduce documented claims (one assertion per documented claim)

# Claim A: documented query returns documented shape
RESP="$(curl -fsS -X POST http://localhost:8080/graphql \
  -H 'Content-Type: application/json' \
  -d '{"query":"<exact query from page>"}')"
echo "$RESP" | jq -e '<exact assertion on shape>' >/dev/null \
  || { echo "FAIL: claim A diverged"; echo "$RESP"; exit 1; }

# Claim B: documented error path produces documented error
RESP="$(curl -sS -X POST http://localhost:8080/graphql \
  -H 'Content-Type: application/json' \
  -d '{"query":"<intentionally broken query>"}')"
echo "$RESP" | jq -e '.errors[0].message == "<exact documented error>"' >/dev/null \
  || { echo "FAIL: claim B diverged"; echo "$RESP"; exit 1; }

# 4. Optional: behavioural checks the page implies (RLS, tenant isolation, etc.)

echo "PASS: <page-slug>"
```

## Authoring rules

1. **One assertion per documented claim.** If the page says "this returns `{x, y, z}`", the script asserts exactly that.
2. **Exact-string matching for error messages.** Substring matching hides regressions.
3. **No `|| true` swallowing.** Failures must propagate.
4. **No silent-skip on DB unavailability.** If MSSQL won't boot, the test fails — the operator has to fix the environment, not the test.
5. **The script is the page's regression test.** When the page changes, this script changes too.
6. **Run against `~/code/fraiseql` at the frozen SHA.** No mocks, no stubs, no pinning to a different SHA. The frozen SHA is in `scripts/docs-test/FRAISEQL_SHA` (set in phase 00).
7. **CI is the only GREEN gate.** The Writer persona may iterate locally but cannot declare the cycle GREEN until this script has passed in CI on a fresh runner (`methodology.md § 6.1`). The Reviewer persona re-runs the script from a clean clone — not from the Writer's CI artifacts.

## CI integration

Each `*.docs-test.sh` is invoked by the CI workflow under `.github/workflows/docs-test.yml`:

```yaml
- name: Docs page reproductions
  run: |
    cd scripts/docs-test
    for f in pages/*.docs-test.sh; do
      echo "=== $f ==="
      bash "$f"
    done
```

A page that lacks a passing reproduction script cannot ship.

---

*Template — delete in phase 10.*
