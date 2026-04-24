# infoequity.qingyunshe.top Domain Cutover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `https://infoequity.qingyunshe.top` the active Flutter and production cloud endpoint.

**Architecture:** Flutter owns compiled default API, IM TCP, WSS, call, LiveKit, QR, and media URL fixtures; those change locally with targeted tests. The production stack owns DNS-facing HTTPS routing, certificates, rendered WuKongIM/TangSengDaoDao/TURN configuration, and service reloads; those change remotely on `ubuntu@42.194.218.158` after SSH trust recovery and backups. Database, Redis, MinIO data, and secrets are preserved.

**Tech Stack:** Flutter/Dart tests, PowerShell on Windows, SSH to Ubuntu, Docker Compose, Nginx, Certbot/Let's Encrypt, WuKongIM, TangSengDaoDao, coturn.

---

## Files and Runtime Assets

### Local repository files

- Modify: `lib/core/config/api_config.dart`
  - Responsibility: default API base URLs and IM TCP addresses.
- Modify: `lib/modules/video_call/call_session_service.dart`
  - Responsibility: fallback call gateway and LiveKit URLs used when bootstrap data is absent.
- Modify: `lib/wukong_base/config/app_config.dart`
  - Responsibility: legacy API/WSS constants.
- Modify: `lib/wukong_scan/scan_page.dart`
  - Responsibility: QR manual-entry URL example.
- Modify: `test/core/config/api_config_test.dart`
  - Responsibility: endpoint defaults, runtime override fallback, media rewrite, upload rewrite, and Windows tunnel behavior.
- Modify: `test/modules/auth/auth_repository_impl_test.dart`
  - Responsibility: auth repository base-URL fixtures.
- Modify: `test/modules/video_call/call_bootstrap_api_test.dart`
  - Responsibility: call bootstrap URL fixtures.
- Modify: `test/modules/video_call/call_realtime_client_test.dart`
  - Responsibility: call gateway WebSocket fixtures.
- Modify: `test/modules/video_call/call_session_service_test.dart`
  - Responsibility: call session fallback and media URL fixtures.
- Modify: `test/modules/video_call/livekit_call_media_engine_test.dart`
  - Responsibility: LiveKit URL fixtures.
- Modify: `test/service/api/call_api_test.dart`
  - Responsibility: call API response URL fixtures.
- Modify: `test/service/api/common_api_test.dart`
  - Responsibility: app-config web URL fixtures.
- Modify: `test/service/api/im_route_info_test.dart`
  - Responsibility: IM route address fixtures.
- Modify: `test/service/api/im_sync_api_test.dart`
  - Responsibility: IM route payload fixtures. The raw-IP parsing test keeps `42.194.218.158` because it verifies IP parsing, not the active domain.
- Modify: `test/service/im/im_service_test.dart`
  - Responsibility: realtime-session WSS and IM address fixtures.
- Modify: `test/wk_foundation/net/wk_http_client_proxy_io_test.dart`
  - Responsibility: WSS proxy URL rewrite fixtures.
- Modify: `test/wukong_uikit/qr_pages_compile_test.dart`
  - Responsibility: QR sample URL.

### Production server files

Under `/opt/wukongim-prod/src/deploy/production` on `ubuntu@42.194.218.158`:

- Modify: `.env`
  - Responsibility: `PUBLIC_DOMAIN`, public URLs, TURN realm, and certificate paths.
- Modify: `nginx/default.conf.template`
  - Responsibility: HTTP-to-HTTPS redirect, canonical host serving, ACME challenge routing, API proxy, WSS proxy, callgateway proxy, LiveKit proxy, and MinIO proxy.
- Regenerate: `rendered/wk.yaml`
  - Responsibility: WuKongIM external TCP, WS, WSS, and API addresses.
- Regenerate: `rendered/tsdd.yaml`
  - Responsibility: TangSengDaoDao external base URL, web login URL, and MinIO download URL.
- Regenerate: `rendered/turnserver.conf`
  - Responsibility: TURN realm, server-name, and external IP.
