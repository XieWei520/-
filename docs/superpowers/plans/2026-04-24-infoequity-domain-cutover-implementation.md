# infoequity.cn Domain Cutover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the active public application endpoint with `https://infoequity.cn`, redirect `www.infoequity.cn` to the primary domain, and remove the old `wemx.cc` live defaults from Flutter and the production server stack.

**Architecture:** The Flutter client owns build-time/default endpoint constants and URL rewrite behavior; these change locally and are verified with targeted unit tests. The server stack owns canonical routing, certificates, rendered WuKongIM/TangSengDaoDao/TURN config, and Nginx proxy behavior; these change on `ubuntu@42.194.218.158` with backups, config rendering, validation, service reload/recreate, and smoke checks. Historical logs/backups remain untouched.

**Tech Stack:** Flutter/Dart tests, PowerShell on Windows, SSH to Ubuntu, Docker Compose, Nginx, Certbot/Let’s Encrypt, WuKongIM, TangSengDaoDao, coturn.

---

## Files and Runtime Assets

### Local repository files

- Modify: `lib/core/config/api_config.dart`
  - Responsibility: canonical Flutter API/IM defaults and self-hosted URL normalization.
- Modify: `lib/modules/video_call/call_session_service.dart`
  - Responsibility: fallback/test bootstrap URLs used by call session service scaffolding.
- Modify: `lib/wukong_base/config/app_config.dart`
  - Responsibility: legacy base URL constants; replace old public endpoints with the new canonical endpoint even if this file is not on the primary runtime path.
- Modify: `lib/wukong_scan/scan_page.dart`
  - Responsibility: QR manual entry hint; remove old IP endpoint from visible UI text.
- Modify: `test/core/config/api_config_test.dart`
  - Responsibility: default API/IM endpoint assertions and self-hosted URL rewrite examples.
- Modify: `test/modules/auth/auth_repository_impl_test.dart`
  - Responsibility: auth API base URL expectation fixtures.
- Modify: `test/modules/video_call/call_bootstrap_api_test.dart`
  - Responsibility: call bootstrap control and LiveKit URL fixtures.
- Modify: `test/modules/video_call/call_realtime_client_test.dart`
  - Responsibility: call gateway WebSocket URL fixtures.
- Modify: `test/modules/video_call/call_session_service_test.dart`
  - Responsibility: call service control/LiveKit URL fixtures.
- Modify: `test/modules/video_call/livekit_call_media_engine_test.dart`
  - Responsibility: LiveKit URL fixtures.
- Modify: `test/service/api/call_api_test.dart`
  - Responsibility: call API response URL fixtures.
- Modify: `test/service/api/im_route_info_test.dart`
  - Responsibility: IM route preferred-address examples.
- Modify: `test/service/api/im_sync_api_test.dart`
  - Responsibility: IM route payload examples. The test that intentionally checks raw IP parsing keeps `42.194.218.158` because it is the current host IP and not the old domain.
- Modify: `test/service/im/im_service_test.dart`
  - Responsibility: IM route and realtime WebSocket URL examples.
- Modify: `test/wk_foundation/net/wk_http_client_proxy_io_test.dart`
  - Responsibility: HTTP proxy URL rewrite fixtures.
- Modify: `test/wukong_uikit/qr_pages_compile_test.dart`
  - Responsibility: QR sample URL; replace old `103.207.68.33` endpoint with `https://infoequity.cn`.

### Production server files

Under `/opt/wukongim-prod/src/deploy/production` on `ubuntu@42.194.218.158`:

- Modify: `.env`
  - Responsibility: active public domain, public URLs, TURN realm, and certificate paths.
- Modify: `nginx/default.conf.template`
  - Responsibility: canonical `infoequity.cn` virtual host, `www.infoequity.cn` redirect, default-host redirect, and app/API/WebSocket proxy routing.
- Regenerate: `rendered/wk.yaml`
  - Responsibility: WuKongIM external TCP/WS/WSS/API addresses.
- Regenerate: `rendered/tsdd.yaml`
  - Responsibility: TangSengDaoDao external base URL/web login URL and MinIO public download URL.
- Regenerate: `rendered/turnserver.conf`
  - Responsibility: TURN realm/server-name/external IP.
- Create if missing: `/etc/letsencrypt/live/infoequity.cn/fullchain.pem`
  - Responsibility: TLS certificate covering `infoequity.cn` and `www.infoequity.cn`.
