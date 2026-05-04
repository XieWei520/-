#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${1:-/var/backups/wukongim-sysctl}"
SYSCTL_FILE="/etc/sysctl.d/99-wukongim.conf"
LIMITS_FILE="/etc/security/limits.d/wukongim-nofile.conf"
DOCKER_OVERRIDE_DIR="/etc/systemd/system/docker.service.d"
DOCKER_OVERRIDE_FILE="${DOCKER_OVERRIDE_DIR}/99-wukongim-nofile.conf"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
STATE_FILE="${BACKUP_DIR}/apply-state.${TIMESTAMP}.env"

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
  echo "${current}"
}

for cmd in sudo sysctl systemctl tee cp mkdir date mktemp chmod dirname; do
  require_cmd "${cmd}"
done
check_docker_unit

backup_if_exists() {
  local src="$1"
  local backup_name="$2"
  local display_name="$3"
  local dst_path="${BACKUP_DIR}/${backup_name}.bak.${TIMESTAMP}"

  if sudo test -f "${src}"; then
    sudo cp -a "${src}" "${dst_path}"
    echo "Backed up ${display_name} -> ${dst_path}" >&2
    echo "${dst_path}"
    return
  fi

  echo "Skip backup (missing): ${display_name}" >&2
  echo ""
}

PRE_FS_FILE_MAX="$(probe_sysctl_key "fs.file-max")"
PRE_NET_CORE_SOMAXCONN="$(probe_sysctl_key "net.core.somaxconn")"
PRE_TCP_MAX_SYN_BACKLOG="$(probe_sysctl_key "net.ipv4.tcp_max_syn_backlog")"
PRE_IP_LOCAL_PORT_RANGE="$(probe_sysctl_key "net.ipv4.ip_local_port_range")"
PRE_TCP_FIN_TIMEOUT="$(probe_sysctl_key "net.ipv4.tcp_fin_timeout")"
PRE_TCP_KEEPALIVE_TIME="$(probe_sysctl_key "net.ipv4.tcp_keepalive_time")"
PRE_TCP_KEEPALIVE_INTVL="$(probe_sysctl_key "net.ipv4.tcp_keepalive_intvl")"
PRE_TCP_KEEPALIVE_PROBES="$(probe_sysctl_key "net.ipv4.tcp_keepalive_probes")"
PRE_NF_CONNTRACK_MAX="$(probe_sysctl_key "net.netfilter.nf_conntrack_max")"
PRE_IP_LOCAL_PORT_RANGE_MIN=""
PRE_IP_LOCAL_PORT_RANGE_MAX=""
if [ -n "${PRE_IP_LOCAL_PORT_RANGE}" ]; then
  read -r PRE_IP_LOCAL_PORT_RANGE_MIN PRE_IP_LOCAL_PORT_RANGE_MAX <<<"${PRE_IP_LOCAL_PORT_RANGE}"
fi

sudo mkdir -p "${BACKUP_DIR}" "${DOCKER_OVERRIDE_DIR}" "$(dirname "${LIMITS_FILE}")"

SYSCTL_EXISTED=0
LIMITS_EXISTED=0
DOCKER_OVERRIDE_EXISTED=0

if sudo test -f "${SYSCTL_FILE}"; then
  SYSCTL_EXISTED=1
fi

if sudo test -f "${LIMITS_FILE}"; then
  LIMITS_EXISTED=1
fi

if sudo test -f "${DOCKER_OVERRIDE_FILE}"; then
  DOCKER_OVERRIDE_EXISTED=1
fi

SYSCTL_BACKUP="$(backup_if_exists "${SYSCTL_FILE}" "99-wukongim.conf" "${SYSCTL_FILE}")"
LIMITS_BACKUP="$(backup_if_exists "${LIMITS_FILE}" "wukongim-nofile.conf" "${LIMITS_FILE}")"
DOCKER_OVERRIDE_BACKUP="$(backup_if_exists "${DOCKER_OVERRIDE_FILE}" "99-wukongim-nofile.conf" "${DOCKER_OVERRIDE_FILE}")"

STATE_TMP="$(mktemp)"
cat >"${STATE_TMP}" <<EOF
STATE_VERSION=1
TIMESTAMP=${TIMESTAMP}
SYSCTL_FILE_EXISTED=${SYSCTL_EXISTED}
LIMITS_FILE_EXISTED=${LIMITS_EXISTED}
DOCKER_OVERRIDE_FILE_EXISTED=${DOCKER_OVERRIDE_EXISTED}
SYSCTL_BACKUP=${SYSCTL_BACKUP}
LIMITS_BACKUP=${LIMITS_BACKUP}
DOCKER_OVERRIDE_BACKUP=${DOCKER_OVERRIDE_BACKUP}
PRE_FS_FILE_MAX=${PRE_FS_FILE_MAX}
PRE_NET_CORE_SOMAXCONN=${PRE_NET_CORE_SOMAXCONN}
PRE_TCP_MAX_SYN_BACKLOG=${PRE_TCP_MAX_SYN_BACKLOG}
PRE_IP_LOCAL_PORT_RANGE_MIN=${PRE_IP_LOCAL_PORT_RANGE_MIN}
PRE_IP_LOCAL_PORT_RANGE_MAX=${PRE_IP_LOCAL_PORT_RANGE_MAX}
PRE_TCP_FIN_TIMEOUT=${PRE_TCP_FIN_TIMEOUT}
PRE_TCP_KEEPALIVE_TIME=${PRE_TCP_KEEPALIVE_TIME}
PRE_TCP_KEEPALIVE_INTVL=${PRE_TCP_KEEPALIVE_INTVL}
PRE_TCP_KEEPALIVE_PROBES=${PRE_TCP_KEEPALIVE_PROBES}
PRE_NF_CONNTRACK_MAX=${PRE_NF_CONNTRACK_MAX}
EOF

sudo cp "${STATE_TMP}" "${STATE_FILE}"
sudo chmod 600 "${STATE_FILE}"
rm -f "${STATE_TMP}"
echo "Transaction state file: ${STATE_FILE}"
echo "Rollback command: sudo bash ./scripts/ops/rollback_im_sysctl.sh ${BACKUP_DIR} ${STATE_FILE}"

cat <<'EOF' | sudo tee "${SYSCTL_FILE}" >/dev/null
fs.file-max = 1048576
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.ip_local_port_range = 10240 65535
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 120
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5
net.netfilter.nf_conntrack_max = 524288
EOF

cat <<'EOF' | sudo tee "${LIMITS_FILE}" >/dev/null
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF

cat <<'EOF' | sudo tee "${DOCKER_OVERRIDE_FILE}" >/dev/null
[Service]
LimitNOFILE=1048576
EOF

sudo sysctl -p "${SYSCTL_FILE}"
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl show docker --property LimitNOFILE
