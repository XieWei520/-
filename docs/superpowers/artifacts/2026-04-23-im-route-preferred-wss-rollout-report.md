# 2026-04-23 IM Route Preferred WSS Rollout Report

## Scope

This report captures the completed Phase 2-4 work for formalizing the IM route
contract, enabling TCP/WS/WSS transport support in the local Flutter SDK, and
teaching the Flutter client to prefer the secure IM route end to end.

Date: 2026-04-23

Primary objective:

- turn `/v1/users/{uid}/im` into a stable multi-transport contract
- make the client truly prefer `wss_addr`
- preserve compatibility for older TCP-only clients

## Delivered Changes

### Phase 2: Server Contract And Protocol Routing

Remote server path:

- `/opt/wukongim-prod/src`

Remote rollback backup created before edits:

- `/opt/wukongim-prod/rollback_snapshots/task1_im_route_contract_20260423_140449`

Changed server files:

- `/opt/wukongim-prod/src/modules/user/im_route_contract.go`
- `/opt/wukongim-prod/src/modules/user/api_im_route_test.go`
- `/opt/wukongim-prod/src/modules/user/api.go`
- `/opt/wukongim-prod/src/modules/user/swagger/api.yaml`

Delivered server behavior:

- `/v1/users/{uid}/im` now returns the explicit contract fields:
  - `tcp_addr`
  - `ws_addr`
  - `wss_addr`
  - `preferred_transport`
  - `preferred_addr`
- `tcp_addr` is normalized as plain `host:port`
- `ws_addr` only survives when it is a valid `ws://...` URI
- `wss_addr` only survives when it is a valid `wss://...` URI
- invalid or missing upstream values normalize to empty strings
- preference order is server-controlled and currently resolves as:
  - `wss`
  - `ws`
  - `tcp`

Additional hardening completed after code review:

- upstream `uid` is now query-escaped before calling the IM route source
- regression test added for `u%26self` to prevent query-string corruption

### Phase 3: SDK Transport Layer

Local SDK path:

- `C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master`

Changed SDK files:

- `lib/manager/connection_transport.dart`
- `lib/manager/connect_manager.dart`
- `test/transport/connection_transport_test.dart`

Delivered SDK behavior:

- raw TCP `host:port` is supported
- `ws://...` is supported
- `wss://...` is supported
- connection manager now chooses transport from the resolved address form
- packet send/listen flow remains byte-oriented
- reconnect and heartbeat logic remain in the existing manager path
- websocket binary frames are converted into `Uint8List` and fed into the
  existing decode pipeline

### Phase 4: Flutter App Route Parsing And Selection

Flutter app worktree:

- `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\im-route-preferred-wss-contract`

Changed app files:

- `lib/service/api/im_route_info.dart`
- `lib/service/api/im_sync_api.dart`
- `lib/service/im/im_service.dart`
- `test/service/api/im_route_info_test.dart`
- `test/service/api/im_sync_api_test.dart`
- `test/service/im/im_service_test.dart`

Delivered app behavior:

- `/v1/users/{uid}/im` is now parsed into a typed `ImRouteInfo`
- app-side address selection now follows the formal contract order:
  1. valid `preferred_addr` matching `preferred_transport`
  2. valid `wss_addr`
  3. valid `ws_addr`
  4. valid `tcp_addr`
  5. local fallback `IMConfig.connectAddr`
- IM initialization now resolves the best available secure address instead of
  consuming only `tcp_addr`

Task 3 feature branch commit:

- `cbc42d9` `feat: parse IM route contract and prefer secure address`

## Verification Evidence

### Server

Commands executed in `golang:1.20` container with mounted source and caches:

- `go test ./modules/user -run TestBuildIMRouteResponse -count=1 -timeout 90s`
- `go test ./modules/user -run TestUserIM_ReturnsFormalContract -count=1 -timeout 90s`
- `go test ./modules/user -run TestUserIM_EncodesUIDForUpstreamQuery -count=1 -timeout 90s`

Result:

- all three passed

### SDK

Commands executed in the local SDK directory:

- `flutter test .\test\transport\connection_transport_test.dart .\test\db\message_identity_test.dart`

Result:

- all tests passed
- transport test coverage includes:
  - TCP parse
  - WS parse
  - WSS parse
  - malformed websocket rejection
  - websocket frame conversion
  - real websocket binary-frame delivery through the SDK transport

### Flutter App

Commands executed in the feature worktree:

- `flutter test .\test\service\api\im_route_info_test.dart .\test\service\api\im_sync_api_test.dart .\test\service\im\im_service_test.dart`
- `dart analyze .\lib\service\api\im_route_info.dart .\lib\service\api\im_sync_api.dart .\lib\service\im\im_service.dart .\test\service\api\im_route_info_test.dart .\test\service\api\im_sync_api_test.dart .\test\service\im\im_service_test.dart`

Result:

- targeted Flutter tests passed
- `dart analyze` reported `No issues found!`

## Approved Production Rollout

Approved restart scope:

1. rebuild and recreate only `tsdd-api`
2. do not restart `nginx`, `wukongim`, `mysql`, or `redis`
3. verify the production HTTPS route contract after rollout

Executed production command:

- `docker compose up -d --build --force-recreate tsdd-api`

Observed rollout behavior:

- `tsdd-api` image rebuilt successfully
- `wukongim_prod-tsdd-api-1` was recreated and started healthy
- supporting services remained running; they were checked for health but not
  rebuilt or recreated in this slice

## Production Verification

Production endpoint checked:

- `https://wemx.cc/v1/users/final_verify_probe/im`

Observed HTTP status:

- `200`

Observed JSON body:

```json
{"tcp_addr":"wemx.cc:5100","ws_addr":"ws://wemx.cc:5200","wss_addr":"wss://wemx.cc/ws","preferred_transport":"wss","preferred_addr":"wss://wemx.cc/ws"}
```

Production conclusion:

- the live API now serves the formal preferred-WSS contract over HTTPS

## Residual Items

Known non-blocking workspace noise:

- Flutter worktree still has unrelated generated plugin files modified:
  - `linux/flutter/generated_plugin_registrant.cc`
  - `linux/flutter/generated_plugin_registrant.h`
  - `linux/flutter/generated_plugins.cmake`
  - `macos/Flutter/GeneratedPluginRegistrant.swift`
  - `windows/flutter/generated_plugin_registrant.cc`
  - `windows/flutter/generated_plugin_registrant.h`
  - `windows/flutter/generated_plugins.cmake`
- pre-existing unrelated untracked items in the worktree were intentionally
  left alone:
  - `api_im_route_test.go.tmp`
  - `remote_task1/`
  - `run_task1_tests.sh`

Repository limitations encountered:

- remote server source tree under `/opt/wukongim-prod/src` is not a Git
  worktree
- local SDK directory under
  `C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master`
  is not a Git worktree
- because of that, server and SDK slices are tracked here by backup paths,
  direct file diffs, test evidence, and production verification rather than
  repository commits

## Final Status

Phase 2 status:

- completed

Phase 3 status:

- completed

Phase 4 status:

- completed

Overall result:

- the server contract, SDK transport layer, Flutter route parsing, and
  production rollout are now aligned on a client-preferred secure `wss_addr`
  contract with passing targeted verification across all three layers
