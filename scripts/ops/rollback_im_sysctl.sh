#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${1:-/var/backups/wukongim-sysctl}"
STATE_FILE_ARG="${2:-}"
SYSCTL_FILE="/etc/sysctl.d/99-wukongim.conf"
LIMITS_FILE="/etc/security/limits.d/wukongim-nofile.conf"
DOCKER_OVERRIDE_DIR="/etc/systemd/system/docker.service.d"
DOCKER_OVERRIDE_FILE="${DOCKER_OVERRIDE_DIR}/99-wukongim-nofile.conf"

if [ "$#" -gt 2 ]; then
  echo "Usage: $0 [backup_dir] [state_file]" >&2
  exit 1
fi

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "ERROR: required command not found: ${cmd}" >&2
    exit 1
  fi
}

check_docker_unit() {
  local load_state
  if ! load_state="$(sudo systemctl show docker --property LoadState --value 2>/dev/null)"; then
    echo "ERROR: failed to query docker systemd unit" >&2
    exit 1
  fi
  if [ "${load_state}" != "loaded" ]; then
    echo "ERROR: docker systemd unit is not loaded (LoadState=${load_state})" >&2
    exit 1
  fi
}

probe_sysctl_key() {
  local key="$1"
  local current
  if ! current="$(sudo sysctl -n "${key}" 2>/dev/null)"; then
    echo "ERROR: cannot query sysctl key: ${key}" >&2
    exit 1
  fi
  if ! sudo sysctl -w "${key}=${current}" >/dev/null 2>&1; then
    echo "ERROR: cannot write sysctl key: ${key}" >&2
    exit 1
  fi
}

resolve_state_file() {
  if [ -n "${STATE_FILE_ARG}" ]; then
    if ! sudo test -f "${STATE_FILE_ARG}"; then
      echo "ERROR: state file not found: ${STATE_FILE_ARG}" >&2
      exit 1
    fi
    echo "${STATE_FILE_ARG}"
    return
  fi

  local state_files=()
  mapfile -t state_files < <(sudo ls -1 "${BACKUP_DIR}"/apply-state.*.env 2>/dev/null || true)
  if [ "${#state_files[@]}" -eq 1 ]; then
    echo "${state_files[0]}"
    return
  fi

  if [ "${#state_files[@]}" -gt 1 ]; then
    echo "ERROR: multiple transaction state files found in ${BACKUP_DIR}. Pass the desired state file as argument 2." >&2
    printf '  %s\n' "${state_files[@]}" >&2
    exit 1
  fi

  echo "ERROR: no transaction state file found in ${BACKUP_DIR}. Pass the state file path from apply output as argument 2." >&2
  exit 1
}

load_state_file() {
  local state_file="$1"
  while IFS='=' read -r key value; do
    value="${value%$'\r'}"
    case "${key}" in
      STATE_VERSION) STATE_VERSION="${value}" ;;
      SYSCTL_FILE_EXISTED) STATE_SYSCTL_EXISTED="${value}" ;;
      LIMITS_FILE_EXISTED) STATE_LIMITS_EXISTED="${value}" ;;
      DOCKER_OVERRIDE_FILE_EXISTED) STATE_DOCKER_EXISTED="${value}" ;;
      SYSCTL_BACKUP) STATE_SYSCTL_BACKUP="${value}" ;;
      LIMITS_BACKUP) STATE_LIMITS_BACKUP="${value}" ;;
      DOCKER_OVERRIDE_BACKUP) STATE_DOCKER_BACKUP="${value}" ;;
      PRE_FS_FILE_MAX) PRE_FS_FILE_MAX="${value}" ;;
      PRE_NET_CORE_SOMAXCONN) PRE_NET_CORE_SOMAXCONN="${value}" ;;
      PRE_TCP_MAX_SYN_BACKLOG) PRE_TCP_MAX_SYN_BACKLOG="${value}" ;;
      PRE_IP_LOCAL_PORT_RANGE_MIN) PRE_IP_LOCAL_PORT_RANGE_MIN="${value}" ;;
      PRE_IP_LOCAL_PORT_RANGE_MAX) PRE_IP_LOCAL_PORT_RANGE_MAX="${value}" ;;
      PRE_TCP_FIN_TIMEOUT) PRE_TCP_FIN_TIMEOUT="${value}" ;;
      PRE_TCP_KEEPALIVE_TIME) PRE_TCP_KEEPALIVE_TIME="${value}" ;;
      PRE_TCP_KEEPALIVE_INTVL) PRE_TCP_KEEPALIVE_INTVL="${value}" ;;
      PRE_TCP_KEEPALIVE_PROBES) PRE_TCP_KEEPALIVE_PROBES="${value}" ;;
      PRE_NF_CONNTRACK_MAX) PRE_NF_CONNTRACK_MAX="${value}" ;;
    esac
  done < <(sudo cat "${state_file}")
}

