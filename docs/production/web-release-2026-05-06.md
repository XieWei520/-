# Web Release 2026-05-06

## Release summary

- Release type: Flutter Web production release
- Public URL: https://infoequity.qingyunshe.top/
- Deployment time: 2026-05-06 08:06 Asia/Shanghai
- Branch at release: codex/customer-service-entry-personal-routing
- Remote host: ubuntu@42.194.218.158
- Remote root: /opt/wukongim-prod/src/deploy/production
- Published directory: /opt/wukongim-prod/src/deploy/production/nginx/html

## Build artifact

- Local build directory: C:\Users\COLORFUL\Desktop\WuKong\build\web
- main.dart.js size: 7,092,749 bytes
- main.dart.js SHA256: 02e1b8f47608ab0901861c045af7a4fa78e06358a1c803171be2085934b55048

## Deployment command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ops\deploy_flutter_web_release.ps1 `
  -Server ubuntu@42.194.218.158 `
  -BuildWebDir build\web `
  -RemoteRoot /opt/wukongim-prod/src/deploy/production
```

## Remote backup and rollback

- Backup directory: /opt/wukongim-prod/src/deploy/production/backup/web-release-20260506080501

Rollback command:

```bash
ssh ubuntu@42.194.218.158 'cd /opt/wukongim-prod/src/deploy/production && cp /opt/wukongim-prod/src/deploy/production/backup/web-release-20260506080501/docker-compose.yaml docker-compose.yaml && rm -rf nginx/html && if [ -d /opt/wukongim-prod/src/deploy/production/backup/web-release-20260506080501/html ]; then cp -a /opt/wukongim-prod/src/deploy/production/backup/web-release-20260506080501/html nginx/html; fi && docker compose --env-file .env up -d --no-deps --force-recreate nginx'
```

## Verification evidence

### Pre-deploy local verification

```powershell
D:\Apps\flutter\bin\flutter.bat test test/web_dependency_wasm_policy_test.dart test/web_entrypoint_cache_cleanup_test.dart test/web_pwa_service_worker_test.dart test/data/cache/web_chat_cache_store_contract_test.dart test/data/cache/indexed_db_web_chat_cache_store_test.dart test/data/providers/chat_history_gateway_web_cache_test.dart test/data/providers/conversation_provider_test.dart test/service/im/im_service_web_policy_test.dart test/wukong_push/web_notification_integration_policy_test.dart test/wukong_push/web_notification_manager_stub_test.dart test/wukong_push/browser_notification_click_bridge_test.dart test/wukong_push/browser_notification_service_test.dart
# Result: 64 tests passed

D:\Apps\flutter\bin\flutter.bat analyze lib/data/cache lib/data/providers/chat_history_gateway.dart lib/data/providers/conversation_provider.dart lib/modules/conversation lib/realtime lib/wukong_push/notification web test/data/cache test/data/providers/chat_history_gateway_web_cache_test.dart test/wukong_push
# Result: No issues found

D:\Apps\flutter\bin\flutter.bat build web --release
# Result: Built build\web
```

### Deploy-time remote verification

- nginx recreated successfully.
- `docker exec <nginx-container> nginx -t`: configuration file syntax is ok; test is successful.
- Remote `sha256sum nginx/html/main.dart.js`: `02e1b8f47608ab0901861c045af7a4fa78e06358a1c803171be2085934b55048` (case-insensitive match).

### Public smoke checks

- `https://infoequity.qingyunshe.top/index.html`: HTTP 200, no-store/no-cache
- `https://infoequity.qingyunshe.top/flutter_bootstrap.js`: HTTP 200
- `https://infoequity.qingyunshe.top/main.dart.js`: HTTP 200, content-length 7,092,749
- `https://infoequity.qingyunshe.top/wk_pwa_service_worker.js`: HTTP 200

## Included functional fixes relevant to Web release

- Web read receipt refresh: visible message extra/read receipt updates without reopening the chat page.
- Web historical message cache: default Web direct history gateway now creates a Web cache store and uses active uid partitioning for cache reads/writes.
- Web IndexedDB cache files are included in source control so the release can be rebuilt from Git instead of relying on untracked local files.

## Release caveats

- This release is archived as a local Git commit in this workspace. Push the branch/tag to the remote repository before relying on another machine to reproduce the release.
- Browser clients may need Ctrl+F5 or a full refresh to discard stale JavaScript/service-worker-controlled resources.