- Create if missing: `/etc/letsencrypt/live/infoequity.qingyunshe.top/fullchain.pem`
  - Responsibility: TLS certificate for `infoequity.qingyunshe.top`.
- Create if missing: `/etc/letsencrypt/live/infoequity.qingyunshe.top/privkey.pem`
  - Responsibility: TLS private key mounted by Nginx and coturn.

---

## Task 1: SSH Trust, DNS, Certificate, and Backup Preflight

**Files:**
- Read: `docs/superpowers/specs/2026-04-24-infoequity-qingyunshe-domain-cutover-design.md`
- Read/update if trusted: `$env:USERPROFILE\.ssh\known_hosts`
- Remote read: `/opt/wukongim-prod/src/deploy/production/.env`
- Remote read: `/opt/wukongim-prod/src/deploy/production/nginx/default.conf.template`
- Remote create if missing: `/etc/letsencrypt/live/infoequity.qingyunshe.top/fullchain.pem`
- Remote create if missing: `/etc/letsencrypt/live/infoequity.qingyunshe.top/privkey.pem`

- [ ] **Step 1: Confirm DNS from the workstation**

Run:

```powershell
nslookup infoequity.qingyunshe.top
```

Expected: output includes `Address: 42.194.218.158`.

- [ ] **Step 2: Capture the current public failure mode**

Run:

```powershell
curl.exe -I --connect-timeout 10 http://infoequity.qingyunshe.top/
curl.exe -I --connect-timeout 10 https://infoequity.qingyunshe.top/
```

Expected before implementation: HTTP currently returns `308` with `Location: https://wemx.cc/`; HTTPS may fail or serve the wrong certificate/config. This confirms the production cutover is still needed.

- [ ] **Step 3: Inspect the current and offered SSH host keys**

Run:

```powershell
ssh-keygen -F 42.194.218.158
ssh-keyscan -T 10 -t ed25519,rsa 42.194.218.158 > .tmp-qingyunshe-hostkeys
ssh-keygen -lf .tmp-qingyunshe-hostkeys
Get-Content .tmp-qingyunshe-hostkeys
```

Expected: `ssh-keyscan` prints one or more host keys and `ssh-keygen -lf` prints their fingerprints. If the operator does not trust the scanned keys for the production server at `42.194.218.158`, stop before making remote changes.

- [ ] **Step 4: Replace the stale SSH host-key entry after trust is accepted**

Run only after Step 3 keys are accepted:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.ssh" | Out-Null
ssh-keygen -R 42.194.218.158
Get-Content .tmp-qingyunshe-hostkeys | Add-Content "$env:USERPROFILE\.ssh\known_hosts"
Remove-Item .tmp-qingyunshe-hostkeys
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "echo REMOTE_OK; hostname; pwd"
```

Expected: SSH prints `REMOTE_OK`, the server hostname, and the remote home directory path.

- [ ] **Step 5: Back up active remote config**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "set -e; cd /opt/wukongim-prod/src/deploy/production; ts=\$(date +%Y%m%d%H%M%S); backup=backup/qingyunshe-cutover-\$ts; mkdir -p \$backup; cp .env nginx/default.conf.template rendered/wk.yaml rendered/tsdd.yaml rendered/turnserver.conf \$backup/; printf '%s\n' \$backup > backup/.latest-qingyunshe-cutover-backup; echo \$backup"
```

Expected: prints a backup directory such as `backup/qingyunshe-cutover-20260424220000`.

- [ ] **Step 6: Check whether the new certificate already exists**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "sudo -n test -s /etc/letsencrypt/live/infoequity.qingyunshe.top/fullchain.pem && sudo -n test -s /etc/letsencrypt/live/infoequity.qingyunshe.top/privkey.pem && echo CERT_EXISTS || echo CERT_MISSING"
```

Expected: either `CERT_EXISTS` or `CERT_MISSING`.

- [ ] **Step 7: If the certificate is missing, issue it with webroot**

Run only if Step 6 prints `CERT_MISSING`:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "sudo -n certbot certonly --webroot -w /opt/wukongim-prod/src/deploy/production/certbot/www -d infoequity.qingyunshe.top --non-interactive --agree-tos --register-unsafely-without-email"
```

