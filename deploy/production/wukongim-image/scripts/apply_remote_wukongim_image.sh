#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROD_ROOT="$(cd "${IMAGE_DIR}/../.." && pwd)"
source "${IMAGE_DIR}/upstream.env"

COMPOSE_FILE="${PROD_ROOT}/docker-compose.yaml"
STAMP="$(date +%Y%m%d%H%M%S)"
BACKUP_DIR="/home/ubuntu/wukong-deploy-backups/wukongim-token-redaction-${STAMP}"

log() { printf '[wukongim-apply] %s\n' "$*"; }

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
script_files=("${PROD_ROOT}"/scripts/*.py)
if ((${#config_templates[@]})); then
  cp "${config_templates[@]}" "${BACKUP_DIR}/config/"
fi
if ((${#script_files[@]})); then
  cp "${script_files[@]}" "${BACKUP_DIR}/scripts/"
fi
shopt -u nullglob

cp -R "${IMAGE_DIR}/." "${BACKUP_DIR}/wukongim-image/"

log "Updating wukongim image in ${COMPOSE_FILE}"
python3 - "${COMPOSE_FILE}" "${WUKONGIM_PATCHED_IMAGE}" <<'PY'
from pathlib import Path
import re
import sys

compose_path = Path(sys.argv[1])
patched_image = sys.argv[2]
text = compose_path.read_text(encoding="utf-8")
lines = text.splitlines(keepends=True)
new_lines = []

in_services = False
services_indent = None
in_wukongim = False
wukongim_indent = None
replacement_count = 0

for line in lines:
    line_body = line.rstrip("\r\n")
    newline = line[len(line_body):]
    stripped = line_body.strip()
    indent = len(line_body) - len(line_body.lstrip(" "))

    if stripped and not stripped.startswith("#"):
        if in_services and services_indent is not None and indent <= services_indent and not re.match(r"^\s*services\s*:\s*(?:#.*)?$", line_body):
            in_services = False
            in_wukongim = False
            wukongim_indent = None

        if re.match(r"^\s*services\s*:\s*(?:#.*)?$", line_body):
            in_services = True
            services_indent = indent
            in_wukongim = False
            wukongim_indent = None
        elif in_services:
            if in_wukongim and wukongim_indent is not None and indent <= wukongim_indent:
                in_wukongim = False
                wukongim_indent = None

            if re.match(r"^\s*wukongim\s*:\s*(?:#.*)?$", line_body):
                in_wukongim = True
                wukongim_indent = indent
            elif in_wukongim and re.match(r"^\s*image\s*:", line_body):
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
  docker compose --env-file .env config >/tmp/wukongim-token-redaction-compose.yaml
  docker compose --env-file .env up -d --no-deps wukongim
)

echo "BACKUP_DIR=${BACKUP_DIR}"
echo "PATCHED_IMAGE=${WUKONGIM_PATCHED_IMAGE}"