- Create if missing: `/etc/letsencrypt/live/infoequity.cn/privkey.pem`
  - Responsibility: TLS private key mounted by Nginx and coturn.

---

## Task 1: Preflight and Certificate Preparation

**Files:**
- Read: `docs/superpowers/specs/2026-04-24-infoequity-domain-cutover-design.md`
- Remote read: `/opt/wukongim-prod/src/deploy/production/.env`
- Remote read: `/opt/wukongim-prod/src/deploy/production/nginx/default.conf.template`
- Remote create if needed: `/etc/letsencrypt/live/infoequity.cn/fullchain.pem`
- Remote create if needed: `/etc/letsencrypt/live/infoequity.cn/privkey.pem`

- [ ] **Step 1: Confirm DNS from the workstation**

Run:

```powershell
nslookup infoequity.cn
nslookup www.infoequity.cn
```

Expected: both names resolve to `42.194.218.158`.

- [ ] **Step 2: Confirm current failure mode before changes**

Run:

```powershell
curl.exe -I --connect-timeout 10 http://infoequity.cn/
curl.exe -I --connect-timeout 10 http://www.infoequity.cn/
```

Expected before implementation: the current server may redirect to `https://wemx.cc/`. This verifies the cutover is not already complete.

- [ ] **Step 3: Back up active remote config**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "set -e; cd /opt/wukongim-prod/src/deploy/production; ts=\$(date +%Y%m%d%H%M%S); backup=backup/infoequity-cutover-\$ts; mkdir -p \$backup; cp .env nginx/default.conf.template rendered/wk.yaml rendered/tsdd.yaml rendered/turnserver.conf \$backup/; printf '%s\n' \$backup > backup/.latest-infoequity-cutover-backup; echo \$backup"
```

Expected: prints a backup directory such as `backup/infoequity-cutover-20260424143000`.

- [ ] **Step 4: Check whether the new certificate already exists**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "sudo -n test -s /etc/letsencrypt/live/infoequity.cn/fullchain.pem && sudo -n test -s /etc/letsencrypt/live/infoequity.cn/privkey.pem && echo CERT_EXISTS || echo CERT_MISSING"
```

Expected: either `CERT_EXISTS` or `CERT_MISSING`.

- [ ] **Step 5: If the certificate is missing, issue it with webroot**

Run only if Step 4 prints `CERT_MISSING`:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "sudo -n certbot certonly --webroot -w /opt/wukongim-prod/src/deploy/production/certbot/www -d infoequity.cn -d www.infoequity.cn --non-interactive --agree-tos --register-unsafely-without-email"
```

Expected: Certbot reports success and creates `/etc/letsencrypt/live/infoequity.cn/`.

If Certbot reports DNS, CAA, HTTP-01 validation, rate-limit, ICP/provider blocking, or connection errors, stop implementation and report the exact error to the user because domain-side action may be needed.

- [ ] **Step 6: Verify certificate names**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "sudo -n openssl x509 -in /etc/letsencrypt/live/infoequity.cn/fullchain.pem -noout -subject -issuer -dates -ext subjectAltName"
```

Expected: output includes `DNS:infoequity.cn` and `DNS:www.infoequity.cn`.

---

## Task 2: Update Flutter Public Endpoint Defaults

**Files:**
- Modify: `lib/core/config/api_config.dart`
- Modify: `lib/modules/video_call/call_session_service.dart`
- Modify: `lib/wukong_base/config/app_config.dart`
- Modify: `lib/wukong_scan/scan_page.dart`
- Test: `test/core/config/api_config_test.dart`
- Test: `test/modules/auth/auth_repository_impl_test.dart`
- Test: `test/modules/video_call/call_bootstrap_api_test.dart`
- Test: `test/modules/video_call/call_realtime_client_test.dart`
- Test: `test/modules/video_call/call_session_service_test.dart`
- Test: `test/modules/video_call/livekit_call_media_engine_test.dart`
- Test: `test/service/api/call_api_test.dart`
- Test: `test/service/api/im_route_info_test.dart`
- Test: `test/service/api/im_sync_api_test.dart`
- Test: `test/service/im/im_service_test.dart`
- Test: `test/wk_foundation/net/wk_http_client_proxy_io_test.dart`
- Test: `test/wukong_uikit/qr_pages_compile_test.dart`

- [ ] **Step 1: Write the failing endpoint-default assertions**

