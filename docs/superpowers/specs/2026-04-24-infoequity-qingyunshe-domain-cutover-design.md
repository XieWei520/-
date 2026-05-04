# infoequity.qingyunshe.top Domain Cutover Design

Date: 2026-04-24

## Goal

Use `infoequity.qingyunshe.top` as the single active public entrypoint for the Flutter client and production cloud server.

The final public entrypoint is:

- Primary domain: `https://infoequity.qingyunshe.top`
- IM TCP address: `infoequity.qingyunshe.top:5100`
- WuKongIM WSS address: `wss://infoequity.qingyunshe.top/ws`

The current `wemx.cc` endpoint and the earlier `infoequity.cn` cutover target must not remain in new Flutter defaults or live production routing for this cutover.

## Current Findings

- DNS for `infoequity.qingyunshe.top` resolves to `42.194.218.158`.
- `http://infoequity.qingyunshe.top/` currently returns a `308` redirect to `https://wemx.cc/`.
- `https://infoequity.qingyunshe.top/` is not currently verified as healthy from the workstation.
- Flutter active defaults currently point to `https://wemx.cc` and `wemx.cc:5100`.
- The repository already contains an older `infoequity.cn` cutover design and plan, but this cutover supersedes that target with the confirmed second-level domain `infoequity.qingyunshe.top`.
- SSH access to `ubuntu@42.194.218.158` is currently blocked by `Host key verification failed`; the implementation must resolve or re-trust the host key before remote changes.
- The workspace contains many unrelated modified and untracked files. Implementation must not revert, overwrite, or stage unrelated changes.

## Scope

### In Scope

1. Flutter client defaults:
   - Change the default HTTP API base URL to `https://infoequity.qingyunshe.top`.
   - Change the default IM TCP address to `infoequity.qingyunshe.top:5100`.
   - Update fallback WSS, LiveKit, call gateway, media, MinIO, and URL rewrite fixtures that currently assert the active public domain.
   - Keep build-time override support unchanged.
   - Keep Windows desktop tunnel defaults unchanged.

2. Production server runtime on `42.194.218.158`:
   - Update active `.env` values to use `infoequity.qingyunshe.top`.
   - Render fresh `rendered/wk.yaml`, `rendered/tsdd.yaml`, and `rendered/turnserver.conf`.
   - Update Nginx so `infoequity.qingyunshe.top` is served directly and no longer redirects to `wemx.cc`.
   - Use a certificate path under `/etc/letsencrypt/live/infoequity.qingyunshe.top/`.

3. Certificate and deployment:
   - Obtain or renew a certificate covering `infoequity.qingyunshe.top`.
   - Reload or recreate only the services needed for the domain change.
   - Validate HTTPS, API, WSS, direct TCP IM, and Flutter tests.

### Out of Scope

- Historical logs, dated backups, archived `.bak` files, and old docs are not rewritten unless they are used by the live runtime path.
- The server IP `42.194.218.158` remains unchanged.
- Database, Redis, MinIO, object-storage, app ID, app key, and other secrets are not rotated.
- App branding, package name, UI copy unrelated to endpoint examples, and account data are not changed.
- Compatibility for old Flutter builds compiled with `wemx.cc` defaults is not guaranteed by this cutover.

## Server Configuration Design

The production `.env` domain-related active values should become:

```env
PUBLIC_DOMAIN=infoequity.qingyunshe.top
MINIO_DOWNLOAD_URL=https://infoequity.qingyunshe.top/minio
TURN_REALM=infoequity.qingyunshe.top
NGINX_SSL_CERT_PATH=/etc/letsencrypt/live/infoequity.qingyunshe.top/fullchain.pem
NGINX_SSL_KEY_PATH=/etc/letsencrypt/live/infoequity.qingyunshe.top/privkey.pem
TSDD_BASE_URL=https://infoequity.qingyunshe.top
TSDD_WEB_LOGIN_URL=https://infoequity.qingyunshe.top
```

`EXTERNAL_IP=42.194.218.158` should remain unchanged because it represents the host public IP.

Rendered WuKongIM external addresses should become:

```yaml
external:
  ip: "42.194.218.158"
  tcpAddr: "infoequity.qingyunshe.top:5100"
  wsAddr: "ws://infoequity.qingyunshe.top:5200"
  wssAddr: "wss://infoequity.qingyunshe.top/ws"
  apiUrl: "https://infoequity.qingyunshe.top"
```

Rendered TangSengDaoDao external and MinIO values should become:

```yaml
external:
  ip: "42.194.218.158"
  baseURL: "https://infoequity.qingyunshe.top"
  webLoginURL: "https://infoequity.qingyunshe.top"

minio:
  downloadURL: "https://infoequity.qingyunshe.top/minio"
```

Rendered TURN values should become:

```conf
realm=infoequity.qingyunshe.top
server-name=infoequity.qingyunshe.top
external-ip=42.194.218.158
```

## Nginx Design

Nginx should expose these behaviors:

1. `infoequity.qingyunshe.top`
   - Port 80 allows ACME HTTP-01 challenge paths.
   - All other HTTP traffic redirects to `https://infoequity.qingyunshe.top$request_uri`.
   - Port 443 serves the app, API, MinIO proxy, WuKongIM WSS `/ws`, call gateway, and LiveKit paths.

2. Default or unknown host traffic
   - Preserve ACME challenge handling where possible.
   - Redirect ordinary HTTP/HTTPS requests to `https://infoequity.qingyunshe.top$request_uri`, or serve only the canonical host if the current template is simpler and safer.

The active Nginx template must not redirect `infoequity.qingyunshe.top` to `wemx.cc`.

## Flutter Design

`lib/core/config/api_config.dart` default values should become:

```dart
static const String devBaseUrl = String.fromEnvironment(
  'WK_DEV_BASE_URL',
  defaultValue: 'https://infoequity.qingyunshe.top',
);
static const String prodBaseUrl = String.fromEnvironment(
  'WK_PROD_BASE_URL',
  defaultValue: 'https://infoequity.qingyunshe.top',
);
static const String devWsAddr = String.fromEnvironment(
  'WK_DEV_WS_ADDR',
  defaultValue: 'infoequity.qingyunshe.top:5100',
);
static const String prodWsAddr = String.fromEnvironment(
  'WK_PROD_WS_ADDR',
  defaultValue: 'infoequity.qingyunshe.top:5100',
);
```

Other active public fixtures and fallback values should use:

- API base: `https://infoequity.qingyunshe.top`
- WSS route: `wss://infoequity.qingyunshe.top/ws`
- Call gateway: `wss://infoequity.qingyunshe.top/v1/callgateway/ws`
- LiveKit: `wss://infoequity.qingyunshe.top/livekit`
- MinIO public media: `https://infoequity.qingyunshe.top/minio/...`

Tests that intentionally cover arbitrary remote values or raw IP parsing may keep those fixture values if they are not asserting the active public domain.

## Deployment Sequence

1. Resolve the SSH host key verification failure for `ubuntu@42.194.218.158`.
   - Confirm the expected host key with the operator if the key changed unexpectedly.
   - Only proceed after SSH can connect safely.

2. Confirm DNS and current behavior:
   - `nslookup infoequity.qingyunshe.top`
   - `curl -I http://infoequity.qingyunshe.top/`
   - `curl -I https://infoequity.qingyunshe.top/`

3. Back up active server files:
   - `.env`
   - `nginx/default.conf.template`
   - `rendered/wk.yaml`
   - `rendered/tsdd.yaml`
   - `rendered/turnserver.conf`

4. Prepare the certificate:
   - Ensure port 80 reaches the production Nginx or certbot challenge path.
   - Obtain or renew a certificate for `infoequity.qingyunshe.top`.
   - Stop and report the exact error if ACME reports DNS, CAA, rate-limit, HTTP-01 validation, ICP/provider blocking, or connection failures.

5. Update server active config:
   - Edit `.env`.
   - Edit `nginx/default.conf.template`.
   - Run the existing render script to regenerate runtime YAML/conf files.

6. Validate before applying where possible:
   - `docker compose --env-file .env config`
   - Nginx config validation inside the running container or a temporary equivalent.

7. Apply:
   - Recreate/reload Nginx, WuKongIM, TSDD API, callgateway, and coturn as needed.
   - Avoid touching MySQL, Redis, and MinIO unless compose dependency behavior requires it.

8. Verify server behavior:
   - `https://infoequity.qingyunshe.top/`
   - `https://infoequity.qingyunshe.top/v1/common/appconfig`
   - `https://infoequity.qingyunshe.top/minio/` path behavior through application media URLs
   - `wss://infoequity.qingyunshe.top/ws`
   - `infoequity.qingyunshe.top:5100`
   - `http://infoequity.qingyunshe.top/` redirects to `https://infoequity.qingyunshe.top/`

9. Update Flutter code and tests:
   - Modify only domain-related defaults, fallback URLs, visible endpoint examples, and test expectations.
   - Run targeted Flutter tests for API config, IM route resolution, call URL parsing, and HTTP proxy URL rewrite behavior.

## Rollback Plan

If the new domain fails after deployment:

1. Restore backed-up `.env`, Nginx template, and rendered config files.
2. Recreate or reload the affected services.
3. Re-run health checks against the restored old entrypoint.

Rollback does not require database changes.

## Risks and Mitigations

- SSH host key mismatch can indicate a legitimate server reinstallation or a security risk. Mitigation: resolve and confirm the host key before remote changes.
- Certificate issuance can fail if DNS, CAA, ICP/provider rules, or HTTP-01 validation is not ready. Mitigation: stop at the certificate step and request domain-side action.
- Existing clients compiled with old defaults may still call `wemx.cc`. Mitigation: this cutover updates new builds and live server config; old build compatibility is outside this scope.
- Changing Nginx while services are live may briefly interrupt API/WebSocket traffic. Mitigation: back up first, validate config before reload, and reload/recreate only affected services.
- The workspace contains unrelated changes. Mitigation: stage and commit only this design document before implementation; implementation must edit only domain-related files.