Expected: Certbot reports success and creates `/etc/letsencrypt/live/infoequity.qingyunshe.top/`.

If Certbot reports DNS, CAA, HTTP-01 validation, rate-limit, ICP/provider blocking, or connection errors, stop implementation and report the exact error because domain-side action is required.

- [ ] **Step 8: Verify certificate subjectAltName**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "sudo -n openssl x509 -in /etc/letsencrypt/live/infoequity.qingyunshe.top/fullchain.pem -noout -subject -issuer -dates -ext subjectAltName"
```

Expected: output includes `DNS:infoequity.qingyunshe.top`.

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
- Test: `test/service/api/common_api_test.dart`
- Test: `test/service/api/im_route_info_test.dart`
- Test: `test/service/api/im_sync_api_test.dart`
- Test: `test/service/im/im_service_test.dart`
- Test: `test/wk_foundation/net/wk_http_client_proxy_io_test.dart`
- Test: `test/wukong_uikit/qr_pages_compile_test.dart`

- [ ] **Step 1: Write failing endpoint-default assertions**

Edit `test/core/config/api_config_test.dart` so the first default test expects:

```dart
expect(ApiConfig.devBaseUrl, 'https://infoequity.qingyunshe.top');
expect(ApiConfig.prodBaseUrl, 'https://infoequity.qingyunshe.top');
expect(ApiConfig.devWsAddr, 'infoequity.qingyunshe.top:5100');
expect(ApiConfig.prodWsAddr, 'infoequity.qingyunshe.top:5100');
expect(ApiConfig.baseUrl, 'https://infoequity.qingyunshe.top');
expect(ApiConfig.wsAddr, 'infoequity.qingyunshe.top:5100');
```

Also replace the two fallback expectations in the same file from:

```dart
expect(ApiConfig.baseUrl, 'https://wemx.cc');
```

to:

```dart
expect(ApiConfig.baseUrl, 'https://infoequity.qingyunshe.top');
```

- [ ] **Step 2: Run the focused test to verify failure**

Run:

```powershell
cmd.exe /c "D:\Apps\flutter\bin\flutter.bat test test/core/config/api_config_test.dart"
```

Expected: FAIL because `ApiConfig` still defaults to `wemx.cc`.

- [ ] **Step 3: Implement `ApiConfig` defaults**

Edit `lib/core/config/api_config.dart` so the defaults are exactly:

```dart
static const String devBaseUrl = String.fromEnvironment(
  'WK_DEV_BASE_URL',
  defaultValue: 'https://infoequity.qingyunshe.top',
);
static const String prodBaseUrl = String.fromEnvironment(
  'WK_PROD_BASE_URL',
  defaultValue: 'https://infoequity.qingyunshe.top',
);
```

and:

```dart
static const String devWsAddr = String.fromEnvironment(
  'WK_DEV_WS_ADDR',
  defaultValue: 'infoequity.qingyunshe.top:5100',
);
static const String prodWsAddr = String.fromEnvironment(
  'WK_PROD_WS_ADDR',
  defaultValue: 'infoequity.qingyunshe.top:5100',
);
```

- [ ] **Step 4: Update self-hosted URL fixtures**

In `test/core/config/api_config_test.dart`, replace these fixtures:

```dart
'https://wemx.cc/minio/chat/1/u_self/demo.png?download=0'
'https://wemx.cc/v1/file/preview/chat/1/u_self/demo.png?download=0'
'https://wemx.cc/v1/file/upload?type=chat&path=/1/u_self/demo.png'
```

with:

```dart
'https://infoequity.qingyunshe.top/minio/chat/1/u_self/demo.png?download=0'
'https://infoequity.qingyunshe.top/v1/file/preview/chat/1/u_self/demo.png?download=0'
'https://infoequity.qingyunshe.top/v1/file/upload?type=chat&path=/1/u_self/demo.png'
```

- [ ] **Step 5: Update call fallback URLs in implementation code**

Edit the fallback descriptor in `lib/modules/video_call/call_session_service.dart` to:

```dart
join: CallJoinDescriptor(
  controlUrl: 'wss://infoequity.qingyunshe.top/v1/callgateway/ws',
  livekitUrl: 'wss://infoequity.qingyunshe.top/livekit',
  roomName: roomId,
),
```

- [ ] **Step 6: Update legacy app config endpoints**

Edit `lib/wukong_base/config/app_config.dart` endpoint constants to:

```dart
static const String apiBaseUrl = 'https://infoequity.qingyunshe.top';
static const String wsUrl = 'wss://infoequity.qingyunshe.top/ws';
static const String apiBaseUrlProd = 'https://infoequity.qingyunshe.top';
static const String wsUrlProd = 'wss://infoequity.qingyunshe.top/ws';
```

- [ ] **Step 7: Update visible QR hint and QR test URL**

In `lib/wukong_scan/scan_page.dart`, replace the sample URL fragment:

```dart
https://wemx.cc/v1/qrcode/...
```

with:

```dart
https://infoequity.qingyunshe.top/v1/qrcode/...
```

In `test/wukong_uikit/qr_pages_compile_test.dart`, replace:

```dart
qrData: 'https://wemx.cc/v1/qrcode/vercode_demo',
```

with:

```dart
qrData: 'https://infoequity.qingyunshe.top/v1/qrcode/vercode_demo',
```

- [ ] **Step 8: Update remaining active public-domain fixtures**

Run this controlled replacement for the remaining test fixture files:

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
    Path('test/service/api/common_api_test.dart'),
    Path('test/service/api/im_route_info_test.dart'),
    Path('test/service/api/im_sync_api_test.dart'),
    Path('test/service/im/im_service_test.dart'),
    Path('test/wk_foundation/net/wk_http_client_proxy_io_test.dart'),
]

for path in paths:
    text = path.read_text(encoding='utf-8')
    text = text.replace('wemx.cc', 'infoequity.qingyunshe.top')
    text = text.replace('infoequity.cn', 'infoequity.qingyunshe.top')
    path.write_text(text, encoding='utf-8')
'@ | python -
```

