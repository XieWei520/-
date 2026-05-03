#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${IMAGE_DIR}/upstream.env"

BUILD_ROOT="${WUKONGIM_BUILD_ROOT:-/home/ubuntu/wukongim-build-src}"
PATCH_FILE="${IMAGE_DIR}/patches/0001-redact-connect-token-logs.patch"
VERIFY_SCRIPT="${IMAGE_DIR}/scripts/verify_patch_static.py"
BINARY_DOCKERFILE="${WUKONGIM_BINARY_DOCKERFILE:-${IMAGE_DIR}/Dockerfile.patched-binary}"

log() { printf '[wukongim-image] %s\n' "$*"; }

if [[ ! -f "${PATCH_FILE}" ]]; then
  log "error: missing patch file: ${PATCH_FILE}" >&2
  exit 2
fi

if [[ ! -f "${VERIFY_SCRIPT}" ]]; then
  log "error: missing verifier: ${VERIFY_SCRIPT}" >&2
  exit 2
fi

if [[ ! -f "${BINARY_DOCKERFILE}" ]]; then
  log "error: missing binary Dockerfile: ${BINARY_DOCKERFILE}" >&2
  exit 2
fi

preserve_go_embed_assets_in_docker_context() {
  local dockerignore="${BUILD_ROOT}/.dockerignore"
  local tmp_dockerignore

  if [[ ! -d "${BUILD_ROOT}/web/dist" ]]; then
    log "error: ${BUILD_ROOT}/web/dist is required for Go embed; use the pinned full source snapshot with generated web assets." >&2
    exit 2
  fi

  if [[ -f "${dockerignore}" ]] && grep -Eq '^[[:space:]]*web/dist[[:space:]]*$' "${dockerignore}"; then
    log "Allowing web/dist into Docker context so Go embed files are available"
    cp "${dockerignore}" "${dockerignore}.wukongim-build.bak"
    tmp_dockerignore="$(mktemp "${dockerignore}.XXXXXX")"
    grep -Ev '^[[:space:]]*web/dist[[:space:]]*$' "${dockerignore}" > "${tmp_dockerignore}"
    mv "${tmp_dockerignore}" "${dockerignore}"
  fi
}

if [[ -d "${BUILD_ROOT}/.git" ]]; then
  if [[ "${WUKONGIM_SKIP_FETCH:-0}" == "1" ]]; then
    log "Skipping upstream fetch because WUKONGIM_SKIP_FETCH=1"
  else
    log "Fetching upstream source in ${BUILD_ROOT}"
    git -C "${BUILD_ROOT}" fetch --tags --prune origin
  fi
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

log "Cleaning upstream checkout"
git -C "${BUILD_ROOT}" clean -ffdx

log "Applying token redaction patch"
git -C "${BUILD_ROOT}" apply --unidiff-zero "${PATCH_FILE}"

log "Running static patch verifier"
python3 "${VERIFY_SCRIPT}" "${BUILD_ROOT}"

preserve_go_embed_assets_in_docker_context

log "Building Docker image ${WUKONGIM_PATCHED_IMAGE}"
docker build -f "${BINARY_DOCKERFILE}" \
  --build-arg "WUKONGIM_VERSION_FALLBACK=${WUKONGIM_BASE_VERSION}" \
  -t "${WUKONGIM_PATCHED_IMAGE}" \
  "${BUILD_ROOT}"
docker image inspect --format 'id={{.Id}} created={{.Created}} size={{.Size}}' "${WUKONGIM_PATCHED_IMAGE}"

log "Built image: ${WUKONGIM_PATCHED_IMAGE}"
