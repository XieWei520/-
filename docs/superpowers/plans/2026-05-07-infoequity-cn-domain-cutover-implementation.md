# infoequity.cn Domain Cutover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `https://infoequity.cn` the only official public domain for the Flutter clients, Web release, and production server configuration.

**Architecture:** Keep one canonical public domain in Flutter defaults and production environment rendering. Update tests first so old-domain regressions fail, then update code/config, then verify locally and against the production server before deployment.

**Tech Stack:** Flutter/Dart, PowerShell, Docker Compose, Nginx, Certbot/Let's Encrypt, WuKongIM/TangSengDaoDao deployment files.

---

## File Map

- Modify: `lib/core/config/api_config.dart` — canonical Flutter API and WSS defaults.
- Modify: `lib/wukong_base/config/app_config.dart` — secondary app URL constants.
- Modify: `test/core/config/api_config_test.dart` — default URL and URL normalization assertions.
- Modify: `test/modules/auth/auth_repository_impl_test.dart` — runtime base URL fixture expectations.
- Modify: `test/modules/chat/chat_scene_providers_test.dart` — media URL fixture.
- Modify: `test/modules/video_call/*` — callgateway/livekit WSS fixtures.
- Modify: `test/service/api/*` and `test/service/im/*` — appconfig, IM route, API fixture expectations.
- Modify: `test/widgets/wk_avatar_platform_safety_test.dart`, `test/wk_foundation/net/wk_http_client_proxy_io_test.dart`, `test/wukong_uikit/*` — URL fixture expectations.
- Modify: `scripts/ops/start_android_client_monitor.ps1` — monitoring default endpoint.
- Modify: `verify_robot_image_fix.sh` — smoke URL helper.
- Modify: `deploy/full-stack/tsdd.yaml` and `deploy/full-stack/docker-compose.yaml` / `deploy/wukongim/docker-compose.yaml` — sample full-stack public endpoint defaults.
- Create: `docs/production/infoequity-cn-cutover-runbook.md` — production DNS/cert/proxy execution and rollback checklist.

## Task 1: Add failing client default-domain tests

**Files:**
- Modify: `test/core/config/api_config_test.dart`

- [ ] **Step 1: Replace the default-domain expectations with `infoequity.cn`**

Use PowerShell:

```powershell
(Get-Content -Raw test/core/config/api_config_test.dart).Replace('https://infoequity.qingyunshe.top', 'https://infoequity.cn').Replace('wss://infoequity.qingyunshe.top/ws', 'wss://infoequity.cn/ws') | Set-Content -Encoding UTF8 test/core/config/api_config_test.dart
```

- [ ] **Step 2: Run the focused test and verify it fails before implementation**

Run:

```powershell
flutter test test/core/config/api_config_test.dart
```

Expected before implementation: FAIL with expectations showing actual `https://infoequity.qingyunshe.top` and expected `https://infoequity.cn`.

## Task 2: Update Flutter canonical domain constants

**Files:**
- Modify: `lib/core/config/api_config.dart`
- Modify: `lib/wukong_base/config/app_config.dart`

- [ ] **Step 1: Update `ApiConfig` defaults**

Change these constants in `lib/core/config/api_config.dart`:

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
    defaultValue: 'wss://infoequity.cn/ws',
  );
  static const String prodWsAddr = String.fromEnvironment(
    'WK_PROD_WS_ADDR',
    defaultValue: 'wss://infoequity.cn/ws',
  );
```

- [ ] **Step 2: Update `AppConfig` secondary constants**

Change these constants in `lib/wukong_base/config/app_config.dart`:

```dart
  static const String apiBaseUrl = 'https://infoequity.cn';
  static const String wsUrl = 'wss://infoequity.cn/ws';
  static const String apiBaseUrlProd = 'https://infoequity.cn';
  static const String wsUrlProd = 'wss://infoequity.cn/ws';