Expected: the listed files no longer contain `wemx.cc` or `infoequity.cn`. `test/service/api/im_sync_api_test.dart` may still contain `42.194.218.158` in the raw-IP parsing test.

- [ ] **Step 9: Run targeted Flutter tests**

Run:

```powershell
cmd.exe /c "D:\Apps\flutter\bin\flutter.bat test test/core/config/api_config_test.dart test/modules/auth/auth_repository_impl_test.dart test/modules/video_call/call_bootstrap_api_test.dart test/modules/video_call/call_realtime_client_test.dart test/modules/video_call/call_session_service_test.dart test/modules/video_call/livekit_call_media_engine_test.dart test/service/api/call_api_test.dart test/service/api/common_api_test.dart test/service/api/im_route_info_test.dart test/service/api/im_sync_api_test.dart test/service/im/im_service_test.dart test/wk_foundation/net/wk_http_client_proxy_io_test.dart test/wukong_uikit/qr_pages_compile_test.dart"
```

Expected: all listed tests PASS.

- [ ] **Step 10: Audit local active code for old public domains**

Run:

```powershell
@'
import os
patterns = ('wemx.cc', 'infoequity.cn', 'api.botgate.cn', '103.207.68.33')
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
git diff -- lib/core/config/api_config.dart lib/modules/video_call/call_session_service.dart lib/wukong_base/config/app_config.dart lib/wukong_scan/scan_page.dart test/core/config/api_config_test.dart test/modules/auth/auth_repository_impl_test.dart test/modules/video_call/call_bootstrap_api_test.dart test/modules/video_call/call_realtime_client_test.dart test/modules/video_call/call_session_service_test.dart test/modules/video_call/livekit_call_media_engine_test.dart test/service/api/call_api_test.dart test/service/api/common_api_test.dart test/service/api/im_route_info_test.dart test/service/api/im_sync_api_test.dart test/service/im/im_service_test.dart test/wk_foundation/net/wk_http_client_proxy_io_test.dart test/wukong_uikit/qr_pages_compile_test.dart
git add -- lib/core/config/api_config.dart lib/modules/video_call/call_session_service.dart lib/wukong_base/config/app_config.dart lib/wukong_scan/scan_page.dart test/core/config/api_config_test.dart test/modules/auth/auth_repository_impl_test.dart test/modules/video_call/call_bootstrap_api_test.dart test/modules/video_call/call_realtime_client_test.dart test/modules/video_call/call_session_service_test.dart test/modules/video_call/livekit_call_media_engine_test.dart test/service/api/call_api_test.dart test/service/api/common_api_test.dart test/service/api/im_route_info_test.dart test/service/api/im_sync_api_test.dart test/service/im/im_service_test.dart test/wk_foundation/net/wk_http_client_proxy_io_test.dart test/wukong_uikit/qr_pages_compile_test.dart
git commit -m "chore: switch Flutter endpoints to qingyunshe domain"
```

