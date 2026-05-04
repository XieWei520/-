# wemx.cc Domain Rollback Design

Date: 2026-04-24

## Goal

Because `infoequity.cn` is temporarily unavailable, restore the live public endpoint to `https://wemx.cc` for both the Flutter client defaults and the production server runtime on `ubuntu@42.194.218.158`.

## Current Findings

- `infoequity.cn` currently has no usable A record from the workstation resolver.
- `wemx.cc` resolves to `42.194.218.158`.
- The production stack currently uses `infoequity.cn` in `.env`, rendered WuKongIM/TangSengDaoDao/TURN config, and Nginx templating.
- The server already has a Let’s Encrypt certificate directory for `wemx.cc`.
- The local workspace contains unrelated modified files; implementation must only replace endpoint-domain strings and avoid reverting other work.

## Scope

### In Scope

1. Flutter client defaults and active test fixtures:
   - `https://infoequity.cn` -> `https://wemx.cc`.
   - `infoequity.cn:5100` -> `wemx.cc:5100`.
   - `wss://infoequity.cn/...` and `ws://infoequity.cn:5200` -> matching `wemx.cc` values.

2. Production server runtime under `/opt/wukongim-prod/src/deploy/production`:
   - Set `PUBLIC_DOMAIN=wemx.cc`.
   - Set public URL, TURN realm, and Nginx certificate path variables to `wemx.cc`.
   - Regenerate `rendered/wk.yaml`, `rendered/tsdd.yaml`, and `rendered/turnserver.conf`.
   - Recreate/reload only affected services.

3. Verification:
   - Confirm `https://wemx.cc/` and selected API/WebSocket/TCP endpoints are reachable.
   - Run targeted Flutter tests for endpoint defaults and URL handling.

### Out of Scope

- DNS changes for `infoequity.cn`.
- Database, Redis, MinIO data, or credential rotation.
- Historical logs, backups, or documentation that are not active runtime config.

## Desired Server Values

```env
PUBLIC_DOMAIN=wemx.cc
MINIO_DOWNLOAD_URL=https://wemx.cc/minio
TURN_REALM=wemx.cc
NGINX_SSL_CERT_PATH=/etc/letsencrypt/live/wemx.cc/fullchain.pem
NGINX_SSL_KEY_PATH=/etc/letsencrypt/live/wemx.cc/privkey.pem
TSDD_BASE_URL=https://wemx.cc
TSDD_WEB_LOGIN_URL=https://wemx.cc
```

`EXTERNAL_IP=42.194.218.158` remains unchanged.

## Rollback

If `wemx.cc` fails after apply, restore the timestamped backup made before editing `.env`, Nginx template, and rendered files, then recreate/reload affected services.