```

- [ ] **Step 3: Re-run the focused test and verify it passes**

Run:

```powershell
flutter test test/core/config/api_config_test.dart
```

Expected: all tests in `api_config_test.dart` PASS.

## Task 3: Update remaining active Dart test fixtures

**Files:**
- Modify: `test/modules/auth/auth_repository_impl_test.dart`
- Modify: `test/modules/chat/chat_scene_providers_test.dart`
- Modify: `test/modules/video_call/call_bootstrap_api_test.dart`
- Modify: `test/modules/video_call/call_realtime_client_test.dart`
- Modify: `test/modules/video_call/call_session_service_test.dart`
- Modify: `test/modules/video_call/livekit_call_media_engine_test.dart`
- Modify: `test/service/api/call_api_test.dart`
- Modify: `test/service/api/common_api_test.dart`
- Modify: `test/service/api/im_route_info_test.dart`
- Modify: `test/service/api/im_sync_api_test.dart`
- Modify: `test/service/im/im_service_test.dart`
- Modify: `test/widgets/wk_avatar_platform_safety_test.dart`
- Modify: `test/wk_foundation/net/wk_http_client_proxy_io_test.dart`
- Modify: `test/wukong_uikit/group/group_detail_page_settings_test.dart`
- Modify: `test/wukong_uikit/qr_pages_compile_test.dart`

- [ ] **Step 1: Replace test fixture host strings**

Run:

```powershell
$files = Get-ChildItem test -Recurse -File -Include *.dart
foreach ($file in $files) {
  $text = Get-Content -Raw $file.FullName
  $updated = $text.Replace('infoequity.qingyunshe.top', 'infoequity.cn')
  if ($updated -ne $text) {
    Set-Content -Encoding UTF8 $file.FullName $updated
  }
}
```

- [ ] **Step 2: Run representative test suites**

Run:

```powershell
flutter test test/service/api/im_route_info_test.dart test/service/im/im_service_test.dart test/service/api/common_api_test.dart test/modules/video_call test/widgets/wk_avatar_platform_safety_test.dart
```

Expected: all selected tests PASS.

## Task 4: Update active scripts and deployment sample configs

**Files:**
- Modify: `scripts/ops/start_android_client_monitor.ps1`
- Modify: `verify_robot_image_fix.sh`
- Modify: `deploy/full-stack/tsdd.yaml`
- Modify: `deploy/full-stack/docker-compose.yaml`
- Modify: `deploy/wukongim/docker-compose.yaml`

- [ ] **Step 1: Update monitor and smoke helper URLs**

Run:

```powershell
$files = @('scripts/ops/start_android_client_monitor.ps1', 'verify_robot_image_fix.sh')
foreach ($path in $files) {
  $text = Get-Content -Raw $path
  $text = $text.Replace('https://wemx.cc', 'https://infoequity.cn')
  $text = $text.Replace('wss://wemx.cc/ws', 'wss://infoequity.cn/ws')
  $text = $text.Replace('infoequity.qingyunshe.top', 'infoequity.cn')
  Set-Content -Encoding UTF8 $path $text
}
```

- [ ] **Step 2: Update sample full-stack external public URLs**

Change `deploy/full-stack/tsdd.yaml` external block so the public URLs use `https://infoequity.cn` while `external.ip` stays the real server IP (for example `103.207.68.33`):

```yaml
external:
  ip: "103.207.68.33"
  baseURL: "https://infoequity.cn"
  webLoginURL: "https://infoequity.cn"
```

Keep `WK_EXTERNAL_IP` in both compose samples as the real server IP (for example `103.207.68.33`).

- [ ] **Step 3: Verify active config scan**

Run:

```powershell
$paths = @('lib','test','scripts','deploy')
$hits = foreach ($p in $paths) { Get-ChildItem $p -Recurse -File | Select-String -Pattern 'infoequity\.qingyunshe\.top|wemx\.cc' }
if ($hits) { $hits | ForEach-Object { "{0}:{1}: {2}" -f $_.Path,$_.LineNumber,$_.Line.Trim() }; exit 1 } else { 'NO_OLD_DOMAIN_HITS_IN_ACTIVE_PATHS' }
```

Expected: prints `NO_OLD_DOMAIN_HITS_IN_ACTIVE_PATHS`.

## Task 5: Write production cutover runbook

**Files:**
- Create: `docs/production/infoequity-cn-cutover-runbook.md`

- [ ] **Step 1: Create the runbook**

Write this file:

```markdown
# infoequity.cn Production Cutover Runbook

Date: 2026-05-07
Canonical domain: `infoequity.cn`
Canonical HTTPS origin: `https://infoequity.cn`
Canonical WSS origin: `wss://infoequity.cn/ws`

## Preconditions

1. DNS A record for `infoequity.cn` points to the production host.
2. SSH access to the production host is available.
3. Port 80 and 443 are reachable from the public internet.
4. The production deployment directory is backed up before changing `.env`, Nginx templates, rendered configs, or compose files.

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

Set the production environment to these public values:

```dotenv
PUBLIC_DOMAIN=infoequity.cn
MINIO_DOWNLOAD_URL=https://infoequity.cn/minio
TURN_REALM=infoequity.cn
NGINX_SSL_CERT_PATH=/etc/letsencrypt/live/infoequity.cn/fullchain.pem
NGINX_SSL_KEY_PATH=/etc/letsencrypt/live/infoequity.cn/privkey.pem
TSDD_BASE_URL=https://infoequity.cn
TSDD_WEB_LOGIN_URL=https://infoequity.cn
```

`EXTERNAL_IP` may remain the server IP if the backend requires a raw reachable address for non-HTTP transport, but public URLs must not use the old domains.

## Apply

```bash
ssh ubuntu@42.194.218.158 'cd /opt/wukongim-prod/src/deploy/production && cp .env backup/.env.before-infoequity-cn-$(date +%Y%m%d%H%M%S) && docker compose --env-file .env config >/tmp/infoequity-cn-compose.yaml'
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

No response may redirect to or include `infoequity.qingyunshe.top` or `wemx.cc`.

## Rollback

1. Restore the backed-up `.env` and Nginx template/config files.
2. Re-run `docker compose --env-file .env up -d --force-recreate nginx tsdd-api callgateway wukongim`.
3. Verify service health using the previous known-good endpoint.
```

