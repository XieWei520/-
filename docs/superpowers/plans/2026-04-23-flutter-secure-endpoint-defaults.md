# Flutter Secure Endpoint Defaults Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Switch the Flutter client's shipped defaults from the raw production IP and plaintext API endpoint to the production domain and TLS-backed API origin, while preserving existing runtime override behavior and leaving the backend contract unchanged.

**Architecture:** This slice keeps the existing `ApiConfig` and `IMService` APIs intact and changes only the default constant values and the tests that pin them. Session realtime traffic becomes `wss://` automatically through the existing `buildSessionGatewayUri()` scheme mapping once `ApiConfig.baseUrl` defaults to `https://wemx.cc`.

**Tech Stack:** Flutter, Dart, flutter_test

---

## File Structure

- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\flutter-secure-endpoint-defaults-plan\lib\core\config\api_config.dart`
  Responsibility: define the default API base URL and IM bootstrap fallback address
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\flutter-secure-endpoint-defaults-plan\test\core\config\api_config_test.dart`
  Responsibility: lock the secure default endpoint behavior and the persisted override behavior
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\flutter-secure-endpoint-defaults-plan\test\service\im\im_service_test.dart`
  Responsibility: prove the existing session gateway helper now resolves to `wss://wemx.cc/...`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\flutter-secure-endpoint-defaults-plan\test\wk_foundation\net\wk_http_client_proxy_io_test.dart`
  Responsibility: prove proxy-bypass logic still treats the secure domain-hosted realtime endpoint as direct