Edit `test/core/config/api_config_test.dart` so the first test expects the new domain:

```dart
expect(ApiConfig.devBaseUrl, 'https://infoequity.cn');
expect(ApiConfig.prodBaseUrl, 'https://infoequity.cn');
expect(ApiConfig.devWsAddr, 'infoequity.cn:5100');
expect(ApiConfig.prodWsAddr, 'infoequity.cn:5100');
expect(ApiConfig.baseUrl, 'https://infoequity.cn');
expect(ApiConfig.wsAddr, 'infoequity.cn:5100');
```

Also change the two later default fallback expectations in the same file from `https://wemx.cc` to `https://infoequity.cn`.

- [ ] **Step 2: Run the focused test to verify it fails**

Run:

```powershell
cmd.exe /c "D:\Apps\flutter\bin\flutter.bat test test/core/config/api_config_test.dart"
```

Expected: FAIL because `ApiConfig` still defaults to `wemx.cc`.

- [ ] **Step 3: Implement `ApiConfig` defaults**

Edit `lib/core/config/api_config.dart`:

```dart
static const String devBaseUrl = String.fromEnvironment(
  'WK_DEV_BASE_URL',
  defaultValue: 'https://infoequity.cn',
);
static const String prodBaseUrl = String.fromEnvironment(
  'WK_PROD_BASE_URL',
  defaultValue: 'https://infoequity.cn',
);
```

and:

```dart
static const String devWsAddr = String.fromEnvironment(
  'WK_DEV_WS_ADDR',
  defaultValue: 'infoequity.cn:5100',
);
static const String prodWsAddr = String.fromEnvironment(
  'WK_PROD_WS_ADDR',
  defaultValue: 'infoequity.cn:5100',
);
```

- [ ] **Step 4: Update self-hosted URL fixtures**

In `test/core/config/api_config_test.dart`, replace self-hosted fixture URLs:

```dart
'https://wemx.cc/minio/chat/1/u_self/demo.png?download=0'
```

with:

```dart
'https://infoequity.cn/minio/chat/1/u_self/demo.png?download=0'
```

Replace:

```dart
'https://wemx.cc/v1/file/preview/chat/1/u_self/demo.png?download=0'
```

with:

```dart
'https://infoequity.cn/v1/file/preview/chat/1/u_self/demo.png?download=0'
```

Replace:

```dart
'https://wemx.cc/v1/file/upload?type=chat&path=/1/u_self/demo.png'
```

with:

```dart
'https://infoequity.cn/v1/file/upload?type=chat&path=/1/u_self/demo.png'
```

- [ ] **Step 5: Update call fallback URLs in implementation code**

Edit `lib/modules/video_call/call_session_service.dart` fallback bootstrap URLs:

```dart
join: CallJoinDescriptor(
  controlUrl: 'wss://infoequity.cn/v1/callgateway/ws',
  livekitUrl: 'wss://infoequity.cn/livekit',
  roomName: roomId,
),
```

- [ ] **Step 6: Update legacy app config endpoints**

Edit `lib/wukong_base/config/app_config.dart` endpoint constants:

```dart
static const String apiBaseUrl = 'https://infoequity.cn';
static const String wsUrl = 'wss://infoequity.cn/ws';
static const String apiBaseUrlProd = 'https://infoequity.cn';
static const String wsUrlProd = 'wss://infoequity.cn/ws';
```

- [ ] **Step 7: Update visible QR hint text**

In `lib/wukong_scan/scan_page.dart`, replace the old sample URL fragment:

```dart
http://103.207.68.33:8090/v1/qrcode/...
```

with:

```dart
https://infoequity.cn/v1/qrcode/...
```

Only change the URL fragment inside the existing string; leave the surrounding localized text unchanged.

- [ ] **Step 8: Update remaining active test fixtures from `wemx.cc`**

Run this replacement for test fixtures and implementation fallback strings:

```powershell
@'
from pathlib import Path
paths = [
    Path('test/modules/auth/auth_repository_impl_test.dart'),
    Path('test/modules/video_call/call_bootstrap_api_test.dart'),
    Path('test/modules/video_call/call_realtime_client_test.dart'),
    Path('test/modules/video_call/call_session_service_test.dart'),
    Path('test/modules/video_call/livekit_call_media_engine_test.dart'),
    Path('test/service/api/call_api_test.dart'),
    Path('test/service/api/im_route_info_test.dart'),
    Path('test/service/api/im_sync_api_test.dart'),
    Path('test/service/im/im_service_test.dart'),
    Path('test/wk_foundation/net/wk_http_client_proxy_io_test.dart'),
]
for path in paths:
    text = path.read_text(encoding='utf-8')
    text = text.replace('wemx.cc', 'infoequity.cn')
    path.write_text(text, encoding='utf-8')
qr = Path('test/wukong_uikit/qr_pages_compile_test.dart')
text = qr.read_text(encoding='utf-8')
text = text.replace(
    'http://103.207.68.33:8090/v1/qrcode/vercode_demo',
    'https://infoequity.cn/v1/qrcode/vercode_demo',
)
qr.write_text(text, encoding='utf-8')
'@ | python -
```

Expected: the listed files no longer contain `wemx.cc`. `test/service/api/im_sync_api_test.dart` may still contain `42.194.218.158` in the raw-IP parsing test.

- [ ] **Step 9: Run targeted Flutter tests**

Run:

```powershell
cmd.exe /c "D:\Apps\flutter\bin\flutter.bat test test/core/config/api_config_test.dart test/modules/auth/auth_repository_impl_test.dart test/modules/video_call/call_bootstrap_api_test.dart test/modules/video_call/call_realtime_client_test.dart test/modules/video_call/call_session_service_test.dart test/modules/video_call/livekit_call_media_engine_test.dart test/service/api/call_api_test.dart test/service/api/im_route_info_test.dart test/service/api/im_sync_api_test.dart test/service/im/im_service_test.dart test/wk_foundation/net/wk_http_client_proxy_io_test.dart test/wukong_uikit/qr_pages_compile_test.dart"
```

Expected: all listed tests PASS.

- [ ] **Step 10: Audit local active code for old endpoints**

Run:

```powershell
@'
import os
patterns = ('wemx.cc', 'api.botgate.cn', '103.207.68.33')
roots = ('lib', 'test')
hits = []
for root in roots:
    for dp, dns, fns in os.walk(root):
        for fn in fns:
            if not fn.endswith(('.dart', '.yaml', '.yml', '.json', '.md', '.ps1', '.py')):
                continue
            p = os.path.join(dp, fn)
            text = open(p, encoding='utf-8', errors='ignore').read()
            for pattern in patterns:
                if pattern in text:
                    hits.append((p, pattern))
for p, pattern in hits:
    print(f'{p}: {pattern}')
raise SystemExit(1 if hits else 0)
'@ | python -
```

Expected: no output and exit code `0`.

- [ ] **Step 11: Commit local Flutter changes**

Run:

```powershell
git add -- lib/core/config/api_config.dart lib/modules/video_call/call_session_service.dart lib/wukong_base/config/app_config.dart lib/wukong_scan/scan_page.dart test/core/config/api_config_test.dart test/modules/auth/auth_repository_impl_test.dart test/modules/video_call/call_bootstrap_api_test.dart test/modules/video_call/call_realtime_client_test.dart test/modules/video_call/call_session_service_test.dart test/modules/video_call/livekit_call_media_engine_test.dart test/service/api/call_api_test.dart test/service/api/im_route_info_test.dart test/service/api/im_sync_api_test.dart test/service/im/im_service_test.dart test/wk_foundation/net/wk_http_client_proxy_io_test.dart test/wukong_uikit/qr_pages_compile_test.dart
git commit -m "chore: switch Flutter endpoints to infoequity domain"
```

Expected: creates a commit containing only domain-related local changes. If unrelated pre-existing modifications in these files exist, review `git diff --cached` before committing and keep only domain changes staged.

---

## Task 3: Update Production Server Domain Configuration

**Files:**
- Remote modify: `/opt/wukongim-prod/src/deploy/production/.env`
- Remote modify: `/opt/wukongim-prod/src/deploy/production/nginx/default.conf.template`
- Remote regenerate: `/opt/wukongim-prod/src/deploy/production/rendered/wk.yaml`
- Remote regenerate: `/opt/wukongim-prod/src/deploy/production/rendered/tsdd.yaml`
- Remote regenerate: `/opt/wukongim-prod/src/deploy/production/rendered/turnserver.conf`

