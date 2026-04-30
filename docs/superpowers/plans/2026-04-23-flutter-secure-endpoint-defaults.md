# Flutter Secure Endpoint Defaults Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Switch the Flutter client defaults from raw-IP plaintext endpoints to
the production domain and TLS-backed API entrypoint without changing the current
server route-discovery contract.

**Architecture:** This plan keeps the existing `ApiConfig` surface, updates only
the shipped default constants, and proves the change through existing targeted
tests. Session gateway security comes from the existing `buildSessionGatewayUri`
mapping once `baseUrl` becomes `https://wemx.cc`.

**Tech Stack:** Flutter, Dart, flutter_test

---

## File Structure And Ownership

- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\core\config\api_config.dart`
  Responsibility: secure default API and IM bootstrap constants
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\core\config\api_config_test.dart`
  Responsibility: assert secure defaults and preserved runtime override
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\service\im\im_service_test.dart`
  Responsibility: assert `wss://wemx.cc` session gateway construction
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\wk_foundation\net\wk_http_client_proxy_io_test.dart`
  Responsibility: assert proxy bypass remains correct for secure domain-hosted
  realtime requests

## Task 1: Lock The Desired Defaults In Tests

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\core\config\api_config_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\service\im\im_service_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\wk_foundation\net\wk_http_client_proxy_io_test.dart`

- [ ] **Step 1: Update the `ApiConfig` default assertions**

```dart
expect(ApiConfig.devBaseUrl, 'https://wemx.cc');
expect(ApiConfig.prodBaseUrl, 'https://wemx.cc');
expect(ApiConfig.devWsAddr, 'wemx.cc:5100');
expect(ApiConfig.prodWsAddr, 'wemx.cc:5100');
expect(ApiConfig.baseUrl, 'https://wemx.cc');
expect(ApiConfig.wsAddr, 'wemx.cc:5100');
```

- [ ] **Step 2: Update the runtime-override test to keep only the persisted API override behavior**

```dart
expect(ApiConfig.baseUrl, 'https://wemx.cc');
await StorageUtils.setString(
  AppConstants.keyAuthLoginApiBaseUrl,
  'http://127.0.0.1:5001',
);
expect(ApiConfig.baseUrl, 'http://127.0.0.1:5001');
await StorageUtils.remove(AppConstants.keyAuthLoginApiBaseUrl);
expect(ApiConfig.baseUrl, 'https://wemx.cc');
```

- [ ] **Step 3: Update the session gateway expectation**

```dart
expect(
  uri.toString(),
  'wss://wemx.cc/v1/realtime/session/events/ws?device_session_id=device_session_01&last_acked_seq=0',
);
```

- [ ] **Step 4: Update the native proxy bypass test fixture**

```dart
shouldBypassNativeProxyForUri(
  apiBaseUri: Uri.parse('https://wemx.cc'),
  requestUri: Uri.parse(
    'wss://wemx.cc/v1/realtime/session/events/ws',
  ),
)
```

- [ ] **Step 5: Run the targeted tests and verify they fail on the old implementation**

Run:

```powershell
flutter test .\test\core\config\api_config_test.dart .\test\service\im\im_service_test.dart .\test\wk_foundation\net\wk_http_client_proxy_io_test.dart
```

Expected:
- Failures show the old insecure defaults are still present in `ApiConfig`.

## Task 2: Implement The Minimal Default Hardening

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\core\config\api_config.dart`

- [ ] **Step 1: Update the default API base URL constants**

```dart
static const String devBaseUrl = String.fromEnvironment(
  'WK_DEV_BASE_URL',
  defaultValue: 'https://wemx.cc',
);
static const String prodBaseUrl = String.fromEnvironment(
  'WK_PROD_BASE_URL',
  defaultValue: 'https://wemx.cc',
);
```

- [ ] **Step 2: Update the default IM bootstrap address constants**

```dart
static const String devWsAddr = String.fromEnvironment(
  'WK_DEV_WS_ADDR',
  defaultValue: 'wemx.cc:5100',
);
static const String prodWsAddr = String.fromEnvironment(
  'WK_PROD_WS_ADDR',
  defaultValue: 'wemx.cc:5100',
);
```

- [ ] **Step 3: Keep all runtime override and URL normalization behavior unchanged**

```dart
static String get baseUrl {
  final runtimeOverride = _normalizeRuntimeBaseUrl(
    StorageUtils.getString(AppConstants.keyAuthLoginApiBaseUrl),
  );
  if (runtimeOverride.isNotEmpty) {
    return runtimeOverride;
  }
  return AppConfig.isDevelopment ? devBaseUrl : prodBaseUrl;
}
```

- [ ] **Step 4: Re-run the targeted tests**

Run:

```powershell
flutter test .\test\core\config\api_config_test.dart .\test\service\im\im_service_test.dart .\test\wk_foundation\net\wk_http_client_proxy_io_test.dart
```

Expected:
- All targeted tests pass.

- [ ] **Step 5: Run lightweight static verification on the touched files**

Run:

```powershell
dart analyze .\lib\core\config\api_config.dart .\test\core\config\api_config_test.dart .\test\service\im\im_service_test.dart .\test\wk_foundation\net\wk_http_client_proxy_io_test.dart
```

Expected:
- No analyzer errors in the touched files.

## Task 3: Prepare The Next Remote Remediation Gate

**Files:**
- No code changes in this task

- [ ] **Step 1: Summarize what this local slice did not change**

```text
- IM route discovery still reads tcp_addr from /v1/users/{uid}/im
- server-rendered configs still need remote backup and approval-gated edits
- nginx/http redirect hardening still requires a separate restart-approved change
```

- [ ] **Step 2: List the approval-gated remote P0 follow-up**

```text
1. Backup nginx template and rendered config files on ubuntu@42.194.218.158
2. Change public defaults to force https/wss domain-based ingress
3. Present reload/restart plan and wait for Approve
```

- [ ] **Step 3: Report verification evidence**

```text
- flutter test target set: pass
- dart analyze touched files: pass
```
