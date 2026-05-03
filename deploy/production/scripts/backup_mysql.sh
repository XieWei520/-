#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: backup_mysql.sh [options]

Create a compressed logical backup from the mysql service in deploy/production.

Options:
  --output-dir <dir>   Backup output directory (default: ./backups/mysql)
  --filename <name>    Output filename (default: <db>_YYYYmmdd_HHMMSS.sql.gz)
  -h, --help           Show this help

Run from deploy/production or any location; script resolves project path automatically.
EOF
}

die() {
    printf '[backup_mysql][error] %s\n' "$*" >&2
    exit 1
}

log() {
    printf '[backup_mysql] %s\n' "$*"
}

read_env_value() {
    local key="$1"
    awk -v wanted_key="${key}" '
        /^[[:space:]]*#/ || $0 !~ /=/ { next }
        {
            raw_key=$0
            sub(/=.*/, "", raw_key)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", raw_key)
            if (raw_key != wanted_key) { next }
            raw_value=$0
            sub(/^[^=]*=/, "", raw_value)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", raw_value)
            if ((substr(raw_value, 1, 1) == "\"" && substr(raw_value, length(raw_value), 1) == "\"") ||
                (substr(raw_value, 1, 1) == "'"'"'" && substr(raw_value, length(raw_value), 1) == "'"'"'")) {
                raw_value=substr(raw_value, 2, length(raw_value)-2)
            }
            print raw_value
            exit
        }
    ' .env
}

OUTPUT_DIR=""
FILENAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-dir)
            [[ $# -ge 2 ]] || die "--output-dir requires a value."
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --filename)
            [[ $# -ge 2 ]] || die "--filename requires a value."
            FILENAME="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "Unknown argument: $1"
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROD_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROD_DIR}"

[[ -f .env ]] || die ".env not found in ${PROD_DIR}. Copy from .env.example and configure secrets first."
command -v docker >/dev/null 2>&1 || die "docker is required."

MYSQL_DATABASE="$(read_env_value MYSQL_DATABASE)"
MYSQL_ROOT_PASSWORD="$(read_env_value MYSQL_ROOT_PASSWORD)"
[[ -n "${MYSQL_DATABASE}" ]] || die "MYSQL_DATABASE is missing from .env."
[[ -n "${MYSQL_ROOT_PASSWORD}" ]] || die "MYSQL_ROOT_PASSWORD is missing from .env."

OUTPUT_DIR="${OUTPUT_DIR:-${PROD_DIR}/backups/mysql}"
mkdir -p "${OUTPUT_DIR}"

if [[ -z "${FILENAME}" ]]; then
    FILENAME="${MYSQL_DATABASE}_$(date +%Y%m%d_%H%M%S).sql.gz"
fi

BACKUP_PATH="${OUTPUT_DIR%/}/${FILENAME}"
TMP_PATH="${BACKUP_PATH}.tmp"

cleanup_tmp() {
    rm -f "${TMP_PATH}"
}
trap cleanup_tmp EXIT

log "Checking mysql service state."
docker compose --env-file .env ps mysql >/dev/null 2>&1 || die "mysql service is not available via docker compose."

log "Creating backup: ${BACKUP_PATH}"
docker compose --env-file .env exec -T mysql sh -c \
    "exec mysqldump --single-transaction --quick --routines --events --triggers --set-gtid-purged=OFF -uroot -p\"\$MYSQL_ROOT_PASSWORD\" \"$MYSQL_DATABASE\"" \
    | gzip -c > "${TMP_PATH}"

[[ -s "${TMP_PATH}" ]] || die "Backup file is empty: ${TMP_PATH}"
mv "${TMP_PATH}" "${BACKUP_PATH}"

if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${BACKUP_PATH}" > "${BACKUP_PATH}.sha256"
    log "Checksum written: ${BACKUP_PATH}.sha256"
fi

trap - EXIT
log "Backup completed: ${BACKUP_PATH}"
