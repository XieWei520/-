#!/usr/bin/env bash
set -euo pipefail

REMOTE_ROOT="${1:-/opt/wukongim-prod/src/deploy/production}"
shift || true

APPLY=0
DRY_RUN=1
ROLLBACK_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      APPLY=1
      DRY_RUN=0
      shift
      ;;
    --dry-run)
      APPLY=0
      DRY_RUN=1
      shift
      ;;
    --rollback)
      ROLLBACK_DIR="${2:?--rollback requires a backup directory}"
      APPLY=1
      DRY_RUN=0
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

TEMPLATE_PATH="${REMOTE_ROOT}/nginx/default.conf.template"
MAIN_NGINX_PATH="${REMOTE_ROOT}/nginx/nginx.conf"
COMPOSE_PATH="${REMOTE_ROOT}/docker-compose.yaml"
ENV_FILE="${REMOTE_ROOT}/.env"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
BACKUP_DIR="${REMOTE_ROOT}/backup/nginx-edge-${TIMESTAMP}"
CANDIDATE_DIR="${BACKUP_DIR}/candidate"

cd "${REMOTE_ROOT}"
test -f "${TEMPLATE_PATH}"
test -f "${COMPOSE_PATH}"
test -f "${ENV_FILE}"
mkdir -p "${CANDIDATE_DIR}"

restore_from_backup() {
  local backup_dir="$1"
  test -d "${backup_dir}"
  cp "${backup_dir}/default.conf.template" "${TEMPLATE_PATH}"
  cp "${backup_dir}/docker-compose.yaml" "${COMPOSE_PATH}"
  if [[ -f "${backup_dir}/nginx.conf" ]]; then
    cp "${backup_dir}/nginx.conf" "${MAIN_NGINX_PATH}"
  elif [[ -f "${backup_dir}/nginx.conf.absent" ]]; then
    rm -f "${MAIN_NGINX_PATH}"
  fi
}

if [[ -n "${ROLLBACK_DIR}" ]]; then
  echo "== rollback nginx edge optimization =="
  restore_from_backup "${ROLLBACK_DIR}"
  docker compose --env-file .env config -q
  docker compose --env-file .env up -d --no-deps --force-recreate nginx
  container_id="$(docker compose --env-file .env ps -q nginx)"
  docker exec "${container_id}" nginx -t
  docker exec "${container_id}" nginx -s reload
  echo "Rollback restored from ${ROLLBACK_DIR}"
  exit 0
fi

python3 - "${REMOTE_ROOT}" "${CANDIDATE_DIR}" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
candidate = Path(sys.argv[2])

