#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROD_ROOT_SOURCE="${WUKONGIM_PROD_ROOT:-${IMAGE_DIR}/..}"
PROD_ROOT="$(cd "${PROD_ROOT_SOURCE}" && pwd)"
source "${IMAGE_DIR}/upstream.env"

COMPOSE_FILE="${PROD_ROOT}/docker-compose.yaml"
STAMP="$(date +%Y%m%d%H%M%S)"
BACKUP_DIR="/home/ubuntu/wukong-deploy-backups/wukongim-token-redaction-${STAMP}"
COMPOSE_MUTATED=0

log() { printf '[wukongim-apply] %s\n' "$*"; }

restore_compose_on_error() {
  local exit_code=$?
  if [[ "${COMPOSE_MUTATED}" == "1" ]]; then
    trap - ERR
    log "error: validation or restart failed; restoring ${COMPOSE_FILE} from ${BACKUP_DIR}/docker-compose.yaml" >&2
    if cp "${BACKUP_DIR}/docker-compose.yaml" "${COMPOSE_FILE}"; then
      log "Attempting best-effort rollback restart for wukongim from restored compose" >&2
      if ! (
        cd "${PROD_ROOT}"
        docker compose --env-file .env up -d --no-deps wukongim
      ); then
        log "warning: best-effort rollback restart failed; backup remains at ${BACKUP_DIR}" >&2
      fi
    else
      log "error: failed to restore ${COMPOSE_FILE}; backup remains at ${BACKUP_DIR}" >&2
    fi
  fi
  exit "${exit_code}"
}

trap restore_compose_on_error ERR

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  log "error: missing compose file: ${COMPOSE_FILE}" >&2
  exit 2
fi

log "Checking patched image exists: ${WUKONGIM_PATCHED_IMAGE}"
docker image inspect "${WUKONGIM_PATCHED_IMAGE}" >/dev/null

log "Creating deployment backup at ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/config" "${BACKUP_DIR}/scripts" "${BACKUP_DIR}/wukongim-image"
cp "${COMPOSE_FILE}" "${BACKUP_DIR}/docker-compose.yaml"

if [[ -f "${PROD_ROOT}/.env.example" ]]; then
  cp "${PROD_ROOT}/.env.example" "${BACKUP_DIR}/.env.example"
fi

shopt -s nullglob
config_templates=("${PROD_ROOT}"/config/*.tpl)
script_files=("${PROD_ROOT}"/scripts/*.py "${PROD_ROOT}"/scripts/*.sh)
if ((${#config_templates[@]})); then
  cp "${config_templates[@]}" "${BACKUP_DIR}/config/"
fi
if ((${#script_files[@]})); then
  cp "${script_files[@]}" "${BACKUP_DIR}/scripts/"
fi
shopt -u nullglob

cp -R "${IMAGE_DIR}/." "${BACKUP_DIR}/wukongim-image/"

log "Updating wukongim image in ${COMPOSE_FILE}"
COMPOSE_MUTATED=1
python3 - "${COMPOSE_FILE}" "${WUKONGIM_PATCHED_IMAGE}" <<'PY'
from pathlib import Path
import re
import sys

compose_path = Path(sys.argv[1])
patched_image = sys.argv[2]
text = compose_path.read_text(encoding="utf-8")
lines = text.splitlines(keepends=True)
new_lines = []

services_re = re.compile(r"^\s*services\s*:\s*(?:#.*)?$")
key_re = re.compile(r"^\s*([A-Za-z0-9_.-]+)\s*:")

in_services = False
services_indent = None
service_indent = None
in_wukongim = False
wukongim_indent = None
wukongim_child_indent = None
replacement_count = 0

for line in lines:
    line_body = line.rstrip("\r\n")
    newline = line[len(line_body):]
    stripped = line_body.strip()
    indent = len(line_body) - len(line_body.lstrip(" "))

    if stripped and not stripped.startswith("#"):
        leaving_services = (
            in_services
            and services_indent is not None
            and indent <= services_indent
            and not services_re.match(line_body)
        )
        if leaving_services:
            in_services = False
            services_indent = None
            service_indent = None
            in_wukongim = False
            wukongim_indent = None
            wukongim_child_indent = None

        if services_re.match(line_body):
            in_services = True
            services_indent = indent
            service_indent = None
            in_wukongim = False
            wukongim_indent = None
            wukongim_child_indent = None
        elif in_services:
            key_match = key_re.match(line_body)
            if key_match:
                key = key_match.group(1)

                if service_indent is None and indent > services_indent:
                    service_indent = indent

                if service_indent is not None and indent == service_indent:
                    in_wukongim = key == "wukongim"
                    wukongim_indent = indent if in_wukongim else None
                    wukongim_child_indent = None
                elif in_wukongim:
                    if wukongim_indent is not None and indent <= wukongim_indent:
                        in_wukongim = False
                        wukongim_indent = None
                        wukongim_child_indent = None
                    else:
                        if wukongim_child_indent is None:
                            wukongim_child_indent = indent

                        if indent == wukongim_child_indent and key == "image":
                            leading = line_body[:indent]
                            line = f"{leading}image: {patched_image}{newline}"
                            replacement_count += 1

    new_lines.append(line)

if replacement_count != 1:
    print("error: could not replace wukongim image", file=sys.stderr)
    sys.exit(1)

compose_path.write_text("".join(new_lines), encoding="utf-8")
PY

log "Validating compose configuration"
(
  cd "${PROD_ROOT}"
  docker compose --env-file .env config >/dev/null
  docker compose --env-file .env up -d --no-deps wukongim
)
COMPOSE_MUTATED=0
trap - ERR

echo "BACKUP_DIR=${BACKUP_DIR}"
echo "PATCHED_IMAGE=${WUKONGIM_PATCHED_IMAGE}"