- [ ] **Step 1: Write a failing remote audit for old active domain**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production; grep -RIn 'wemx\.cc' .env nginx/default.conf.template rendered/wk.yaml rendered/tsdd.yaml rendered/turnserver.conf && exit 1 || exit 0"
```

Expected before implementation: command exits `1` and prints old-domain references.

- [ ] **Step 2: Update `.env` domain values**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "python3 - <<'PY'
from pathlib import Path
path = Path('/opt/wukongim-prod/src/deploy/production/.env')
text = path.read_text()
replacements = {
    'PUBLIC_DOMAIN=wemx.cc': 'PUBLIC_DOMAIN=infoequity.cn',
    'MINIO_DOWNLOAD_URL=https://wemx.cc/minio': 'MINIO_DOWNLOAD_URL=https://infoequity.cn/minio',
    'MINIO_DOWNLOAD_URL=http://42.194.218.158/minio': 'MINIO_DOWNLOAD_URL=https://infoequity.cn/minio',
    'TURN_REALM=wemx.cc': 'TURN_REALM=infoequity.cn',
    'NGINX_SSL_CERT_PATH=/etc/letsencrypt/live/wemx.cc/fullchain.pem': 'NGINX_SSL_CERT_PATH=/etc/letsencrypt/live/infoequity.cn/fullchain.pem',
    'NGINX_SSL_KEY_PATH=/etc/letsencrypt/live/wemx.cc/privkey.pem': 'NGINX_SSL_KEY_PATH=/etc/letsencrypt/live/infoequity.cn/privkey.pem',
    'TSDD_BASE_URL=https://wemx.cc': 'TSDD_BASE_URL=https://infoequity.cn',
    'TSDD_WEB_LOGIN_URL=https://wemx.cc': 'TSDD_WEB_LOGIN_URL=https://infoequity.cn',
    'TSDD_BASE_URL=http://42.194.218.158': 'TSDD_BASE_URL=https://infoequity.cn',
    'TSDD_WEB_LOGIN_URL=http://42.194.218.158': 'TSDD_WEB_LOGIN_URL=https://infoequity.cn',
}
for old, new in replacements.items():
    text = text.replace(old, new)
path.write_text(text)
PY"
```

Expected: `.env` active values now reference `infoequity.cn`; `EXTERNAL_IP=42.194.218.158` remains unchanged.

- [ ] **Step 3: Update Nginx template for canonical and `www` routing**

Replace `/opt/wukongim-prod/src/deploy/production/nginx/default.conf.template` with this complete template:

```nginx
map $http_upgrade $connection_upgrade {
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

server {
    listen 80;
    server_name ${PUBLIC_DOMAIN} www.${PUBLIC_DOMAIN};
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
    server_name www.${PUBLIC_DOMAIN};
    client_max_body_size ${NGINX_CLIENT_MAX_BODY_SIZE};

    ssl_certificate /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;

    return 308 https://${PUBLIC_DOMAIN}$request_uri;
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
    gzip_types application/json text/plain text/css application/javascript;

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

    location /v1/user/login {
        limit_req zone=login_limit burst=20 nodelay;
        proxy_pass http://tsdd_api;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }

    location /v1/file/upload {
        proxy_pass http://tsdd_api;
        proxy_http_version 1.1;
        proxy_request_buffering off;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto https;
    }

    location /v1/ {
        proxy_pass http://tsdd_api;
        proxy_http_version 1.1;
        proxy_read_timeout 120s;
        proxy_send_timeout 120s;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }

    location /v1/callgateway/ {
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

    location /v1/realtime/session/ {
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

    location /minio/ {
        proxy_pass http://minio:9000/;
        proxy_http_version 1.1;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto https;
    }

    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
}
```

Use this command to write the Nginx code block above to the remote file safely:

```powershell
@'
from pathlib import Path
plan = Path('docs/superpowers/plans/2026-04-24-infoequity-domain-cutover-implementation.md').read_text(encoding='utf-8')
marker = 'Replace `/opt/wukongim-prod/src/deploy/production/nginx/default.conf.template` with this complete template:\n\n```nginx\n'
start = plan.index(marker) + len(marker)
end = plan.index('\n```', start)
Path('.tmp-infoequity-nginx.conf').write_text(plan[start:end] + '\n', encoding='utf-8')
'@ | python -
Get-Content -Raw .tmp-infoequity-nginx.conf | ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "cat > /opt/wukongim-prod/src/deploy/production/nginx/default.conf.template"
Remove-Item .tmp-infoequity-nginx.conf
```

Expected: template contains `www.${PUBLIC_DOMAIN}` and no `wemx.cc`.

- [ ] **Step 4: Render runtime config**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "set -e; cd /opt/wukongim-prod/src/deploy/production; python3 scripts/render_config.py"
```

