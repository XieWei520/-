#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROD_ROOT_SOURCE="${WUKONGIM_PROD_ROOT:-${IMAGE_DIR}/..}"
PROD_ROOT="$(cd "${PROD_ROOT_SOURCE}" && pwd)"
source "${IMAGE_DIR}/upstream.env"

COMPOSE_FILE="${PROD_ROOT}/docker-compose.yaml"
ENV_FILE="${PROD_ROOT}/.env"
STAMP="$(date +%Y%m%d%H%M%S)"
BACKUP_PARENT="/home/ubuntu/wukong-deploy-backups"
BACKUP_STEM="${BACKUP_PARENT}/wukongim-token-redaction-${STAMP}"
BACKUP_DIR=""
COMPOSE_MUTATED=0

log() { printf '[wukongim-apply] %s\n' "$*"; }

create_backup_dir() {
  local attempt candidate

  mkdir -p "${BACKUP_PARENT}"
  for attempt in 0 1 2 3 4 5 6 7 8 9; do
    if [[ "${attempt}" == "0" ]]; then
      candidate="${BACKUP_STEM}-$$"
    else
      candidate="${BACKUP_STEM}-$$-${attempt}"
    fi

    if mkdir "${candidate}" 2>/dev/null; then
      BACKUP_DIR="${candidate}"
      mkdir "${BACKUP_DIR}/config" "${BACKUP_DIR}/scripts" "${BACKUP_DIR}/wukongim-image"
      return 0
    fi
  done

  log "error: could not create unique backup directory under ${BACKUP_PARENT}" >&2
  return 1
}

rollback_if_needed() {
  local exit_code="${1:-$?}"

  trap - ERR EXIT INT TERM HUP
  if [[ "${COMPOSE_MUTATED}" == "1" && "${exit_code}" != "0" ]]; then
    log "error: validation or restart failed; restoring ${COMPOSE_FILE} from ${BACKUP_DIR}/docker-compose.yaml" >&2
    if cp "${BACKUP_DIR}/docker-compose.yaml" "${COMPOSE_FILE}"; then
      log "Attempting best-effort rollback restart for wukongim from restored compose" >&2
      if ! (
        cd "${PROD_ROOT}" &&
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

verify_wukongim_started() {
  local max_attempts="${WUKONGIM_START_CHECK_ATTEMPTS:-10}"
  local sleep_seconds="${WUKONGIM_START_CHECK_SLEEP_SECONDS:-3}"
  local required_observations="${WUKONGIM_START_STABLE_OBSERVATIONS:-2}"
  local attempt services service_name service_count
  local container_ids container_id container_count running_status health_status
  local all_ready stable_observations=0

  for ((attempt = 1; attempt <= max_attempts; attempt++)); do
    service_count=0
    if services="$(docker compose --env-file .env ps --status running --services wukongim)"; then
      while IFS= read -r service_name; do
        [[ -z "${service_name}" ]] && continue
        if [[ "${service_name}" == "wukongim" ]]; then
          service_count=$((service_count + 1))
        else
          service_count=-1
        fi
      done <<<"${services}"
    fi

    all_ready=0
    if [[ "${service_count}" == "1" ]]; then
      if container_ids="$(docker compose --env-file .env ps -q wukongim)"; then
        container_count=0
        all_ready=1

        while IFS= read -r container_id; do
          [[ -z "${container_id}" ]] && continue
          container_count=$((container_count + 1))

          if ! running_status="$(docker inspect --format '{{.State.Running}}' "${container_id}")"; then
            log "error: could not inspect wukongim container ${container_id}" >&2
            return 1
          fi
          if [[ "${running_status}" != "true" ]]; then
            all_ready=0
          fi

          if ! health_status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "${container_id}")"; then
            log "error: could not inspect wukongim container health ${container_id}" >&2
            return 1
          fi
          if [[ "${health_status}" == "unhealthy" ]]; then
            log "error: wukongim container ${container_id} is unhealthy" >&2
            return 1
          fi
          if [[ "${health_status}" == "starting" ]]; then
            all_ready=0
          fi
        done <<<"${container_ids}"

        if [[ "${container_count}" == "0" ]]; then
          all_ready=0
        fi
      fi
    fi

    if [[ "${all_ready}" == "1" ]]; then
      stable_observations=$((stable_observations + 1))
      if ((stable_observations >= required_observations)); then
        log "wukongim service is running"
        return 0
      fi
    else
      stable_observations=0
    fi

    if ((attempt < max_attempts)); then
      sleep "${sleep_seconds}"
    fi
  done

  log "error: wukongim service did not reach running/healthy state" >&2
  return 1
}

trap 'rollback_if_needed $?' ERR
trap 'rollback_if_needed $?' EXIT
trap 'rollback_if_needed 130' INT
trap 'rollback_if_needed 143' TERM
trap 'rollback_if_needed 129' HUP

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  log "error: missing compose file: ${COMPOSE_FILE}" >&2
  exit 2
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  log "error: missing env file: ${ENV_FILE}" >&2
  exit 2
fi

log "Checking patched image exists: ${WUKONGIM_PATCHED_IMAGE}"
docker image inspect "${WUKONGIM_PATCHED_IMAGE}" >/dev/null

create_backup_dir
log "Created deployment backup at ${BACKUP_DIR}"
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
  cd "${PROD_ROOT}" &&
    docker compose --env-file .env config >/dev/null &&
    docker compose --env-file .env up -d --no-deps wukongim &&
    verify_wukongim_started
)
COMPOSE_MUTATED=0
trap - ERR EXIT INT TERM HUP

echo "BACKUP_DIR=${BACKUP_DIR}"
echo "PATCHED_IMAGE=${WUKONGIM_PATCHED_IMAGE}"
