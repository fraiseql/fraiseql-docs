#!/usr/bin/env bash
#
# storage-smoke.sh — direct-client smoke check for the Cycle 3 storage sidecars.
#
# Exercises a 1 KB write + read + listing per backend using each backend's
# native client tool (mc for MinIO, az for Azurite, curl for fake-gcs-server).
# This is NOT the Cycle 5 smoke — that one drives the FraiseQL server.
# This helper just proves the sidecar infrastructure is wired correctly and
# the pre-created bucket / container `fraiseql-docs-test` is reachable.
#
# Usage:
#   scripts/docs-test/lib/storage-smoke.sh                 # all three backends
#   scripts/docs-test/lib/storage-smoke.sh minio           # one only
#   scripts/docs-test/lib/storage-smoke.sh minio azurite   # subset
#
# The Cycle 4 operator CLI (docs-test.sh) will invoke this. Cycle 5's full
# smoke test will invoke it after `up --profile storage` to assert the
# sidecar pre-condition before the FraiseQL-side checks.
#
# Exit codes:
#   0  — every requested backend passed write + read + match.
#   1  — at least one backend failed; stderr names which step failed.
#   2  — bad usage (unknown backend name).
#
# Assumes the Compose stack is already up via:
#   docker compose -f scripts/docs-test/docker-compose.docs-test.yml \
#     --profile storage up -d --wait --wait-timeout 180
#
# The helper does NOT bring services up or down; it is a read/write probe.

set -euo pipefail

# ---------------------------------------------------------------------------
# Paths and constants. All paths are relative to the docs-test repo root so
# the helper is callable from any CWD as long as it can resolve its own dir.
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_TEST_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${DOCS_TEST_DIR}/docker-compose.docs-test.yml"

BUCKET="fraiseql-docs-test"
KEY="cycle-03-smoke.bin"
# 1 KB payload (1024 bytes of pseudo-random data, base64 = 1368 chars).
# Encoded inline to avoid filesystem deps; decoded into a per-run tmpfile.
PAYLOAD_SIZE=1024

WORKDIR=""
RC=0

# ---------------------------------------------------------------------------
# Logging helpers — write to stderr so stdout stays clean for transcript use.
# ---------------------------------------------------------------------------
log() { printf '[%s] %s\n' "$(date -u +%H:%M:%SZ)" "$*" >&2; }
err() { printf '[%s] ERROR: %s\n' "$(date -u +%H:%M:%SZ)" "$*" >&2; }

# ---------------------------------------------------------------------------
# Setup / teardown.
# ---------------------------------------------------------------------------
setup() {
  WORKDIR="$(mktemp -d -t fraiseql-docs-storage-smoke.XXXXXX)"
  # Generate a deterministic 1 KB payload so the comparison is stable.
  head -c "${PAYLOAD_SIZE}" /dev/urandom > "${WORKDIR}/payload.bin"
  log "workdir=${WORKDIR} payload=$(wc -c < "${WORKDIR}/payload.bin") bytes"
}

