#!/usr/bin/env bash
set -euo pipefail

COMPOSE_DIR="${1:-/opt/wukongim-prod/src/deploy/production}"
TURN_HOST="${TURN_HOST:-127.0.0.1}"
TURN_REALM="${TURN_REALM:-infoequity.qingyunshe.top}"
TURN_USER="${TURN_USER:-codex-turn-probe}"
TURN_PASSWORD="${TURN_PASSWORD:-codex-turn-probe-pass}"

cd "${COMPOSE_DIR}"

echo "== coturn container identity =="
docker compose --env-file .env exec -T coturn sh -lc 'id; test -r /etc/coturn/certs/fullchain.pem && echo CERT_READABLE || echo CERT_NOT_READABLE; test -r /etc/coturn/certs/privkey.pem && echo PRIVKEY_READABLE || echo PRIVKEY_NOT_READABLE'

echo "== coturn recent TLS/config warnings =="
docker compose --env-file .env logs --tail=200 coturn 2>/dev/null \
  | grep -Ei 'bad configuration|cannot find private key|cannot start TLS|DTLS|TLS|WARNING|ERROR' \
  | sed -E 's/(static-auth-secret|realm|user|password|secret|key)([^[:space:]:=]*)([[:space:]]*[:=][[:space:]]*)[^[:space:]]+/\1\2\3<redacted>/Ig' \
  || true

echo "== STUN 3478 probe =="
docker compose --env-file .env exec -T coturn turnutils_stunclient "${TURN_HOST}" 3478

echo "== TURN UDP 3478 probe =="
docker compose --env-file .env exec -T coturn turnutils_uclient \
  -u "${TURN_USER}" -w "${TURN_PASSWORD}" -r "${TURN_REALM}" \
  -y "${TURN_HOST}" 3478 || true

echo "== TURNS 5349 TLS handshake probe =="
docker compose --env-file .env exec -T coturn sh -lc \
  '
host=$1
realm=$2
tmp="${TMPDIR:-/tmp}/coturn_tls_probe.$$"
trap '\''rm -f "${tmp}"'\'' EXIT
openssl_status=0
openssl s_client -connect "${host}:5349" -servername "${realm}" -brief </dev/null >"${tmp}" 2>&1 || openssl_status=$?
head -20 "${tmp}"
exit "${openssl_status}"
' sh "${TURN_HOST}" "${TURN_REALM}"
