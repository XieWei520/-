#!/usr/bin/env bash
set -euo pipefail

INTERVAL="${1:-5}"

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "ERROR: required command not found: ${cmd}" >&2
    exit 1
  fi
}

for cmd in date ss sysctl free docker vmstat df tail sleep awk; do
  require_cmd "${cmd}"
done

if ! [[ "${INTERVAL}" =~ ^[0-9]+([.][0-9]+)?$ ]] || ! awk "BEGIN { exit !(${INTERVAL} > 0) }"; then
  echo "ERROR: interval must be a positive number (received: ${INTERVAL})" >&2
  exit 1
fi

run_section() {
  local title="$1"
  shift

  echo "== ${title} =="
  if ! "$@"; then
    echo "WARN: ${title} command failed; continuing observation loop" >&2
  fi
}

while true; do
  if ! date '+%F %T'; then
    echo "WARN: timestamp command failed" >&2
  fi
  run_section "sockets" ss -s
  run_section "conntrack" sysctl net.netfilter.nf_conntrack_count net.netfilter.nf_conntrack_max
  run_section "memory" free -h
  run_section "top docker" docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}'
  echo '== vmstat =='
  if ! vmstat 1 2 | tail -n 1; then
    echo "WARN: vmstat command failed; continuing observation loop" >&2
  fi
  run_section "disk" df -h /
  echo
  sleep "${INTERVAL}"
done