- [ ] **Step 2: Run markdown scan**

Run:

```powershell
Select-String -Path docs/production/infoequity-cn-cutover-runbook.md -Pattern 'infoequity\.qingyunshe\.top|wemx\.cc'
```

Expected: no matches.

## Task 6: Full local verification

**Files:**
- No code changes unless verification reveals a defect.

- [ ] **Step 1: Run focused Flutter tests**

Run:

```powershell
flutter test test/core/config/api_config_test.dart test/service/api/im_route_info_test.dart test/service/im/im_service_test.dart test/service/api/common_api_test.dart test/modules/video_call test/widgets/wk_avatar_platform_safety_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run analyzer**

Run:

```powershell
flutter analyze
```

Expected: no new domain-cutover issues. If pre-existing analyzer warnings appear, record them separately and do not hide them.

- [ ] **Step 3: Scan active paths for old public domains**

Run:

```powershell
$paths = @('lib','test','scripts','deploy')
$hits = foreach ($p in $paths) { Get-ChildItem $p -Recurse -File | Select-String -Pattern 'infoequity\.qingyunshe\.top|wemx\.cc' }
if ($hits) { $hits | ForEach-Object { "{0}:{1}: {2}" -f $_.Path,$_.LineNumber,$_.Line.Trim() }; exit 1 } else { 'NO_OLD_DOMAIN_HITS_IN_ACTIVE_PATHS' }
```

Expected: `NO_OLD_DOMAIN_HITS_IN_ACTIVE_PATHS`.

## Task 7: Remote production execution gate

**Files:**
- No repository file changes.

- [ ] **Step 1: Confirm SSH and production path**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "hostname; test -d /opt/wukongim-prod/src/deploy/production && echo PROD_PATH_OK"
```

Expected: prints `PROD_PATH_OK`.

- [ ] **Step 2: Confirm DNS points at production**

Run:

```powershell
nslookup infoequity.cn
curl.exe -I --connect-timeout 10 http://infoequity.cn/
```

Expected: DNS resolves to the production host and HTTP reaches the server. If DNS does not resolve to production, stop and ask the user to update DNS.

- [ ] **Step 3: Inspect remote current domain config**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && grep -RInE 'infoequity\.qingyunshe\.top|wemx\.cc|PUBLIC_DOMAIN|TSDD_BASE_URL|MINIO_DOWNLOAD_URL|NGINX_SSL' .env nginx rendered 2>/dev/null || true"
```

Expected: output identifies the exact remote files to update.

## Task 8: Remote production apply and verify

**Files:**
- Remote production config files only.

- [ ] **Step 1: Back up remote production config**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && mkdir -p backup/infoequity-cn-$(date +%Y%m%d%H%M%S) && cp -a .env nginx rendered backup/infoequity-cn-$(date +%Y%m%d%H%M%S)/ 2>/dev/null || true"
```

Expected: backup directory created.

- [ ] **Step 2: Edit remote env/template values to `infoequity.cn`**

Use a remote script that replaces old domains in production configuration files only:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && python3 - <<'PY'
from pathlib import Path
paths = [Path('.env')]
paths += list(Path('nginx').rglob('*')) if Path('nginx').exists() else []
paths += list(Path('rendered').rglob('*')) if Path('rendered').exists() else []
for p in paths:
    if not p.is_file():
        continue
    text = p.read_text(errors='ignore')
    new = text.replace('infoequity.qingyunshe.top', 'infoequity.cn').replace('wemx.cc', 'infoequity.cn')
    if new != text:
        p.write_text(new)
        print(p)
PY"
```

Expected: prints changed remote files.

- [ ] **Step 3: Ensure cert exists**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "sudo -n test -s /etc/letsencrypt/live/infoequity.cn/fullchain.pem && sudo -n test -s /etc/letsencrypt/live/infoequity.cn/privkey.pem || sudo -n certbot certonly --webroot -w /opt/wukongim-prod/src/deploy/production/certbot/www -d infoequity.cn --non-interactive --agree-tos --register-unsafely-without-email"
```

Expected: certificate files exist.

- [ ] **Step 4: Recreate affected services**

Run:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=15 ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose --env-file .env config >/tmp/infoequity-cn-compose.yaml && docker compose --env-file .env up -d --force-recreate nginx tsdd-api callgateway wukongim"
```

Expected: services recreated successfully.

- [ ] **Step 5: Verify public endpoints**

Run:

```powershell
curl.exe -I --connect-timeout 15 http://infoequity.cn/
curl.exe -I --connect-timeout 15 https://infoequity.cn/
curl.exe -sS --connect-timeout 15 https://infoequity.cn/v1/ping
curl.exe -sS --connect-timeout 15 https://infoequity.cn/v1/common/appconfig
curl.exe -I --http1.1 --connect-timeout 15 -H "Connection: Upgrade" -H "Upgrade: websocket" https://infoequity.cn/ws
```

Expected: no output redirects to or contains `infoequity.qingyunshe.top` or `wemx.cc`; API ping succeeds; WSS endpoint does not redirect to an old domain.