cleanup() {
  if [[ -n "${WORKDIR}" && -d "${WORKDIR}" ]]; then
    rm -rf "${WORKDIR}"
  fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# compare_files — assert two files have identical contents.
# ---------------------------------------------------------------------------
compare_files() {
  local expected="$1" actual="$2" label="$3"
  if [[ ! -f "${actual}" ]]; then
    err "${label}: downloaded file missing (${actual})"
    return 1
  fi
  if cmp -s "${expected}" "${actual}"; then
    log "${label}: payload roundtrip OK (${PAYLOAD_SIZE} bytes match)"
    return 0
  else
    err "${label}: payload mismatch"
    err "  expected sha256: $(sha256sum "${expected}" | awk '{print $1}')"
    err "  actual   sha256: $(sha256sum "${actual}"   | awk '{print $1}')"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# fresh_download_target — remove any stale downloaded.bin between backends
# so a successful prior run doesn't mask a current-backend failure.
# ---------------------------------------------------------------------------
fresh_download_target() {
  rm -f "${WORKDIR}/downloaded.bin"
}

# ---------------------------------------------------------------------------
# MinIO — uses `mc` from the running `minio-init` recipe, but invoked here
# via `docker compose run --rm minio-init` so we hit the same image / network.
# Operations:
#   - cp payload → local/fraiseql-docs-test/cycle-03-smoke.bin
#   - ls local/fraiseql-docs-test (must contain the key)
#   - cp it back → compare bytes
# ---------------------------------------------------------------------------
smoke_minio() {
  log "=== MinIO smoke ==="
  fresh_download_target
  local mc_args=(
    --rm
    -v "${WORKDIR}:/work"
    --entrypoint /bin/sh
    minio-init
  )
  docker compose -f "${COMPOSE_FILE}" run "${mc_args[@]}" -eu -c "
    mc alias set --quiet local http://minio:9000 \$MINIO_ROOT_USER \$MINIO_ROOT_PASSWORD
    mc cp /work/payload.bin local/${BUCKET}/${KEY}
    mc ls local/${BUCKET}/${KEY}
    mc cp local/${BUCKET}/${KEY} /work/downloaded.bin
  " >&2
  compare_files "${WORKDIR}/payload.bin" "${WORKDIR}/downloaded.bin" "MinIO"
}

# ---------------------------------------------------------------------------
# Azurite — uses `az storage blob` via the `azurite-init` service container.
# ---------------------------------------------------------------------------
smoke_azurite() {
  log "=== Azurite smoke ==="
  fresh_download_target
  docker compose -f "${COMPOSE_FILE}" run \
    --rm \
    -v "${WORKDIR}:/work" \
    --entrypoint /bin/sh \
    azurite-init \
    -eu -c "
      az storage blob upload --container-name ${BUCKET} --name ${KEY} \
        --file /work/payload.bin --overwrite --only-show-errors
      az storage blob list --container-name ${BUCKET} --query '[].name' --only-show-errors
      az storage blob download --container-name ${BUCKET} --name ${KEY} \
        --file /work/downloaded.bin --only-show-errors >/dev/null
    " >&2
  compare_files "${WORKDIR}/payload.bin" "${WORKDIR}/downloaded.bin" "Azurite"
}

# ---------------------------------------------------------------------------
# fake-gcs — there's no canonical gcs CLI in our stack; we use curl against
# the well-documented JSON API. Object upload uses the resumable-upload
# convenience endpoint `/upload/storage/v1/b/<bucket>/o?uploadType=media&name=<key>`.
# ---------------------------------------------------------------------------
smoke_fake_gcs() {
  log "=== fake-gcs-server smoke ==="
  fresh_download_target
  # fake-gcs has no official CLI; we drive it via the documented JSON API
  # using curl. We borrow the `azurite-init` service because the
  # azure-cli base image ships curl (the `minio/mc` and `fake-gcs` images
  # do not) and is already pulled by `--profile storage`. The container
  # is on the same Compose network so the `fake-gcs:4443` hostname
  # resolves.
  docker compose -f "${COMPOSE_FILE}" run \
    --rm \
    -v "${WORKDIR}:/work" \
    --entrypoint /bin/sh \
    azurite-init \
    -eu -c "
      # Upload via media upload (binary body in POST).
      curl --fail-with-body -sS \
        -X POST \
        -H 'Content-Type: application/octet-stream' \
        --data-binary @/work/payload.bin \
        'http://fake-gcs:4443/upload/storage/v1/b/${BUCKET}/o?uploadType=media&name=${KEY}'
      echo
      # List to confirm the object exists.
      curl --fail-with-body -sS 'http://fake-gcs:4443/storage/v1/b/${BUCKET}/o' | head -c 400
      echo
      # Download (alt=media returns the raw object body).
      curl --fail-with-body -sS \
        -o /work/downloaded.bin \
        'http://fake-gcs:4443/storage/v1/b/${BUCKET}/o/${KEY}?alt=media'
    " >&2
  compare_files "${WORKDIR}/payload.bin" "${WORKDIR}/downloaded.bin" "fake-gcs"
}

# ---------------------------------------------------------------------------
# Argument parsing.
# ---------------------------------------------------------------------------
backends=()
if [[ $# -eq 0 ]]; then
  backends=(minio azurite fake-gcs)
else
  for arg in "$@"; do
    case "${arg}" in
      minio|azurite|fake-gcs) backends+=("${arg}") ;;
      *)
        err "unknown backend '${arg}' (expected: minio | azurite | fake-gcs)"
        exit 2
        ;;
    esac
  done
fi

# ---------------------------------------------------------------------------
# Run.
# ---------------------------------------------------------------------------
setup

for b in "${backends[@]}"; do
  case "${b}" in
    minio)    if ! smoke_minio;    then RC=1; fi ;;
    azurite)  if ! smoke_azurite;  then RC=1; fi ;;
    fake-gcs) if ! smoke_fake_gcs; then RC=1; fi ;;
  esac
done

if [[ "${RC}" -eq 0 ]]; then
  log "ALL OK — ${#backends[@]} backend(s) passed"
else
  err "FAILURES — see stderr above"
fi

exit "${RC}"