Expected: creates a commit containing only domain-related local changes. If unrelated pre-existing modifications are present in these files, use `git diff --cached` before committing and unstage unrelated hunks.

---

## Task 3: Update Production Server Domain Configuration

**Files:**
- Remote modify: `/opt/wukongim-prod/src/deploy/production/.env`
- Remote modify: `/opt/wukongim-prod/src/deploy/production/nginx/default.conf.template`
- Remote regenerate: `/opt/wukongim-prod/src/deploy/production/rendered/wk.yaml`
- Remote regenerate: `/opt/wukongim-prod/src/deploy/production/rendered/tsdd.yaml`
- Remote regenerate: `/opt/wukongim-prod/src/deploy/production/rendered/turnserver.conf`

- [ ] **Step 1: Write a failing remote audit for old active domains**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production; grep -RInE 'wemx\.cc|infoequity\.cn' .env nginx/default.conf.template rendered/wk.yaml rendered/tsdd.yaml rendered/turnserver.conf && exit 1 || exit 0"
```

Expected before implementation: command exits `1` and prints old-domain references if the remote stack has not already been cut over.

- [ ] **Step 2: Update `.env` domain values idempotently**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "python3 - <<'PY'
from pathlib import Path

path = Path('/opt/wukongim-prod/src/deploy/production/.env')
text = path.read_text()
values = {
    'PUBLIC_DOMAIN': 'infoequity.qingyunshe.top',
    'MINIO_DOWNLOAD_URL': 'https://infoequity.qingyunshe.top/minio',
    'TURN_REALM': 'infoequity.qingyunshe.top',
    'NGINX_SSL_CERT_PATH': '/etc/letsencrypt/live/infoequity.qingyunshe.top/fullchain.pem',
    'NGINX_SSL_KEY_PATH': '/etc/letsencrypt/live/infoequity.qingyunshe.top/privkey.pem',
    'TSDD_BASE_URL': 'https://infoequity.qingyunshe.top',
    'TSDD_WEB_LOGIN_URL': 'https://infoequity.qingyunshe.top',
}

lines = text.splitlines()
seen = set()
out = []
for line in lines:
    if '=' in line and not line.lstrip().startswith('#'):
        key = line.split('=', 1)[0]
        if key in values:
            out.append(f'{key}={values[key]}')
            seen.add(key)
            continue
    out.append(line)

for key, value in values.items():
    if key not in seen:
        out.append(f'{key}={value}')

path.write_text('\n'.join(out) + '\n')
PY"
```

Expected: `.env` active values reference `infoequity.qingyunshe.top`. `EXTERNAL_IP=42.194.218.158` remains unchanged.

- [ ] **Step 3: Replace the Nginx template**

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

Use this command to extract the Nginx code block above and write it to the remote template:

```powershell
@'
from pathlib import Path
plan = Path('docs/superpowers/plans/2026-04-24-infoequity-qingyunshe-domain-cutover-implementation.md').read_text(encoding='utf-8')
marker = 'Replace `/opt/wukongim-prod/src/deploy/production/nginx/default.conf.template` with this complete template:\n\n```nginx\n'
start = plan.index(marker) + len(marker)
end = plan.index('\n```', start)
Path('.tmp-qingyunshe-nginx.conf').write_text(plan[start:end] + '\n', encoding='utf-8')
'@ | python -
Get-Content -Raw .tmp-qingyunshe-nginx.conf | ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "cat > /opt/wukongim-prod/src/deploy/production/nginx/default.conf.template"
Remove-Item .tmp-qingyunshe-nginx.conf
```

Expected: remote template has `server_name ${PUBLIC_DOMAIN};` and contains no `wemx.cc` or previous apex target.

- [ ] **Step 4: Render runtime config**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "set -e; cd /opt/wukongim-prod/src/deploy/production; python3 scripts/render_config.py"
```

Expected output includes:

```text
Rendered: /opt/wukongim-prod/src/deploy/production/rendered/tsdd.yaml
Rendered: /opt/wukongim-prod/src/deploy/production/rendered/turnserver.conf
Rendered: /opt/wukongim-prod/src/deploy/production/rendered/wk.yaml
```

- [ ] **Step 5: Verify active rendered values**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production; grep -RIn 'infoequity.qingyunshe.top' .env nginx/default.conf.template rendered/wk.yaml rendered/tsdd.yaml rendered/turnserver.conf; if grep -RInE 'wemx\.cc|infoequity\.cn' .env nginx/default.conf.template rendered/wk.yaml rendered/tsdd.yaml rendered/turnserver.conf; then exit 1; fi"
```

Expected: prints new-domain references and exits `0`.

- [ ] **Step 6: Validate Docker Compose config**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production; docker compose --env-file .env config >/tmp/qingyunshe-compose-config.yaml && grep -n 'infoequity.qingyunshe.top' /tmp/qingyunshe-compose-config.yaml | head"
```

Expected: exits `0` and prints Compose config lines containing `infoequity.qingyunshe.top`.

- [ ] **Step 7: Recreate or reload affected services**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "set -e; cd /opt/wukongim-prod/src/deploy/production; docker compose --env-file .env up -d nginx wukongim tsdd-api callgateway coturn"
```

Expected: affected services are recreated or confirmed up. MySQL, Redis, and MinIO are not intentionally recreated.

- [ ] **Step 8: Confirm affected service health**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production; docker compose --env-file .env ps nginx wukongim tsdd-api callgateway coturn"
```

Expected: `wukongim`, `tsdd-api`, and `callgateway` show healthy if health checks are configured; `nginx` and `coturn` show running/up.

---

## Task 4: End-to-End Production Verification

**Files:**
- Read: production HTTP/TLS endpoints.
- Read: production container health and rendered config.

- [ ] **Step 1: Verify HTTP redirects to the canonical HTTPS domain**

Run:

```powershell
curl.exe -I --connect-timeout 15 http://infoequity.qingyunshe.top/
```

Expected: `301` or `308` with:

```text
Location: https://infoequity.qingyunshe.top/
```

- [ ] **Step 2: Verify primary HTTPS app shell**

Run:

```powershell
curl.exe -I --connect-timeout 15 https://infoequity.qingyunshe.top/
```

Expected: HTTP status `200` or another app-shell success status, with no `Location: https://wemx.cc/`.

- [ ] **Step 3: Verify API app config**

Run:

```powershell
curl.exe -sS --connect-timeout 15 https://infoequity.qingyunshe.top/v1/common/appconfig
```

Expected: JSON response succeeds. Any returned public URL fields use `https://infoequity.qingyunshe.top` or omit old public URLs.

- [ ] **Step 4: Verify WSS endpoint reaches Nginx without old-domain redirect**

Run:

```powershell
curl.exe -I --http1.1 --connect-timeout 15 -H "Connection: Upgrade" -H "Upgrade: websocket" https://infoequity.qingyunshe.top/ws
```

Expected: response is a WebSocket-related status such as `101`, `400`, or `426`; it must not include `Location: https://wemx.cc/`.

- [ ] **Step 5: Verify direct TCP IM port**

Run:

```powershell
powershell.exe -NoProfile -Command "$tcp = New-Object Net.Sockets.TcpClient; $iar = $tcp.BeginConnect('infoequity.qingyunshe.top', 5100, $null, $null); if (-not $iar.AsyncWaitHandle.WaitOne(5000)) { throw 'timeout' }; $tcp.EndConnect($iar); $tcp.Close(); 'TCP_5100_OK'"
```