Expected:

```text
Rendered: /opt/wukongim-prod/src/deploy/production/rendered/livekit.yaml
Rendered: /opt/wukongim-prod/src/deploy/production/rendered/tsdd.yaml
Rendered: /opt/wukongim-prod/src/deploy/production/rendered/turnserver.conf
Rendered: /opt/wukongim-prod/src/deploy/production/rendered/wk.yaml
```

- [ ] **Step 5: Verify rendered values**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production; grep -RIn 'infoequity.cn' .env nginx/default.conf.template rendered/wk.yaml rendered/tsdd.yaml rendered/turnserver.conf; if grep -RIn 'wemx\.cc' .env nginx/default.conf.template rendered/wk.yaml rendered/tsdd.yaml rendered/turnserver.conf; then exit 1; fi"
```

Expected: prints new-domain references and exits `0`; no old-domain active references remain.

- [ ] **Step 6: Validate compose config**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production; docker compose --env-file .env config >/tmp/infoequity-compose-config.yaml && grep -n 'infoequity.cn' /tmp/infoequity-compose-config.yaml | head"
```

Expected: exits `0` and prints config lines containing `infoequity.cn`.

- [ ] **Step 7: Recreate/reload affected services**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "set -e; cd /opt/wukongim-prod/src/deploy/production; docker compose --env-file .env up -d nginx wukongim tsdd-api callgateway coturn"
```

Expected: affected services are recreated or confirmed up. MySQL, Redis, and MinIO are not intentionally recreated.

- [ ] **Step 8: Confirm service health**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production; docker compose --env-file .env ps nginx wukongim tsdd-api callgateway coturn"
```

Expected: `wukongim`, `tsdd-api`, and `callgateway` show healthy; `nginx` and `coturn` show running/up.

---

## Task 4: End-to-End Production Verification

**Files:**
- Read: production HTTP/TLS endpoints.
- Read: production container health and rendered config.

- [ ] **Step 1: Verify primary HTTPS app shell**

Run:

```powershell
curl.exe -I --connect-timeout 15 https://infoequity.cn/
```

Expected: HTTP status `200` or an app-shell success status, with no redirect to `wemx.cc`.

- [ ] **Step 2: Verify API app config**

Run:

```powershell
curl.exe -sS --connect-timeout 15 https://infoequity.cn/v1/common/appconfig
```

Expected: JSON response succeeds. Any returned public URL fields should use `https://infoequity.cn` or omit old public URLs.

- [ ] **Step 3: Verify `www` HTTP redirect**

Run:

```powershell
curl.exe -I --connect-timeout 15 http://www.infoequity.cn/
```

Expected: `301` or `308` with:

```text
Location: https://infoequity.cn/
```

- [ ] **Step 4: Verify `www` HTTPS redirect**

Run:

```powershell
curl.exe -I --connect-timeout 15 https://www.infoequity.cn/
```

Expected: `301` or `308` with:

```text
Location: https://infoequity.cn/
```

- [ ] **Step 5: Verify old-domain removal from active server files**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production; if grep -RIn 'wemx\.cc' .env nginx/default.conf.template rendered/wk.yaml rendered/tsdd.yaml rendered/turnserver.conf; then exit 1; fi"
```

Expected: no output and exit code `0`.

- [ ] **Step 6: Verify WuKongIM route payload**

Run:

```powershell
curl.exe -sS --connect-timeout 15 https://infoequity.cn/v1/users/final_verify_probe/im
```

Expected: response contains addresses using `infoequity.cn`, for example `infoequity.cn:5100` and `wss://infoequity.cn/ws`. If the endpoint requires auth or returns a controlled error, use the existing server smoke test from Step 7 instead.

