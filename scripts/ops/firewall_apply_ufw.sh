#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${1:-/var/backups/wukongim-firewall}"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"

sudo mkdir -p "${BACKUP_DIR}"
sudo ufw status numbered > "${BACKUP_DIR}/ufw-status-before-${TIMESTAMP}.txt" || true
sudo iptables-save > "${BACKUP_DIR}/iptables-before-${TIMESTAMP}.rules" || true

sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 5100/tcp
sudo ufw allow 5200/tcp
sudo ufw allow 3478/tcp
sudo ufw allow 3478/udp
sudo ufw allow 5349/tcp
sudo ufw allow 49160:49220/udp
sudo ufw allow 50000:50100/udp

sudo ufw --force enable
sudo ufw status verbose