Expected:

```text
TCP_5100_OK
```

- [ ] **Step 6: Verify server smoke test if available**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production; python3 scripts/smoke_test.py --base-url https://infoequity.qingyunshe.top --timeout 15"
```

Expected: smoke test passes. If `scripts/smoke_test.py` is absent or requires app-specific credentials, record that exact output and rely on Steps 1-5 plus container health.

- [ ] **Step 7: Verify old-domain removal from active server files**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production; if grep -RInE 'wemx\.cc|infoequity\.cn' .env nginx/default.conf.template rendered/wk.yaml rendered/tsdd.yaml rendered/turnserver.conf; then exit 1; fi"
```

Expected: no output and exit code `0`.

---

## Task 5: Final Local and Remote Audit

**Files:**
- Read: local `lib/` and `test/`.
- Read: remote active production config.
- Read: Git history and worktree status.

- [ ] **Step 1: Run local focused tests again**

Run:

```powershell
cmd.exe /c "D:\Apps\flutter\bin\flutter.bat test test/core/config/api_config_test.dart test/modules/auth/auth_repository_impl_test.dart test/modules/video_call/call_bootstrap_api_test.dart test/modules/video_call/call_realtime_client_test.dart test/modules/video_call/call_session_service_test.dart test/modules/video_call/livekit_call_media_engine_test.dart test/service/api/call_api_test.dart test/service/api/common_api_test.dart test/service/api/im_route_info_test.dart test/service/api/im_sync_api_test.dart test/service/im/im_service_test.dart test/wk_foundation/net/wk_http_client_proxy_io_test.dart test/wukong_uikit/qr_pages_compile_test.dart"
```

Expected: all listed tests PASS.

- [ ] **Step 2: Audit local active runtime files for old public endpoints**

Run:

```powershell
@'
import os
patterns = ('wemx.cc', 'infoequity.cn', 'api.botgate.cn', '103.207.68.33')
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

- [ ] **Step 3: Check local Git status**

Run:

```powershell
git status --short
git log -3 --oneline
```

Expected: the qingyunshe design/plan and Flutter endpoint changes are committed. Any remaining status entries are unrelated pre-existing work and are not staged by this cutover.

- [ ] **Step 4: Record completion evidence**

Final response must include:

- The design commit hash.
- The implementation/Flutter commit hash.
- The remote backup directory created in Task 1.
- The certificate subjectAltName line containing `DNS:infoequity.qingyunshe.top`.
- The successful HTTP, API, WSS, TCP, and test outputs.
- Any domain-side action requested from the user if Certbot or verification failed.

---

## Rollback Steps

Use these only if the production cutover breaks active service:

1. Restore the latest backup directory recorded by Task 1:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "set -e; cd /opt/wukongim-prod/src/deploy/production; backup=\$(cat backup/.latest-qingyunshe-cutover-backup); test -n \$backup; cp \$backup/.env .env; cp \$backup/default.conf.template nginx/default.conf.template; cp \$backup/wk.yaml rendered/wk.yaml; cp \$backup/tsdd.yaml rendered/tsdd.yaml; cp \$backup/turnserver.conf rendered/turnserver.conf"
```

2. Recreate affected services:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production; docker compose --env-file .env up -d nginx wukongim tsdd-api callgateway coturn"
```

3. Verify the restored entrypoint with the same smoke checks used before this cutover.

Rollback does not touch MySQL, Redis, MinIO data, or application databases.

---

## Self-Review

- Spec coverage: Flutter defaults, legacy endpoint constants, server `.env`, rendered WuKongIM/TSDD/TURN config, Nginx canonical routing, certificate issuance, host-key recovery, verification, and rollback are covered.
- Placeholder scan: no deferred-work markers are present; steps include exact paths, commands, expected results, and code snippets for changed constants/templates.
- Type consistency: Dart constant names, test file names, server paths, and remote service names match the current repository findings and the production path `/opt/wukongim-prod/src/deploy/production`.