### Task 1: Codify The Secure Defaults In Tests

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\flutter-secure-endpoint-defaults-plan\test\core\config\api_config_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\flutter-secure-endpoint-defaults-plan\test\service\im\im_service_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\flutter-secure-endpoint-defaults-plan\test\wk_foundation\net\wk_http_client_proxy_io_test.dart`

- [ ] **Step 1: Rewrite the `ApiConfig` default assertions to the secure production domain**

```dart
group('ApiConfig defaults', () {
  test('point to the secure production domain by default', () {
    expect(ApiConfig.devBaseUrl, 'https://wemx.cc');
    expect(ApiConfig.prodBaseUrl, 'https://wemx.cc');
    expect(ApiConfig.devWsAddr, 'wemx.cc:5100');
    expect(ApiConfig.prodWsAddr, 'wemx.cc:5100');
    expect(ApiConfig.baseUrl, 'https://wemx.cc');
    expect(ApiConfig.wsAddr, 'wemx.cc:5100');
  });
```

- [ ] **Step 2: Keep the persisted API-base override test, but make the fallback secure**

```dart
test(
  'uses persisted auth login API base URL override when present',
  () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageUtils.init();

    expect(ApiConfig.baseUrl, 'https://wemx.cc');

    await StorageUtils.setString(
      AppConstants.keyAuthLoginApiBaseUrl,
      'http://127.0.0.1:5001',
    );
    expect(ApiConfig.baseUrl, 'http://127.0.0.1:5001');

    await StorageUtils.remove(AppConstants.keyAuthLoginApiBaseUrl);
    expect(ApiConfig.baseUrl, 'https://wemx.cc');
  },
);
```

- [ ] **Step 3: Change the session gateway expectation to `wss://wemx.cc`**

```dart
final uri = buildSessionGatewayUri(
  baseUrl: 'https://wemx.cc',
  deviceSessionId: 'device_session_01',
  lastAckedSeq: 0,
);

expect(uri.toString(), isNot(contains(':0/')));
expect(
  uri.toString(),
  'wss://wemx.cc/v1/realtime/session/events/ws?device_session_id=device_session_01&last_acked_seq=0',
);
```

- [ ] **Step 4: Change the proxy-bypass fixture to the secure domain-hosted realtime endpoint**

```dart
expect(
  shouldBypassNativeProxyForUri(
    apiBaseUri: Uri.parse('https://wemx.cc'),
    requestUri: Uri.parse(
      'wss://wemx.cc/v1/realtime/session/events/ws',
    ),
  ),
  isTrue,
);

expect(
  shouldBypassNativeProxyForUri(
    apiBaseUri: Uri.parse('https://wemx.cc'),
    requestUri: Uri.parse(
      'https://wemx.cc:0/v1/realtime/session/events/ws',
    ),
  ),
  isTrue,
);
```

- [ ] **Step 5: Run the targeted tests to verify the old implementation fails**

Run:

```powershell
flutter test .\test\core\config\api_config_test.dart .\test\service\im\im_service_test.dart .\test\wk_foundation\net\wk_http_client_proxy_io_test.dart
```

Expected:
- `api_config_test.dart` fails because the code still defaults to `http://42.194.218.158`
- `im_service_test.dart` fails because `buildSessionGatewayUri()` still receives `http://42.194.218.158` in the fixture
- `wk_http_client_proxy_io_test.dart` may already pass because it validates host/scheme matching logic rather than `ApiConfig` defaults

- [ ] **Step 6: Commit the test-only expectation update**

```powershell
git add .\test\core\config\api_config_test.dart .\test\service\im\im_service_test.dart .\test\wk_foundation\net\wk_http_client_proxy_io_test.dart
git commit -m "test: codify secure endpoint defaults"
```

### Task 2: Implement The Minimal Default Hardening In `ApiConfig`

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\flutter-secure-endpoint-defaults-plan\lib\core\config\api_config.dart`
- Verify with: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\flutter-secure-endpoint-defaults-plan\test\core\config\api_config_test.dart`
- Verify with: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\flutter-secure-endpoint-defaults-plan\test\service\im\im_service_test.dart`
- Verify with: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\flutter-secure-endpoint-defaults-plan\test\wk_foundation\net\wk_http_client_proxy_io_test.dart`

- [ ] **Step 1: Replace the default API base URL constants with the production HTTPS domain**

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

- [ ] **Step 2: Replace the default IM bootstrap fallback with the production domain host**

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

- [ ] **Step 3: Leave the persisted runtime override path untouched**

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

- [ ] **Step 4: Re-run the focused test set and verify the feature passes**

Run:

```powershell
flutter test .\test\core\config\api_config_test.dart .\test\service\im\im_service_test.dart .\test\wk_foundation\net\wk_http_client_proxy_io_test.dart
```

Expected:
- All targeted tests pass
- The session gateway test now resolves to `wss://wemx.cc/...`

- [ ] **Step 5: Run lightweight static verification on the touched files**

Run:

```powershell
dart analyze .\lib\core\config\api_config.dart .\test\core\config\api_config_test.dart .\test\service\im\im_service_test.dart .\test\wk_foundation\net\wk_http_client_proxy_io_test.dart
```

Expected:
- No analyzer errors in the touched files

- [ ] **Step 6: Commit the default hardening change**

```powershell
git add .\lib\core\config\api_config.dart .\test\core\config\api_config_test.dart .\test\service\im\im_service_test.dart .\test\wk_foundation\net\wk_http_client_proxy_io_test.dart
git commit -m "feat: default Flutter endpoints to secure domain"
```

### Task 3: Capture Verification Evidence And Hold The Remote Boundary

**Files:**
- No code changes in this task

- [ ] **Step 1: Record the completed local evidence for this slice**

```text
- flutter pub get completed in the isolated worktree
- flutter test .\test\core\config\api_config_test.dart .\test\service\im\im_service_test.dart .\test\wk_foundation\net\wk_http_client_proxy_io_test.dart passed after the implementation
- dart analyze .\lib\core\config\api_config.dart .\test\core\config\api_config_test.dart .\test\service\im\im_service_test.dart .\test\wk_foundation\net\wk_http_client_proxy_io_test.dart passed
```

- [ ] **Step 2: Record the explicit non-goals so later slices do not assume they shipped here**

```text
- /v1/users/{uid}/im route-discovery contract is unchanged in this slice
- no nginx, Docker, or remote server config changes are made here
- no production restart or reload is required for this Flutter-only default change
```

- [ ] **Step 3: Commit any final evidence note only if a new artifact file is added**

```powershell
git status --short
```

Expected:
- No unstaged implementation changes remain
- If no artifact file was added, do not create an empty commit
