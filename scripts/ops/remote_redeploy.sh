#!/usr/bin/env bash
set -euo pipefail

REMOTE_ROOT="${1:-/opt/wukongim-prod/src/deploy/production}"
ENV_FILE="${REMOTE_ROOT}/.env"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
BACKUP_DIR="${REMOTE_ROOT}/backups/releases"
RELEASE_BASE_URL="${RELEASE_BASE_URL:-}"
ALLOW_HTTP_RELEASE_PROBES="${ALLOW_HTTP_RELEASE_PROBES:-0}"

resolve_release_base_url() {
  if [[ -n "${RELEASE_BASE_URL}" ]]; then
    printf '%s\n' "${RELEASE_BASE_URL%/}"
    return 0
  fi

  local env_base_url=""
  env_base_url="$(grep -E '^TSDD_BASE_URL=' "${ENV_FILE}" 2>/dev/null | tail -1 | cut -d= -f2- || true)"
  if [[ -n "${env_base_url}" ]]; then
    printf '%s\n' "${env_base_url%/}"
    return 0
  fi

  printf '%s\n' 'https://infoequity.qingyunshe.top'
}

assert_release_base_url_safe() {
  local base_url="$1"
  if [[ "${base_url}" == http://* && "${ALLOW_HTTP_RELEASE_PROBES}" != "1" ]]; then
    cat >&2 <<EOF
Refusing production release probes over HTTP: ${base_url}
Use RELEASE_BASE_URL=https://infoequity.qingyunshe.top or set ALLOW_HTTP_RELEASE_PROBES=1 only for an explicit local-only diagnostic.
EOF
    return 1
  fi
}

: "${BUILD_VERSION:?BUILD_VERSION is required}"
: "${BUILD_COMMIT:?BUILD_COMMIT is required}"
: "${BUILD_COMMIT_DATE:?BUILD_COMMIT_DATE is required}"
: "${BUILD_TREE_STATE:?BUILD_TREE_STATE is required}"

wait_for_health() {
  local service="$1"
  local timeout="${2:-180}"
  local elapsed=0
  local container_id=""
  local health_status=""

  container_id="$(docker compose --env-file .env ps -q "${service}")"
  if [[ -z "${container_id}" ]]; then
    echo "Service '${service}' has no running container ID after compose up." >&2
    return 1
  fi

  while (( elapsed < timeout )); do
    health_status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${container_id}")"
    if [[ "${health_status}" == "healthy" || "${health_status}" == "none" ]]; then
      return 0
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done

  echo "Timed out waiting for '${service}' health. Last status: ${health_status}" >&2
  docker compose --env-file .env ps
  return 1
}

cd "${REMOTE_ROOT}"
test -f "${ENV_FILE}"
mkdir -p "${BACKUP_DIR}"

cp "${ENV_FILE}" "${BACKUP_DIR}/.env.before-${TIMESTAMP}"
grep '^BUILD_' "${ENV_FILE}" > "${BACKUP_DIR}/build-before-${TIMESTAMP}.env" || true

echo "== preflight =="
docker compose --env-file .env ps
grep '^BUILD_' .env

echo "== build =="
docker compose --env-file .env build tsdd-api callgateway

echo "== rollout =="
docker compose --env-file .env up -d --no-deps tsdd-api callgateway
wait_for_health tsdd-api 180
wait_for_health callgateway 180

RELEASE_BASE_URL="$(resolve_release_base_url)"
assert_release_base_url_safe "${RELEASE_BASE_URL}"

echo "== smoke (${RELEASE_BASE_URL}) =="
python3 scripts/smoke_test.py --base-url "${RELEASE_BASE_URL}" --timeout 10

echo "== perf (${RELEASE_BASE_URL}) =="
python3 scripts/perf_probe.py --base-url "${RELEASE_BASE_URL}" --samples 20 --timeout 10

python3 - "${ENV_FILE}" <<'PY'
import os
import sys
from pathlib import Path

path = Path(sys.argv[1])
updates = {
    "BUILD_VERSION": os.environ["BUILD_VERSION"],
    "BUILD_COMMIT": os.environ["BUILD_COMMIT"],
    "BUILD_COMMIT_DATE": os.environ["BUILD_COMMIT_DATE"],
    "BUILD_TREE_STATE": os.environ["BUILD_TREE_STATE"],
}

lines = path.read_text(encoding="utf-8").splitlines()
seen = set()
rewritten = []

for line in lines:
    stripped = line.strip()
    if not stripped or stripped.startswith("#") or "=" not in line:
        rewritten.append(line)
        continue

    key, _ = line.split("=", 1)
    key = key.strip()
    if key in updates:
        rewritten.append(f"{key}={updates[key]}")
        seen.add(key)
    else:
        rewritten.append(line)

for key, value in updates.items():
    if key not in seen:
        rewritten.append(f"{key}={value}")

path.write_text("\n".join(rewritten) + "\n", encoding="utf-8")
PY

echo "== final status =="
docker compose --env-file .env ps
grep '^BUILD_' .env
echo "Rollback .env backup: ${BACKUP_DIR}/.env.before-${TIMESTAMP}"