require_state_value() {
  local key="$1"
  local value="$2"
  if [ -z "${value}" ]; then
    echo "ERROR: missing ${key} in transaction state file" >&2
    exit 1
  fi
}

validate_state_flag() {
  local key="$1"
  local value="$2"
  if [ "${value}" != "0" ] && [ "${value}" != "1" ]; then
    echo "ERROR: invalid ${key} value in state file: ${value}" >&2
    exit 1
  fi
}

validate_state_version() {
  if [ "${STATE_VERSION}" != "1" ]; then
    echo "ERROR: unsupported STATE_VERSION=${STATE_VERSION}. Expected 1." >&2
    exit 1
  fi
}

validate_backup_reference() {
  local field_name="$1"
  local backup_path="$2"
  local existed_before="$3"
  local label="$4"

  if [ "${existed_before}" = "1" ]; then
    require_state_value "${field_name}" "${backup_path}"
  fi

  if [ -n "${backup_path}" ] && ! sudo test -f "${backup_path}"; then
    echo "ERROR: referenced backup for ${label} is missing: ${backup_path}" >&2
    exit 1
  fi
}

validate_restore_plan() {
  validate_backup_reference "SYSCTL_BACKUP" "${STATE_SYSCTL_BACKUP}" "${STATE_SYSCTL_EXISTED}" "${SYSCTL_FILE}"
  validate_backup_reference "LIMITS_BACKUP" "${STATE_LIMITS_BACKUP}" "${STATE_LIMITS_EXISTED}" "${LIMITS_FILE}"
  validate_backup_reference "DOCKER_OVERRIDE_BACKUP" "${STATE_DOCKER_BACKUP}" "${STATE_DOCKER_EXISTED}" "${DOCKER_OVERRIDE_FILE}"
}

restore_or_remove() {
  local backup_path="$1"
  local existed_before="$2"
  local target_file="$3"
  local label="$4"

  if [ -n "${backup_path}" ]; then
    sudo mkdir -p "$(dirname "${target_file}")"
    sudo cp -a "${backup_path}" "${target_file}"
    echo "Restored ${label} from ${backup_path}" >&2
    echo "restored"
    return
  fi

  if [ "${existed_before}" = "0" ]; then
    sudo rm -f "${target_file}"
    echo "Removed managed ${label}; it did not exist before apply" >&2
    echo "removed"
    return
  fi

  echo "ERROR: ${label} existed before apply but no backup path was recorded in state file" >&2
  exit 1
}

apply_runtime_if_known() {
  local key="$1"
  local value="$2"

  if [ -z "${value}" ]; then
    echo "ERROR: missing pre-apply runtime value for ${key}" >&2
    exit 1
  fi
  sudo sysctl -w "${key}=${value}" >/dev/null
}

restore_runtime_sysctl_from_state() {
  apply_runtime_if_known "fs.file-max" "${PRE_FS_FILE_MAX}"
  apply_runtime_if_known "net.core.somaxconn" "${PRE_NET_CORE_SOMAXCONN}"
  apply_runtime_if_known "net.ipv4.tcp_max_syn_backlog" "${PRE_TCP_MAX_SYN_BACKLOG}"
  sudo sysctl -w "net.ipv4.ip_local_port_range=${PRE_IP_LOCAL_PORT_RANGE_MIN} ${PRE_IP_LOCAL_PORT_RANGE_MAX}" >/dev/null
  apply_runtime_if_known "net.ipv4.tcp_fin_timeout" "${PRE_TCP_FIN_TIMEOUT}"
  apply_runtime_if_known "net.ipv4.tcp_keepalive_time" "${PRE_TCP_KEEPALIVE_TIME}"
  apply_runtime_if_known "net.ipv4.tcp_keepalive_intvl" "${PRE_TCP_KEEPALIVE_INTVL}"
  apply_runtime_if_known "net.ipv4.tcp_keepalive_probes" "${PRE_TCP_KEEPALIVE_PROBES}"
  apply_runtime_if_known "net.netfilter.nf_conntrack_max" "${PRE_NF_CONNTRACK_MAX}"
}

for cmd in sudo sysctl systemctl cp rm mkdir ls cat dirname; do
  require_cmd "${cmd}"