nginx_template = r'''map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

upstream tsdd_api {
    server tsdd-api:8090;
    keepalive 64;
}

upstream callgateway_api {
    server callgateway:8091;
    keepalive 32;
}

upstream livekit_api {
    server livekit:7880;
    keepalive 32;
}

upstream wukongim_ws {
    server wukongim:5200;
    keepalive 32;
}

limit_req_zone $binary_remote_addr zone=login_limit:10m rate=20r/m;
limit_req_zone $binary_remote_addr zone=edge_noise_limit:10m rate=120r/m;

server {
    listen 80;
    server_name ${PUBLIC_DOMAIN};
    client_max_body_size ${NGINX_CLIENT_MAX_BODY_SIZE};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 308 https://${PUBLIC_DOMAIN}$request_uri;
    }
}

server {
    listen 80 default_server;
    server_name _;
    client_max_body_size ${NGINX_CLIENT_MAX_BODY_SIZE};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 308 https://${PUBLIC_DOMAIN}$request_uri;
    }
}

server {
    listen 443 ssl;
    http2 on;
    server_name ${PUBLIC_DOMAIN};
    client_max_body_size ${NGINX_CLIENT_MAX_BODY_SIZE};

    ssl_certificate /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;

    add_header Strict-Transport-Security "max-age=31536000" always;

    set $cors_allow_headers "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, token, accept, origin, Cache-Control, X-Requested-With, appid, noncestr, sign, timestamp, X-Device-ID, X-Device-Session-ID";
    set $cors_allow_methods "GET, POST, PUT, DELETE, PATCH, OPTIONS";

    error_page 418 = @cors_preflight_https;

    if ($request_method = OPTIONS) {
        return 418;
    }

    location @cors_preflight_https {
        add_header Access-Control-Allow-Origin $http_origin;
        add_header Access-Control-Allow-Credentials "true";
        add_header Access-Control-Allow-Headers $cors_allow_headers;
        add_header Access-Control-Allow-Methods $cors_allow_methods;
        add_header Access-Control-Max-Age 86400;
        add_header Vary "Origin";
        add_header Content-Length 0;
        add_header Content-Type text/plain;
        return 204;
    }

    gzip on;
    gzip_min_length 1024;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types application/json text/plain text/css application/javascript application/wasm application/octet-stream image/svg+xml font/woff font/woff2 font/ttf font/otf;

    location ~ /\.(?!well-known/acme-challenge/) {
        access_log off;
        return 404;
    }

    location ~* ^/(?:wp-|wordpress|phpmyadmin|pma|xmlrpc\.php|vendor/|composer\.(?:json|lock)|server-status|actuator|cgi-bin/) {
        limit_req zone=edge_noise_limit burst=30 nodelay;
        access_log off;
        return 404;
    }

    location = /ws {
        proxy_pass http://wukongim_ws/;
        proxy_http_version 1.1;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }

    location ^~ /v1/callgateway/ {
        proxy_pass http://callgateway_api;
        proxy_http_version 1.1;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }

    location ^~ /v1/realtime/session/ {
        proxy_pass http://tsdd_api;
        proxy_http_version 1.1;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }

    location /v1/user/login {
        limit_req zone=login_limit burst=20 nodelay;
        proxy_pass http://tsdd_api;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }

    location = /v1/file/upload {
        proxy_pass http://tsdd_api;
        proxy_http_version 1.1;
        proxy_request_buffering off;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto https;
    }

    location ^~ /v1/file/preview/ {
        proxy_pass http://tsdd_api;
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }

    location ^~ /v1/file/download/ {
        proxy_pass http://tsdd_api;
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }

    location ^~ /v1/ {
        proxy_pass http://tsdd_api;
        proxy_http_version 1.1;
        proxy_read_timeout 120s;
        proxy_send_timeout 120s;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }

    location /livekit {
        rewrite ^/livekit/?(.*)$ /$1 break;
        proxy_pass http://livekit_api;
        proxy_http_version 1.1;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }

    location ^~ /minio/ {
        proxy_pass http://minio:9000/;
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        add_header Strict-Transport-Security "max-age=31536000" always;
        add_header Cache-Control "private, max-age=604800" always;
    }

    location = /index.html {
        root /usr/share/nginx/html;
        add_header Strict-Transport-Security "max-age=31536000" always;
        add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0" always;
        try_files /index.html =404;
    }

    location = /flutter_service_worker.js {
        root /usr/share/nginx/html;
        add_header Strict-Transport-Security "max-age=31536000" always;
        add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0" always;
        try_files /flutter_service_worker.js =404;
    }

    location = /flutter_bootstrap.js {
        root /usr/share/nginx/html;
        add_header Strict-Transport-Security "max-age=31536000" always;
        add_header Cache-Control "no-cache, must-revalidate" always;
        try_files /flutter_bootstrap.js =404;
    }

    location = /main.dart.js {
        root /usr/share/nginx/html;
        add_header Strict-Transport-Security "max-age=31536000" always;
        add_header Cache-Control "public, no-cache, must-revalidate" always;
        try_files /main.dart.js =404;
    }

    location = /manifest.json {
        root /usr/share/nginx/html;
        add_header Strict-Transport-Security "max-age=31536000" always;
        add_header Cache-Control "no-cache, must-revalidate" always;
        try_files /manifest.json =404;
    }

    location ~* ^/(assets|canvaskit)/ {
        root /usr/share/nginx/html;
        access_log off;
        add_header Strict-Transport-Security "max-age=31536000" always;
        add_header Cache-Control "public, max-age=31536000, immutable" always;
        try_files $uri =404;
    }

    location ~* \.(?:png|jpg|jpeg|gif|webp|svg|ico|woff|woff2|ttf|otf)$ {
        root /usr/share/nginx/html;
        access_log off;
        add_header Strict-Transport-Security "max-age=31536000" always;
        add_header Cache-Control "public, max-age=86400" always;
        try_files $uri =404;
    }

    location / {
        root /usr/share/nginx/html;
        index index.html;
        add_header Strict-Transport-Security "max-age=31536000" always;
        add_header Cache-Control "no-cache, must-revalidate" always;
        try_files $uri $uri/ /index.html;
    }
}
'''

