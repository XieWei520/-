# infoequity.cn Domain Cutover Design

Date: 2026-04-24

## Goal

Replace the current public application domain with `infoequity.cn` across the Flutter client defaults and the production server runtime configuration.

The final public entrypoint is:

- Primary domain: `https://infoequity.cn`
- Alias: `www.infoequity.cn`, redirected to `https://infoequity.cn`

The old `wemx.cc` domain must not remain in active client defaults, production templates, rendered runtime configuration, or Nginx routing for the live stack.

## Current Findings

- DNS for both `infoequity.cn` and `www.infoequity.cn` resolves to `42.194.218.158`.
- The current server still redirects `http://infoequity.cn/` to `https://wemx.cc/`.
- Flutter active defaults currently point to `https://wemx.cc` and `wemx.cc:5100`.
- Production server configuration contains `wemx.cc` in `.env`, rendered WuKongIM/TangSengDaoDao/TURN config, Nginx routing, and certificate paths.
- The workspace already contains unrelated modified and untracked files; implementation must avoid overwriting or reverting them.

## Scope

### In Scope

1. Flutter client defaults:
   - Change default HTTP API base URL to `https://infoequity.cn`.
   - Change default IM TCP address to `infoequity.cn:5100`.
   - Update tests that assert the default domain, WSS route, media URL, call gateway URL, and LiveKit URL.
   - Keep build-time override support unchanged.
   - Keep Windows desktop tunnel defaults unchanged.

2. Production server runtime:
   - Update active `.env` values to use `infoequity.cn`.
   - Render fresh `rendered/wk.yaml`, `rendered/tsdd.yaml`, and `rendered/turnserver.conf`.
   - Update Nginx to serve `infoequity.cn` as the canonical domain.
   - Redirect `www.infoequity.cn` to `https://infoequity.cn`.
   - Remove `wemx.cc` from active Nginx server names and redirects.
   - Use a certificate path under `/etc/letsencrypt/live/infoequity.cn/`.

3. Certificate and deployment:
   - Obtain or renew a Let’s Encrypt certificate covering `infoequity.cn` and `www.infoequity.cn`.
   - Restart or reload only the services needed for the domain change.
   - Validate HTTPS, API, WSS, direct TCP IM, and `www` redirect.

### Out of Scope

- Historical logs, dated backups, archived `.bak` files, and old documentation are not rewritten unless they are used by the live runtime path.
- The server IP `42.194.218.158` remains the production host and SSH target.
- Secrets, app IDs, database credentials, Redis credentials, and object storage credentials are not rotated.
- The app brand, package name, and UI copy are not changed.

## Server Configuration Design

The production `.env` should use these domain-related active values:

```env
PUBLIC_DOMAIN=infoequity.cn
MINIO_DOWNLOAD_URL=https://infoequity.cn/minio
TURN_REALM=infoequity.cn
NGINX_SSL_CERT_PATH=/etc/letsencrypt/live/infoequity.cn/fullchain.pem
NGINX_SSL_KEY_PATH=/etc/letsencrypt/live/infoequity.cn/privkey.pem
TSDD_BASE_URL=https://infoequity.cn
TSDD_WEB_LOGIN_URL=https://infoequity.cn
```

`EXTERNAL_IP=42.194.218.158` should remain unchanged because it represents the host public IP, not the old domain.

Rendered WuKongIM external addresses should become:

```yaml
external:
  ip: "42.194.218.158"
  tcpAddr: "infoequity.cn:5100"
  wsAddr: "ws://infoequity.cn:5200"
  wssAddr: "wss://infoequity.cn/ws"
  apiUrl: "https://infoequity.cn"
```

Rendered TangSengDaoDao external and MinIO values should become:

```yaml
external:
  ip: "42.194.218.158"
  baseURL: "https://infoequity.cn"
  webLoginURL: "https://infoequity.cn"

minio:
  downloadURL: "https://infoequity.cn/minio"
```

Rendered TURN values should become:

```conf
realm=infoequity.cn
server-name=infoequity.cn
external-ip=42.194.218.158
```

## Nginx Design

Nginx should have separate public behaviors:

1. `infoequity.cn`
   - Port 80 allows ACME challenge paths.
   - All other HTTP traffic redirects to `https://infoequity.cn$request_uri`.
   - Port 443 serves the app, API, MinIO proxy, WuKongIM WSS `/ws`, call gateway, and LiveKit paths.

2. `www.infoequity.cn`
   - Port 80 allows ACME challenge paths.
   - All other HTTP traffic redirects to `https://infoequity.cn$request_uri`.
   - Port 443 redirects to `https://infoequity.cn$request_uri`.

3. Default/unknown host traffic
   - Redirects to `https://infoequity.cn$request_uri` after preserving ACME challenge handling.

The active Nginx template must not use `wemx.cc`.

## Flutter Design

`lib/core/config/api_config.dart` default values should become:

```dart
static const String devBaseUrl = String.fromEnvironment(
  'WK_DEV_BASE_URL',
  defaultValue: 'https://infoequity.cn',
);
static const String prodBaseUrl = String.fromEnvironment(
  'WK_PROD_BASE_URL',
  defaultValue: 'https://infoequity.cn',
);
static const String devWsAddr = String.fromEnvironment(
  'WK_DEV_WS_ADDR',
  defaultValue: 'infoequity.cn:5100',
);
static const String prodWsAddr = String.fromEnvironment(
  'WK_PROD_WS_ADDR',
  defaultValue: 'infoequity.cn:5100',
);
```

Tests that currently use `wemx.cc` for expected active public endpoints should be updated to `infoequity.cn`. Tests that intentionally cover arbitrary remote/IP values can keep those values if they are not asserting the default live domain.

## Deployment Sequence

1. Confirm DNS points to `42.194.218.158` for:
   - `infoequity.cn`
   - `www.infoequity.cn`

2. Back up active server files:
   - `.env`
   - `nginx/default.conf.template`
   - `rendered/wk.yaml`
   - `rendered/tsdd.yaml`
   - `rendered/turnserver.conf`

3. Prepare certificate:
   - Ensure port 80 reaches the production Nginx/certbot challenge path.
   - Obtain a Let’s Encrypt certificate for both `infoequity.cn` and `www.infoequity.cn`.
   - Stop and ask for domain-side action if ACME reports DNS, CAA, rate-limit, or validation failures.

4. Update server active config:
   - Edit `.env`.
   - Edit the Nginx template for canonical and `www` behavior.
   - Run the existing render script to regenerate runtime YAML/conf files.

5. Validate before restart where possible:
   - `docker compose --env-file .env config`
   - Nginx config validation inside the container or via a temporary check container if available.

6. Apply:
   - Recreate/reload Nginx, WuKongIM, TSDD API, callgateway, and coturn as needed.
   - Avoid touching MySQL, Redis, and MinIO unless compose dependency behavior requires them.

7. Verify:
   - `https://infoequity.cn/`
   - `https://infoequity.cn/v1/common/appconfig`
   - `https://infoequity.cn/minio/` path behavior through application media URLs
   - `wss://infoequity.cn/ws`
   - `infoequity.cn:5100`
   - `http://www.infoequity.cn/` redirects to `https://infoequity.cn/`
   - `https://www.infoequity.cn/` redirects to `https://infoequity.cn/`

8. Update Flutter code and tests:
   - Modify only domain-related defaults and test expectations.
   - Run targeted Flutter tests for API config, IM route resolution, call URL parsing, and HTTP proxy URL rewrite behavior.

## Rollback Plan

If the new domain fails after deployment:

1. Restore backed-up `.env`, Nginx template, and rendered config files.
2. Recreate/reload the affected services.
3. Re-run the same health checks against the restored old entrypoint.

Rollback does not require database changes.

## Risks and Mitigations

- Certificate issuance can fail if DNS, CAA, ICP/provider blocking, or HTTP-01 validation is not ready. Mitigation: stop at the certificate step and request domain-side action.
- Existing clients compiled with old defaults may still call `wemx.cc`. Mitigation: this cutover intentionally prioritizes removing the old domain from new builds and live server config; old client compatibility is not preserved.
- Changing Nginx while services are live may briefly interrupt API/WebSocket traffic. Mitigation: back up first, validate config before reload, and reload/recreate only affected services.
- The workspace contains unrelated changes. Mitigation: stage and commit only the design document first; implementation later must edit only domain-related files.