done
check_docker_unit
probe_sysctl_key "fs.file-max"
probe_sysctl_key "net.core.somaxconn"
probe_sysctl_key "net.ipv4.tcp_max_syn_backlog"
probe_sysctl_key "net.ipv4.ip_local_port_range"
probe_sysctl_key "net.ipv4.tcp_fin_timeout"
probe_sysctl_key "net.ipv4.tcp_keepalive_time"
probe_sysctl_key "net.ipv4.tcp_keepalive_intvl"
probe_sysctl_key "net.ipv4.tcp_keepalive_probes"
probe_sysctl_key "net.netfilter.nf_conntrack_max"

STATE_FILE="$(resolve_state_file)"
echo "Using transaction state file: ${STATE_FILE}"

STATE_VERSION=""
STATE_SYSCTL_EXISTED=""
STATE_LIMITS_EXISTED=""
STATE_DOCKER_EXISTED=""
STATE_SYSCTL_BACKUP=""
STATE_LIMITS_BACKUP=""
STATE_DOCKER_BACKUP=""
PRE_FS_FILE_MAX=""
PRE_NET_CORE_SOMAXCONN=""
PRE_TCP_MAX_SYN_BACKLOG=""
PRE_IP_LOCAL_PORT_RANGE_MIN=""
PRE_IP_LOCAL_PORT_RANGE_MAX=""
PRE_TCP_FIN_TIMEOUT=""
PRE_TCP_KEEPALIVE_TIME=""
PRE_TCP_KEEPALIVE_INTVL=""
PRE_TCP_KEEPALIVE_PROBES=""
PRE_NF_CONNTRACK_MAX=""
load_state_file "${STATE_FILE}"

require_state_value "SYSCTL_FILE_EXISTED" "${STATE_SYSCTL_EXISTED}"
require_state_value "LIMITS_FILE_EXISTED" "${STATE_LIMITS_EXISTED}"
require_state_value "DOCKER_OVERRIDE_FILE_EXISTED" "${STATE_DOCKER_EXISTED}"
require_state_value "STATE_VERSION" "${STATE_VERSION}"
validate_state_version
validate_state_flag "SYSCTL_FILE_EXISTED" "${STATE_SYSCTL_EXISTED}"
validate_state_flag "LIMITS_FILE_EXISTED" "${STATE_LIMITS_EXISTED}"
validate_state_flag "DOCKER_OVERRIDE_FILE_EXISTED" "${STATE_DOCKER_EXISTED}"
require_state_value "PRE_FS_FILE_MAX" "${PRE_FS_FILE_MAX}"
require_state_value "PRE_NET_CORE_SOMAXCONN" "${PRE_NET_CORE_SOMAXCONN}"
require_state_value "PRE_TCP_MAX_SYN_BACKLOG" "${PRE_TCP_MAX_SYN_BACKLOG}"
require_state_value "PRE_IP_LOCAL_PORT_RANGE_MIN" "${PRE_IP_LOCAL_PORT_RANGE_MIN}"
require_state_value "PRE_IP_LOCAL_PORT_RANGE_MAX" "${PRE_IP_LOCAL_PORT_RANGE_MAX}"
require_state_value "PRE_TCP_FIN_TIMEOUT" "${PRE_TCP_FIN_TIMEOUT}"
require_state_value "PRE_TCP_KEEPALIVE_TIME" "${PRE_TCP_KEEPALIVE_TIME}"
require_state_value "PRE_TCP_KEEPALIVE_INTVL" "${PRE_TCP_KEEPALIVE_INTVL}"
require_state_value "PRE_TCP_KEEPALIVE_PROBES" "${PRE_TCP_KEEPALIVE_PROBES}"
require_state_value "PRE_NF_CONNTRACK_MAX" "${PRE_NF_CONNTRACK_MAX}"
validate_restore_plan
echo "Restore plan validation passed; applying rollback mutations."

SYSCTL_RESTORE_ACTION="$(restore_or_remove "${STATE_SYSCTL_BACKUP}" "${STATE_SYSCTL_EXISTED}" "${SYSCTL_FILE}" "${SYSCTL_FILE}")"
restore_or_remove "${STATE_LIMITS_BACKUP}" "${STATE_LIMITS_EXISTED}" "${LIMITS_FILE}" "${LIMITS_FILE}" >/dev/null
restore_or_remove "${STATE_DOCKER_BACKUP}" "${STATE_DOCKER_EXISTED}" "${DOCKER_OVERRIDE_FILE}" "${DOCKER_OVERRIDE_FILE}" >/dev/null
restore_runtime_sysctl_from_state
if [ "${SYSCTL_RESTORE_ACTION}" = "restored" ]; then
  sudo sysctl -p "${SYSCTL_FILE}"
fi

sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl show docker --property LimitNOFILE
echo "Rollback completed for transaction state: ${STATE_FILE}"
