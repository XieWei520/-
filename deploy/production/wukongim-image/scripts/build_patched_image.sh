#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${IMAGE_DIR}/upstream.env"

BUILD_ROOT="${WUKONGIM_BUILD_ROOT:-/home/ubuntu/wukongim-build-src}"
PATCH_FILE="${IMAGE_DIR}/patches/0001-redact-connect-token-logs.patch"
VERIFY_SCRIPT="${IMAGE_DIR}/scripts/verify_patch_static.py"

log() { printf '[wukongim-image] %s\n' "$*"; }

if [[ ! -f "${PATCH_FILE}" ]]; then
  log "error: missing patch file: ${PATCH_FILE}" >&2
  exit 2
fi

if [[ ! -f "${VERIFY_SCRIPT}" ]]; then
  log "error: missing verifier: ${VERIFY_SCRIPT}" >&2
  exit 2
fi

if [[ -d "${BUILD_ROOT}/.git" ]]; then
  log "Fetching upstream source in ${BUILD_ROOT}"
  git -C "${BUILD_ROOT}" fetch --tags --prune origin
elif [[ -e "${BUILD_ROOT}" || -L "${BUILD_ROOT}" ]]; then
  log "error: build root exists but is not a git checkout: ${BUILD_ROOT}" >&2
  log "Move it aside or set WUKONGIM_BUILD_ROOT to an empty path." >&2
  exit 2
else
  log "Cloning upstream source into ${BUILD_ROOT}"
  git clone "${WUKONGIM_UPSTREAM_REPO}" "${BUILD_ROOT}"
fi

log "Checking out upstream commit ${WUKONGIM_UPSTREAM_COMMIT}"
git -C "${BUILD_ROOT}" checkout --detach "${WUKONGIM_UPSTREAM_COMMIT}"
git -C "${BUILD_ROOT}" reset --hard "${WUKONGIM_UPSTREAM_COMMIT}"

log "Applying token redaction patch"
git -C "${BUILD_ROOT}" apply "${PATCH_FILE}"

log "Running static patch verifier"
python3 "${VERIFY_SCRIPT}" "${BUILD_ROOT}"

log "Building Docker image ${WUKONGIM_PATCHED_IMAGE}"
docker build -t "${WUKONGIM_PATCHED_IMAGE}" "${BUILD_ROOT}"
docker image inspect --format 'id={{.Id}} created={{.Created}} size={{.Size}}' "${WUKONGIM_PATCHED_IMAGE}"

log "Built image: ${WUKONGIM_PATCHED_IMAGE}"
