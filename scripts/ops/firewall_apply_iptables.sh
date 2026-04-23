#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${1:-/var/backups/wukongim-firewall}"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"

sudo mkdir -p "${BACKUP_DIR}"
sudo iptables-save > "${BACKUP_DIR}/iptables-before-${TIMESTAMP}.rules"

ensure_rule() {
  if ! sudo iptables -C "$@" 2>/dev/null; then
    sudo iptables -A "$@"
  fi
}

sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

ensure_rule INPUT -i lo -j ACCEPT
ensure_rule INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ensure_rule INPUT -p tcp --dport 22 -j ACCEPT
ensure_rule INPUT -p tcp --dport 80 -j ACCEPT
ensure_rule INPUT -p tcp --dport 443 -j ACCEPT
ensure_rule INPUT -p tcp --dport 5100 -j ACCEPT
ensure_rule INPUT -p tcp --dport 5200 -j ACCEPT
ensure_rule INPUT -p tcp --dport 3478 -j ACCEPT
ensure_rule INPUT -p udp --dport 3478 -j ACCEPT
ensure_rule INPUT -p tcp --dport 5349 -j ACCEPT
ensure_rule INPUT -p udp --dport 49160:49220 -j ACCEPT
ensure_rule INPUT -p udp --dport 50000:50100 -j ACCEPT

sudo iptables-save | sudo tee "${BACKUP_DIR}/iptables-after-${TIMESTAMP}.rules" >/dev/null
sudo iptables-save