main_nginx = r'''user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /run/nginx.pid;

events {
    worker_connections 8192;
    multi_accept on;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    tcp_nopush     on;
    tcp_nodelay    on;
    keepalive_timeout  65;
    server_tokens off;

    include /etc/nginx/conf.d/*.conf;
}
'''

compose_path = root / "docker-compose.yaml"
compose = compose_path.read_text(encoding="utf-8")
main_mount = "      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro"
template_mount = "      - ./nginx/default.conf.template:/etc/nginx/templates/default.conf.template:ro"
if main_mount not in compose:
    if template_mount not in compose:
        raise SystemExit("nginx template mount not found in docker-compose.yaml")
    compose = compose.replace(template_mount, f"{main_mount}\n{template_mount}")

(candidate / "default.conf.template").write_text(nginx_template, encoding="utf-8")
(candidate / "nginx.conf").write_text(main_nginx, encoding="utf-8")
(candidate / "docker-compose.yaml").write_text(compose, encoding="utf-8")
PY

echo "== candidate diff =="
diff -u "${TEMPLATE_PATH}" "${CANDIDATE_DIR}/default.conf.template" || true
if [[ -f "${MAIN_NGINX_PATH}" ]]; then
  diff -u "${MAIN_NGINX_PATH}" "${CANDIDATE_DIR}/nginx.conf" || true
else
  echo "nginx/nginx.conf will be created."
fi
diff -u "${COMPOSE_PATH}" "${CANDIDATE_DIR}/docker-compose.yaml" || true

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "Dry run only. Candidate files are in ${CANDIDATE_DIR}"
  echo "Run with --apply to write files, validate docker compose, and restart nginx."
  exit 0
fi

cp "${TEMPLATE_PATH}" "${BACKUP_DIR}/default.conf.template"
cp "${COMPOSE_PATH}" "${BACKUP_DIR}/docker-compose.yaml"
if [[ -f "${MAIN_NGINX_PATH}" ]]; then
  cp "${MAIN_NGINX_PATH}" "${BACKUP_DIR}/nginx.conf"
else
  touch "${BACKUP_DIR}/nginx.conf.absent"
fi

cp "${CANDIDATE_DIR}/default.conf.template" "${TEMPLATE_PATH}"
cp "${CANDIDATE_DIR}/nginx.conf" "${MAIN_NGINX_PATH}"
cp "${CANDIDATE_DIR}/docker-compose.yaml" "${COMPOSE_PATH}"

ROLLBACK_HINT="powershell -ExecutionPolicy Bypass -File scripts\\ops\\deploy_nginx_edge_optimizations.ps1 -RollbackBackupDir ${BACKUP_DIR}"
echo "ROLLBACK_HINT=${ROLLBACK_HINT}"

if ! docker compose --env-file .env config -q; then
  echo "docker compose config failed; restoring backup." >&2
  restore_from_backup "${BACKUP_DIR}"
  exit 1
fi

if [[ "${APPLY}" -eq 1 ]]; then
  if ! docker compose --env-file .env up -d --no-deps --force-recreate nginx; then
    echo "nginx compose rollout failed; restoring backup." >&2
    restore_from_backup "${BACKUP_DIR}"
    docker compose --env-file .env up -d --no-deps --force-recreate nginx || true
    exit 1
  fi
  container_id="$(docker compose --env-file .env ps -q nginx)"
  if ! docker exec "${container_id}" nginx -t; then
    echo "nginx -t failed; restoring backup." >&2
    restore_from_backup "${BACKUP_DIR}"
    docker compose --env-file .env up -d --no-deps --force-recreate nginx || true
    exit 1
  fi
  docker exec "${container_id}" nginx -s reload

  public_domain="$(grep -E '^PUBLIC_DOMAIN=' .env | head -n1 | cut -d= -f2- | tr -d '\"')"
  if [[ -n "${public_domain}" ]]; then
    echo "== header smoke =="
    curl -k -fsSI "https://${public_domain}/index.html" | sed -n '1,12p'
    curl -k -sSI "https://${public_domain}/flutter_bootstrap.js" | sed -n '1,12p' || true
    curl -k -fsSI "https://${public_domain}/canvaskit/canvaskit.wasm" | sed -n '1,12p' || true
    curl -k -sSI "https://${public_domain}/.env" | sed -n '1,8p' || true
  fi
fi

echo "Nginx edge optimization applied. Backup: ${BACKUP_DIR}"