- [ ] **Step 7: Run server smoke test**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production; python3 scripts/smoke_test.py --base-url https://infoequity.cn --timeout 15"
```

Expected: smoke test passes. If it fails due to certificate verification or app-specific auth assumptions, capture the exact failure and verify `/v1/common/appconfig` and container health separately before deciding whether rollback is needed.

- [ ] **Step 8: Verify direct TCP IM port reaches the same host**

Run:

```powershell
powershell.exe -NoProfile -Command "$tcp = New-Object Net.Sockets.TcpClient; $iar = $tcp.BeginConnect('infoequity.cn', 5100, $null, $null); if (-not $iar.AsyncWaitHandle.WaitOne(5000)) { throw 'timeout' }; $tcp.EndConnect($iar); $tcp.Close(); 'TCP_5100_OK'"
```

Expected:

```text
TCP_5100_OK
```

---

## Task 5: Final Local and Remote Audit

**Files:**
- Read: local `lib/`, `test/`, active plan/spec docs.
- Read: remote active production config.

- [ ] **Step 1: Run local focused tests again**

Run:

```powershell
cmd.exe /c "D:\Apps\flutter\bin\flutter.bat test test/core/config/api_config_test.dart test/modules/auth/auth_repository_impl_test.dart test/modules/video_call/call_bootstrap_api_test.dart test/modules/video_call/call_realtime_client_test.dart test/modules/video_call/call_session_service_test.dart test/modules/video_call/livekit_call_media_engine_test.dart test/service/api/call_api_test.dart test/service/api/im_route_info_test.dart test/service/api/im_sync_api_test.dart test/service/im/im_service_test.dart test/wk_foundation/net/wk_http_client_proxy_io_test.dart test/wukong_uikit/qr_pages_compile_test.dart"
```

Expected: all listed tests PASS.

- [ ] **Step 2: Audit local active runtime files for old public endpoints**

Run:

```powershell
@'
import os
patterns = ('wemx.cc', 'api.botgate.cn', '103.207.68.33')
roots = ('lib', 'test')
hits = []
for root in roots:
    for dp, dns, fns in os.walk(root):
        for fn in fns:
            if not fn.endswith(('.dart', '.yaml', '.yml', '.json', '.md', '.ps1', '.py')):
                continue
            p = os.path.join(dp, fn)
            text = open(p, encoding='utf-8', errors='ignore').read()
            for pattern in patterns:
                if pattern in text:
                    hits.append((p, pattern))
for p, pattern in hits:
    print(f'{p}: {pattern}')
raise SystemExit(1 if hits else 0)
'@ | python -
```

Expected: no output and exit code `0`.

- [ ] **Step 3: Audit remote active runtime files for old domain**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production; if grep -RIn 'wemx\.cc' .env nginx/default.conf.template rendered/wk.yaml rendered/tsdd.yaml rendered/turnserver.conf; then exit 1; fi"
```

Expected: no output and exit code `0`.

- [ ] **Step 4: Check local Git status**

Run:

```powershell
git status --short
```

Expected: only unrelated pre-existing changes remain. The domain cutover code should be committed or staged intentionally.

- [ ] **Step 5: Record completion evidence**

Add a short note to the final response with:

- The local commit hash for Flutter/domain code changes.
- The remote backup directory created in Task 1.
- The certificate subjectAltName verification result.
- The successful `curl`/smoke-test outputs.
- Any domain-side action requested from the user, if Certbot or verification required it.

---

## Rollback Steps

Use these only if the production cutover breaks active service:

1. Restore the latest backup directory recorded by Task 1:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "set -e; cd /opt/wukongim-prod/src/deploy/production; backup=\$(cat backup/.latest-infoequity-cutover-backup); test -n \$backup; cp \$backup/.env .env; cp \$backup/default.conf.template nginx/default.conf.template; cp \$backup/wk.yaml rendered/wk.yaml; cp \$backup/tsdd.yaml rendered/tsdd.yaml; cp \$backup/turnserver.conf rendered/turnserver.conf"
```

2. Recreate affected services:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production; docker compose --env-file .env up -d nginx wukongim tsdd-api callgateway coturn"
```

3. Verify the restored entrypoint with the same smoke checks previously used for the old deployment.

Rollback does not touch MySQL, Redis, MinIO data, or application databases.

---

## Self-Review

- Spec coverage: Flutter defaults, legacy active endpoint constants, server `.env`, rendered WuKongIM/TSDD/TURN config, Nginx canonical/`www` routing, certificate issuance, verification, and rollback are covered.
- Red-flag scan: the implementation tasks avoid deferred-work markers. Rollback uses `backup/.latest-infoequity-cutover-backup`, which Task 1 writes during backup creation.
- Type consistency: Dart constants and expected URLs match existing file names and test responsibilities. Server paths match the observed production directory `/opt/wukongim-prod/src/deploy/production`.
