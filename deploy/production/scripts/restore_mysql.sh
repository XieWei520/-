#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: restore_mysql.sh [options] <backup-file>

Restore a .sql or .sql.gz backup into the mysql service in deploy/production.

Options:
  --drop-existing      Drop and recreate target database before import
  --yes, -y            Skip confirmation prompt
  -h, --help           Show this help

Examples:
  ./scripts/restore_mysql.sh ./backups/mysql/im_prod_20260405_120000.sql.gz --drop-existing --yes
  ./scripts/restore_mysql.sh /tmp/im_prod.sql
EOF
}

die() {
    printf '[restore_mysql][error] %s\n' "$*" >&2
    exit 1
}

log() {
    printf '[restore_mysql] %s\n' "$*"
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

DROP_EXISTING=0
ASSUME_YES=0
BACKUP_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --drop-existing)
            DROP_EXISTING=1
            shift
            ;;
        --yes|-y)
            ASSUME_YES=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            die "Unknown argument: $1"
            ;;
        *)
            if [[ -z "${BACKUP_FILE}" ]]; then
                BACKUP_FILE="$1"
                shift
            else
                die "Unexpected extra argument: $1"
            fi
            ;;
    esac
done

[[ -n "${BACKUP_FILE}" ]] || {
    usage
    exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROD_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROD_DIR}"

[[ -f .env ]] || die ".env not found in ${PROD_DIR}. Copy from .env.example and configure secrets first."
command -v docker >/dev/null 2>&1 || die "docker is required."

if [[ "${BACKUP_FILE}" != /* ]]; then
    BACKUP_FILE="${PWD}/${BACKUP_FILE}"
fi
[[ -f "${BACKUP_FILE}" ]] || die "Backup file not found: ${BACKUP_FILE}"

MYSQL_DATABASE="$(read_env_value MYSQL_DATABASE)"
MYSQL_ROOT_PASSWORD="$(read_env_value MYSQL_ROOT_PASSWORD)"
[[ -n "${MYSQL_DATABASE}" ]] || die "MYSQL_DATABASE is missing from .env."
[[ -n "${MYSQL_ROOT_PASSWORD}" ]] || die "MYSQL_ROOT_PASSWORD is missing from .env."
[[ "${MYSQL_DATABASE}" =~ ^[A-Za-z0-9_]+$ ]] || die "MYSQL_DATABASE must contain only letters, numbers, and underscores."
MYSQL_DATABASE_SQL_IDENTIFIER="\`${MYSQL_DATABASE}\`"

if [[ "${ASSUME_YES}" -ne 1 ]]; then
    printf '[restore_mysql] About to import %s into database "%s"%s. Continue? [y/N]: ' \
        "${BACKUP_FILE}" \
        "${MYSQL_DATABASE}" \
        "$( [[ "${DROP_EXISTING}" -eq 1 ]] && printf ' (drop-existing enabled)' )"
    read -r confirmation
    case "${confirmation}" in
        y|Y|yes|YES) ;;
        *) die "Cancelled by user." ;;
    esac
fi

log "Checking mysql service state."
docker compose --env-file .env ps mysql >/dev/null 2>&1 || die "mysql service is not available via docker compose."

if [[ "${DROP_EXISTING}" -eq 1 ]]; then
    log "Dropping and recreating database: ${MYSQL_DATABASE}"
    docker compose --env-file .env exec -T mysql sh -c \
        "exec mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" -e \"DROP DATABASE IF EXISTS ${MYSQL_DATABASE_SQL_IDENTIFIER}; CREATE DATABASE ${MYSQL_DATABASE_SQL_IDENTIFIER} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;\""
else
    log "Ensuring database exists: ${MYSQL_DATABASE}"
    docker compose --env-file .env exec -T mysql sh -c \
        "exec mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" -e \"CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE_SQL_IDENTIFIER} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;\""
fi

if [[ "${BACKUP_FILE}" == *.gz ]]; then
    log "Importing gzipped backup."
    gzip -dc "${BACKUP_FILE}" | docker compose --env-file .env exec -T mysql sh -c \
        "exec mysql --default-character-set=utf8mb4 -uroot -p\"\$MYSQL_ROOT_PASSWORD\" \"$MYSQL_DATABASE\""
else
    log "Importing sql backup."
    cat "${BACKUP_FILE}" | docker compose --env-file .env exec -T mysql sh -c \
        "exec mysql --default-character-set=utf8mb4 -uroot -p\"\$MYSQL_ROOT_PASSWORD\" \"$MYSQL_DATABASE\""
fi

TABLE_COUNT="$(docker compose --env-file .env exec -T mysql sh -c \
    "mysql -N -s -uroot -p\"\$MYSQL_ROOT_PASSWORD\" -e \"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${MYSQL_DATABASE}';\"")"
log "Restore completed. ${MYSQL_DATABASE} table count: ${TABLE_COUNT}"
