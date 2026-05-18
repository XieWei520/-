#!/usr/bin/env bash
set -euo pipefail

log() {
    printf '[cleanup_feishu_monitor_minio] %s %s\n' "$(date -Is)" "$*"
}

usage() {
    cat <<'EOF'
Usage: cleanup_feishu_monitor_minio.sh [--dry-run]

Remove Feishu-monitor forwarded image objects older than 6 hours from the
dedicated MinIO chat prefix:

  chat/feishu-monitor/

The script intentionally does not accept an arbitrary object prefix.
EOF
}

MINIO_CONTAINER="${MINIO_CONTAINER:-wukongim_prod-minio-1}"
RETENTION="${FEISHU_MONITOR_MINIO_RETENTION:-6h}"
DRY_RUN="0"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN="1"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf '[cleanup_feishu_monitor_minio][error] unknown argument: %s\n' "$1" >&2
            exit 1
            ;;
    esac
done

if [[ ! "${RETENTION}" =~ ^[0-9]+[smhd]$ ]]; then
    printf '[cleanup_feishu_monitor_minio][error] invalid retention: %s\n' "${RETENTION}" >&2
    exit 1
fi

command -v docker >/dev/null 2>&1 || {
    printf '[cleanup_feishu_monitor_minio][error] docker is required.\n' >&2
    exit 1
}

docker container inspect "${MINIO_CONTAINER}" >/dev/null 2>&1 || {
    printf '[cleanup_feishu_monitor_minio][error] MinIO container not found: %s\n' "${MINIO_CONTAINER}" >&2
    exit 1
}

log "cleaning local/chat/feishu-monitor/ older_than=${RETENTION} dry_run=${DRY_RUN}"

docker exec \
    -e FEISHU_MONITOR_MINIO_RETENTION="${RETENTION}" \
    -e FEISHU_MONITOR_MINIO_DRY_RUN="${DRY_RUN}" \
    "${MINIO_CONTAINER}" sh -lc '
set -eu
export MC_CONFIG_DIR="${MC_CONFIG_DIR:-/tmp/.mc}"
export MC_HOST_local="http://${MINIO_ROOT_USER}:${MINIO_ROOT_PASSWORD}@127.0.0.1:9000"
if [ "${FEISHU_MONITOR_MINIO_DRY_RUN}" = "1" ]; then
    mc rm --quiet --recursive --force --older-than "${FEISHU_MONITOR_MINIO_RETENTION}" --dry-run local/chat/feishu-monitor/
else
    mc rm --quiet --recursive --force --older-than "${FEISHU_MONITOR_MINIO_RETENTION}" local/chat/feishu-monitor/
fi
'

log "done"
