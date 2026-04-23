# Flutter Secure Endpoint Defaults Rollout

Date: 2026-04-23

## Scope

- move Flutter default API origin from raw-IP HTTP to `https://wemx.cc`
- move Flutter default IM bootstrap host from raw IP to `wemx.cc:5100`
- preserve persisted runtime override behavior
- do not change backend route contract in this slice

## Delivered Changes

- [api_config.dart](C:\Users\COLORFUL\Desktop\WuKong\.worktrees\flutter-secure-endpoint-defaults-plan\lib\core\config\api_config.dart)
  - `devBaseUrl` defaulted to `https://wemx.cc`
  - `prodBaseUrl` defaulted to `https://wemx.cc`
  - `devWsAddr` defaulted to `wemx.cc:5100`
  - `prodWsAddr` defaulted to `wemx.cc:5100`
- [api_config_test.dart](C:\Users\COLORFUL\Desktop\WuKong\.worktrees\flutter-secure-endpoint-defaults-plan\test\core\config\api_config_test.dart)
  - locked secure defaults and preserved runtime override expectations
- [im_service_test.dart](C:\Users\COLORFUL\Desktop\WuKong\.worktrees\flutter-secure-endpoint-defaults-plan\test\service\im\im_service_test.dart)
  - pinned realtime session gateway resolution to secure-domain behavior
- [wk_http_client_proxy_io_test.dart](C:\Users\COLORFUL\Desktop\WuKong\.worktrees\flutter-secure-endpoint-defaults-plan\test\wk_foundation\net\wk_http_client_proxy_io_test.dart)
  - verified proxy bypass still treats the secure realtime endpoint as direct

## Verification

Executed in `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\flutter-secure-endpoint-defaults-plan`:

```text
flutter test .\test\core\config\api_config_test.dart .\test\service\im\im_service_test.dart .\test\wk_foundation\net\wk_http_client_proxy_io_test.dart
Result: 29 tests passed

dart analyze .\lib\core\config\api_config.dart .\test\core\config\api_config_test.dart .\test\service\im\im_service_test.dart .\test\wk_foundation\net\wk_http_client_proxy_io_test.dart
Result: No issues found!
```

Observed verification notes:

- `flutter test` refreshed generated plugin registrant files under `linux/`, `macos/`, and `windows/`
- those generated files are workspace noise and should be restored before merge
- package-manager warnings about `file_picker` default plugin metadata were emitted, but tests still passed and analyzer stayed clean

## Non-Goals

- no `/v1/users/{uid}/im` contract change
- no nginx, Docker, or remote server change
- no production restart required
