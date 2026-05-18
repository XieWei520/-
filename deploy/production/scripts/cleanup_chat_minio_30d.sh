#!/usr/bin/env bash
set -euo pipefail

log() {
    printf '[cleanup_chat_minio_30d] %s %s\n' "$(date -Is)" "$*"
}

usage() {
    cat <<'EOF'
Usage: cleanup_chat_minio_30d.sh [--dry-run]

Remove ordinary chat media objects older than 30 days from MinIO.

Allowed targets:
  chat/1/
  chat/2/

This intentionally does not clean chat/feishu-monitor/, which has its own
6 hour cleanup policy.
EOF
}

MINIO_CONTAINER="${MINIO_CONTAINER:-wukongim_prod-minio-1}"
RETENTION="${CHAT_MINIO_RETENTION:-30d}"
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
            printf '[cleanup_chat_minio_30d][error] unknown argument: %s\n' "$1" >&2
            exit 1
            ;;
    esac
done

if [[ ! "${RETENTION}" =~ ^[0-9]+[smhd]$ ]]; then
    printf '[cleanup_chat_minio_30d][error] invalid retention: %s\n' "${RETENTION}" >&2
    exit 1
fi

command -v docker >/dev/null 2>&1 || {
    printf '[cleanup_chat_minio_30d][error] docker is required.\n' >&2
    exit 1
}

docker container inspect "${MINIO_CONTAINER}" >/dev/null 2>&1 || {
    printf '[cleanup_chat_minio_30d][error] MinIO container not found: %s\n' "${MINIO_CONTAINER}" >&2
    exit 1
}

log "cleaning ordinary chat media older_than=${RETENTION} dry_run=${DRY_RUN}"

docker exec \
    -e CHAT_MINIO_RETENTION="${RETENTION}" \
    -e CHAT_MINIO_DRY_RUN="${DRY_RUN}" \
    "${MINIO_CONTAINER}" sh -lc '
set -eu
export MC_CONFIG_DIR="${MC_CONFIG_DIR:-/tmp/.mc}"
export MC_HOST_local="http://${MINIO_ROOT_USER}:${MINIO_ROOT_PASSWORD}@127.0.0.1:9000"
for target in local/chat/1/ local/chat/2/; do
    if [ "${CHAT_MINIO_DRY_RUN}" = "1" ]; then
        mc rm --quiet --recursive --force --older-than "${CHAT_MINIO_RETENTION}" --dry-run "${target}"
    else
        mc rm --quiet --recursive --force --older-than "${CHAT_MINIO_RETENTION}" "${target}"
    fi
done
'

log "done"
