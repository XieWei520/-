# infoequity.cn Production Cutover Runbook

Date: 2026-05-07
Canonical domain: `infoequity.cn`
Canonical HTTPS origin: `https://infoequity.cn`
Canonical WSS origin: `wss://infoequity.cn/ws`

## Preconditions

1. DNS A record for `infoequity.cn` points to the production host.
2. SSH access to the production host is available.
3. Port 80 and 443 are reachable from the public internet.
4. Back up `.env`, Nginx templates, rendered configs, and compose files before changing them.

## Discovery

```bash
ssh ubuntu@42.194.218.158 'hostname; pwd; ls -la /opt/wukongim-prod/src/deploy/production'
ssh ubuntu@42.194.218.158 'cd /opt/wukongim-prod/src/deploy/production && grep -RInE "infoequity\.qingyunshe\.top|wemx\.cc|PUBLIC_DOMAIN|TSDD_BASE_URL|MINIO_DOWNLOAD_URL|NGINX_SSL" .env nginx rendered 2>/dev/null || true'
```

## DNS Check

```bash
nslookup infoequity.cn
curl -I --connect-timeout 10 http://infoequity.cn/
```

## Certificate

```bash
ssh ubuntu@42.194.218.158 'sudo -n certbot certonly --webroot -w /opt/wukongim-prod/src/deploy/production/certbot/www -d infoequity.cn --non-interactive --agree-tos --register-unsafely-without-email'
ssh ubuntu@42.194.218.158 'sudo -n openssl x509 -in /etc/letsencrypt/live/infoequity.cn/fullchain.pem -noout -subject -issuer -dates -ext subjectAltName'
```

The SAN output must contain `DNS:infoequity.cn`.

## Production Config Values

Set production environment public values to:

```dotenv
PUBLIC_DOMAIN=infoequity.cn
MINIO_DOWNLOAD_URL=https://infoequity.cn/minio
TURN_REALM=infoequity.cn
NGINX_SSL_CERT_PATH=/etc/letsencrypt/live/infoequity.cn/fullchain.pem
NGINX_SSL_KEY_PATH=/etc/letsencrypt/live/infoequity.cn/privkey.pem
TSDD_BASE_URL=https://infoequity.cn
TSDD_WEB_LOGIN_URL=https://infoequity.cn
```

`EXTERNAL_IP` may remain the server IP when a service requires a raw reachable address for non-HTTP transport, but public URLs must use only `infoequity.cn`.

## Apply

```bash
ssh ubuntu@42.194.218.158 'cd /opt/wukongim-prod/src/deploy/production && mkdir -p backup && cp .env backup/.env.before-infoequity-cn-$(date +%Y%m%d%H%M%S)'
ssh ubuntu@42.194.218.158 'cd /opt/wukongim-prod/src/deploy/production && docker compose --env-file .env config >/tmp/infoequity-cn-compose.yaml'
ssh ubuntu@42.194.218.158 'cd /opt/wukongim-prod/src/deploy/production && docker compose --env-file .env up -d --force-recreate nginx tsdd-api callgateway wukongim'
```

## Verify

```bash
curl -I --connect-timeout 15 http://infoequity.cn/
curl -I --connect-timeout 15 https://infoequity.cn/
curl -sS --connect-timeout 15 https://infoequity.cn/v1/ping
curl -sS --connect-timeout 15 https://infoequity.cn/v1/common/appconfig
curl -I --http1.1 --connect-timeout 15 -H 'Connection: Upgrade' -H 'Upgrade: websocket' https://infoequity.cn/ws
curl -I --connect-timeout 15 https://infoequity.cn/minio/minio/health/live
```

No response may redirect to or include an old public domain.

## Rollback

1. Restore the backed-up `.env` and Nginx template/config files.
2. Re-run `docker compose --env-file .env up -d --force-recreate nginx tsdd-api callgateway wukongim`.
3. Verify service health using the previous known-good endpoint.
