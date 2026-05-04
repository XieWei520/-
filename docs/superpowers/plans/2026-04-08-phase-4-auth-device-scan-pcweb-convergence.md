# Phase 4 Auth, Device Sessions, Scan, And PC-Web Convergence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish Phase 4 by converging Flutter auth and PC/Web session flows onto one truthful production chain rooted in `lib/modules/auth/**` and `lib/service/api/login_bridge_api.dart`, then verify that chain against the live backend on `42.194.218.158`.

**Architecture:** This is a convergence plan, not a rewrite. The current `modules/auth` mainline already owns phone/password login, login verification, device sessions, and scan-driven Web confirmation, so the work here is to freeze the bridge contract with tests, demote false legacy owners under `lib/wukong_login/**`, clean in-scope mojibake, and validate the same contract against the deployed API container `wukongim_prod-tsdd-api-1`.

**Tech Stack:** Flutter, flutter_riverpod, go_router, Dio, flutter_test, PowerShell, SSH, Docker Compose, Go, TangSengDaoDaoServer backend

---

**Workspace Note:** This local copy does not contain `.git` metadata. Use the `git add` and `git commit` commands below only in a canonical checkout. In this copy, record the same checkpoints together with the exact verification output in your delivery notes.

## Scope Boundary

This plan implements the approved Phase 4 design at [2026-04-08-phase-4-auth-device-scan-pcweb-convergence-design.md](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/docs/superpowers/specs/2026-04-08-phase-4-auth-device-scan-pcweb-convergence-design.md).

In scope:

- phone/password login as the primary acceptance chain
- login verification follow-up when the backend requires it
- device-session list, delete, and quit-all-PC/Web flow
- scan login-confirm routing into `AuthWebLoginConfirmPage`
- wrapper-only legacy ownership under `lib/wukong_login/**`
- honest live-backend validation on `42.194.218.158`
- backend changes only if the deployed API blocks the Flutter owner chain

Out of scope:

- third-party login product completion
- unrelated chat, contacts, settings, or call features
- broad backend refactors not tied to an observed Phase 4 blocker

## File Structure

### New Files

- `test/service/api/login_bridge_api_test.dart`
  - Locks the PC/Web bridge contract: login UUID, login status, grant-login failure handling, and device-session payload parsing.
- `test/wukong_login/pc_login_service_test.dart`
  - Proves `pc_login_service.dart` is only a compatibility facade over `LoginBridgeApi`.
- `test/modules/auth/auth_copy_test.dart`
  - Locks the corrected auth-facing copy so mojibake cannot re-enter the active product path.

### Existing Flutter Files To Modify

- `lib/service/api/login_bridge_api.dart`
  - Remains the exclusive owner for login UUID, login status, Web login grant, device list, delete-device, and quit-PC/Web.
- `lib/modules/auth/application/device_session_controller.dart`
  - Keeps device-session retries and recovery honest after delete and quit-all failures.
- `lib/modules/auth/presentation/pages/auth_device_sessions_page.dart`
  - Presents the truthful device-session chain with readable copy and stable retry behavior.
- `lib/modules/auth/presentation/pages/auth_web_login_confirm_page.dart`
  - Confirms Web login through `AuthRepositoryImpl -> LoginBridgeApi`.
- `lib/modules/auth/presentation/pages/auth_login_verification_page.dart`
  - Keeps the in-scope login-verification page readable after text cleanup.
- `lib/modules/auth/presentation/pages/auth_third_login_page.dart`
  - Cleans text only if the route remains reachable; no product-completeness work is added.
- `lib/modules/auth/presentation/widgets/auth_copy.dart`
  - Centralizes clean auth copy for the active login/register/reset path.
- `lib/service/api/common_api.dart`
  - Cleans runtime-capability status text so auth/session gating messages are readable.
- `lib/wukong_scan/scan_result_page.dart`
  - Keeps scan routing as the owner, but with readable login-confirm text and no duplicate auth logic.
- `lib/wukong_login/pc_login_service.dart`
  - Must end as a deprecated compatibility facade, not a stub-heavy production owner.
- `test/modules/auth/auth_device_sessions_web_login_test.dart`
  - Extends UI coverage for confirm, delete-device, and quit-all flows.
- `test/modules/auth/auth_routes_compile_test.dart`
  - Continues proving `wukong_login/**` pages are wrappers only.
- `test/service/api/common_api_test.dart`
  - Updates capability-message assertions after mojibake cleanup.

### Conditional Backend Files To Modify Only If Live Validation Fails

- `/opt/wukongim-prod/src/modules/user/api.go`
  - Live production source for `/v1/user/loginuuid`, `/v1/user/loginstatus`, `/v1/user/login_authcode/:auth_code`, and `/v1/user/grant_login`.
- `/opt/wukongim-prod/src/modules/user/api_device.go`
  - Live production source for `/v1/user/devices`, `/v1/user/devices/:device_id`, and the `self` device marker.
- `/opt/wukongim-prod/src/deploy/production/docker-compose.yaml`
  - Production compose entry used to rebuild the `tsdd-api` service if a backend patch is required.
- `/home/ubuntu/tsdd-task1-repo/TangSengDaoDaoServer-main/modules/user/api.go`
- `/home/ubuntu/tsdd-task1-repo/TangSengDaoDaoServer-main/modules/user/api_device.go`
  - Mirror reference checkout on the server; keep it aligned only after the production source patch is confirmed.

## Verification Commands Used Throughout

- `flutter analyze lib/modules/auth lib/wukong_login lib/wukong_scan lib/service/api/login_bridge_api.dart lib/service/api/common_api.dart lib/app/navigation`
- `flutter test test/service/api/login_bridge_api_test.dart`
- `flutter test test/modules/auth/auth_device_sessions_web_login_test.dart`
- `flutter test test/modules/auth/auth_routes_compile_test.dart`
- `flutter test test/modules/auth/auth_copy_test.dart`
- `flutter test test/wukong_login/pc_login_service_test.dart`
- `flutter test test/modules/auth/auth_login_page_test.dart test/modules/auth/auth_register_reset_page_test.dart test/modules/auth/auth_verification_profile_flow_test.dart test/modules/auth/auth_bootstrap_coordinator_test.dart`
- `flutter test test/wukong_scan/scan_service_test.dart`
- `ssh -F NUL ubuntu@42.194.218.158 "hostname && docker ps --format '{{.Names}}' | grep wukongim_prod-tsdd-api-1"`
- `ssh -F NUL ubuntu@42.194.218.158 "docker logs --since 10m wukongim_prod-tsdd-api-1 | grep -E '/v1/user/login|/v1/user/sms/login_check_phone|/v1/user/login/check_phone|/v1/user/devices|/v1/user/pc/quit|/v1/user/loginuuid|/v1/user/loginstatus|/v1/user/grant_login'"`

### Task 1: Lock `LoginBridgeApi` As The Only Bridge Owner

**Files:**
- Create: `test/service/api/login_bridge_api_test.dart`
- Modify: `lib/service/api/login_bridge_api.dart`

- [ ] **Step 1: Write the failing bridge contract tests**

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/login_bridge_api.dart';

void main() {
  group('LoginBridgeApi', () {
    test('getDevices reads the direct list payload returned by the live backend', () async {
      final adapter = _RecordingPlainAdapter(
        payload: const <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 7,
            'device_id': 'desktop-7',
            'device_name': 'MacBook Pro（本机）',
            'device_model': 'macOS',
            'last_login': '2026-04-08 09:00',
            'self': 1,
          },
        ],
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;

      final devices = await LoginBridgeApi.instance.getDevices();

      expect(adapter.lastRequestOptions?.path, '/v1/user/devices');
      expect(devices.single.deviceId, 'desktop-7');
      expect(devices.single.deviceName, 'MacBook Pro（本机）');
      expect(devices.single.self, isTrue);
    });

    test('grantLogin throws on business failure even when HTTP is 200', () async {
      ApiClient.instance.dio.httpClientAdapter = _RecordingPlainAdapter(
        payload: const <String, dynamic>{
          'code': 1,
          'msg': '授权码失效或不存在！',
        },
      );

      await expectLater(
        () => LoginBridgeApi.instance.grantLogin('bad-auth', encrypt: 'enc-1'),
        throwsA(
          predicate(
            (error) => error.toString().contains('授权码失效或不存在！'),
          ),
        ),
      );
    });

    test('deleteDevice rejects blank ids before touching the network', () async {
      final adapter = _RecordingPlainAdapter(
        payload: const <String, dynamic>{'code': 0},
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await expectLater(
        () => LoginBridgeApi.instance.deleteDevice('   '),
        throwsA(predicate((error) => error.toString().contains('设备 ID 不能为空'))),
      );
      expect(adapter.lastRequestOptions, isNull);
    });
  });
}

class _RecordingPlainAdapter implements HttpClientAdapter {
  _RecordingPlainAdapter({required this.payload});

  final Object payload;
  RequestOptions? lastRequestOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequestOptions = options;
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
```

- [ ] **Step 2: Run the bridge tests to verify they fail**

Run: `flutter test test/service/api/login_bridge_api_test.dart`
Expected: FAIL with missing test file or with current fallback/error parsing not matching the asserted live-backend contract

- [ ] **Step 3: Tighten response normalization in `login_bridge_api.dart`**

```dart
String _messageOf(Map<String, dynamic> body, String fallbackMessage) {
  final raw = (body['msg'] ?? body['message'] ?? fallbackMessage)
      .toString()
      .trim();
  return raw.isEmpty ? fallbackMessage : raw;
}

bool _readBoolLike(dynamic rawValue) {
  if (rawValue is bool) {
    return rawValue;
  }
  if (rawValue is num) {
    return rawValue.toInt() != 0;
  }
  final normalized = rawValue?.toString().trim().toLowerCase() ?? '';
  return normalized == '1' || normalized == 'true';
}

void _throwIfFailed(
  Response<dynamic> response, {
  required String fallbackMessage,
}) {
  final body = _normalizeResponseData(response.data);
  final statusCode = response.statusCode ?? 200;
  final code = body['code'];
  final status = body['status'];
  final message = _messageOf(body, fallbackMessage);
  final hasErrorCode =
      (code is num && code.toInt() != 0) ||
      (status is num && status.toInt() >= 400);
  if (statusCode >= 400 || hasErrorCode) {
    throw Exception(message);
  }
}

factory LoginBridgeDeviceRecord.fromJson(Map<String, dynamic> json) {
  return LoginBridgeDeviceRecord(
    id: (json['id'] as num?)?.toInt() ?? 0,
    deviceId: (json['device_id'] ?? '').toString(),
    deviceName: (json['device_name'] ?? '未知设备').toString(),
    deviceModel: (json['device_model'] ?? '').toString(),
    lastLogin: (json['last_login'] ?? '').toString(),
    self: _readBoolLike(json['self']),
  );
}
```

- [ ] **Step 4: Re-run the bridge contract checks**

Run: `flutter test test/service/api/login_bridge_api_test.dart`
Expected: PASS with `getDevices`, `grantLogin`, and `deleteDevice` contract coverage green

Run: `flutter analyze lib/service/api/login_bridge_api.dart test/service/api/login_bridge_api_test.dart`
Expected: PASS with bridge-owner code analyzer clean

- [ ] **Step 5: Checkpoint**

```bash
git add lib/service/api/login_bridge_api.dart test/service/api/login_bridge_api_test.dart
git commit -m "test: lock login bridge api contract"
```

### Task 2: Freeze The `AuthRepository -> Controller -> Page` Session Chain

**Files:**
- Modify: `lib/modules/auth/application/device_session_controller.dart`
- Modify: `lib/modules/auth/presentation/pages/auth_web_login_confirm_page.dart`
- Modify: `test/modules/auth/auth_device_sessions_web_login_test.dart`

- [ ] **Step 1: Extend the failing UI tests for confirm, delete, and quit-all**

```dart
class _TrackingAuthRepository implements AuthRepository {
  _TrackingAuthRepository({
    List<LoginBridgeDeviceRecord>? initialDevices,
  }) : _devices = List<LoginBridgeDeviceRecord>.from(
         initialDevices ??
             const <LoginBridgeDeviceRecord>[
               LoginBridgeDeviceRecord(
                 id: 1,
                 deviceId: 'desktop-1',
                 deviceName: 'MacBook Pro',
                 deviceModel: 'macOS',
                 lastLogin: '2026-04-08 10:00',
                 self: false,
               ),
             ],
       );

  final List<LoginBridgeDeviceRecord> _devices;
  final List<String> calls = <String>[];
  String? grantedAuthCode;
  String? grantedEncrypt;
  bool failQuitAllOnce = false;

  @override
  Future<void> grantWebLogin({
    required String authCode,
    String? encrypt,
  }) async {
    calls.add('grant');
    grantedAuthCode = authCode;
    grantedEncrypt = encrypt;
  }

  @override
  Future<List<LoginBridgeDeviceRecord>> loadDevices() async {
    calls.add('load');
    return List<LoginBridgeDeviceRecord>.from(_devices);
  }

  @override
  Future<void> deleteDevice(String deviceId) async {
    calls.add('delete:$deviceId');
    _devices.removeWhere((item) => item.deviceId == deviceId);
  }

  @override
  Future<void> quitPcWebSessions() async {
    calls.add('quit-all');
    if (failQuitAllOnce) {
      failQuitAllOnce = false;
      throw Exception('quit failed');
    }
    _devices.removeWhere((item) => !item.self);
  }

  @override
  Future<AuthCredentialResult> loginWithPhone({
    required String zone,
    required String phone,
    required String password,
  }) async => const AuthCredentialResult.failure('unused');

  @override
  Future<AuthCredentialResult> loginWithUsername({
    required String username,
    required String password,
  }) async => const AuthCredentialResult.failure('unused');

  @override
  Future<AuthCredentialResult> registerWithPhone({
    required String zone,
    required String phone,
    required String code,
    required String password,
    String? inviteCode,
  }) async => const AuthCredentialResult.failure('unused');

  @override
  Future<void> sendRegisterCode({required String zone, required String phone}) async {}

  @override
  Future<void> sendLoginVerificationCode(String uid) async {}

  @override
  Future<AuthCredentialResult> verifyLoginCode({
    required String uid,
    required String code,
  }) async => const AuthCredentialResult.failure('unused');

  @override
  Future<void> sendResetPasswordCode({
    required String zone,
    required String phone,
  }) async {}

  @override
  Future<void> resetPassword({
    required String zone,
    required String phone,
    required String code,
    required String newPassword,
  }) async {}

  @override
  Future<UserInfo> completeProfile({
    required String name,
    int? sex,
    String? avatarFilePath,
  }) async => UserInfo(uid: 'u-1', token: 't-1', name: name);

  @override
  Future<String> loadThirdLoginAuthCode() async => 'unused';

  @override
  Future<ThirdLoginStatusResult> loadThirdLoginStatus(String authCode) async =>
      const ThirdLoginStatusResult(status: 0);

  @override
  Future<AuthCredentialResult> loginWithThirdPartyAuthCode(String authCode) async =>
      const AuthCredentialResult.failure('unused');

  @override
  Future<UserInfo?> getCurrentUser() async => null;
}

testWidgets('web login confirm passes authCode and encrypt to repository', (tester) async {
  final repository = _TrackingAuthRepository();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        home: AuthWebLoginConfirmPage(
          authCode: 'auth-1',
          encrypt: 'enc-1',
        ),
      ),
    ),
  );

  await tester.tap(find.byKey(const ValueKey('auth-web-login-confirm')));
  await tester.pumpAndSettle();

  expect(repository.grantedAuthCode, 'auth-1');
  expect(repository.grantedEncrypt, 'enc-1');
}

testWidgets('device sessions page removes a remote device and reloads the list', (tester) async {
  final repository = _TrackingAuthRepository();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: AuthDeviceSessionsPage()),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('移除'));
  await tester.pumpAndSettle();

  expect(repository.calls, contains('delete:desktop-1'));
  expect(find.byKey(const ValueKey('auth-device-desktop-1')), findsNothing);
}

testWidgets('quit-all failure clears on retry instead of leaving the page stuck', (tester) async {
  final repository = _TrackingAuthRepository()..failQuitAllOnce = true;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: AuthDeviceSessionsPage()),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byType(FilledButton).first);
  await tester.pumpAndSettle();
  expect(find.textContaining('quit failed'), findsOneWidget);

  await tester.tap(find.byType(FilledButton).first);
  await tester.pumpAndSettle();
  expect(find.textContaining('quit failed'), findsNothing);
}
```

- [ ] **Step 2: Run the session-chain tests to verify they fail**

Run: `flutter test test/modules/auth/auth_device_sessions_web_login_test.dart`
Expected: FAIL because the current page/controller path does not yet prove the full confirm-delete-retry chain

- [ ] **Step 3: Make delete and quit-all retries explicitly recoverable**

```dart
Future<void> remove(String deviceId) async {
  state = state.copyWith(error: null);
  try {
    await _repository.deleteDevice(deviceId);
    await load();
  } catch (error) {
    state = state.copyWith(error: error.toString());
  }
}

@override
Widget build(BuildContext context) {
  final canSubmit = !_isSubmitting && widget.authCode.trim().isNotEmpty;
  return AuthFlowShell(
    title: '确认 Web 登录',
    subtitle: '检测到来自 PC/Web 的登录授权请求',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          key: const ValueKey('auth-web-login-confirm'),
          onPressed: canSubmit ? _confirmLogin : null,
          child: Text(_isSubmitting ? '确认中...' : '确认登录'),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 4: Re-run the focused auth session tests**

Run: `flutter test test/modules/auth/auth_device_sessions_web_login_test.dart`
Expected: PASS with repository handoff, delete refresh, and quit-all retry behavior green

Run: `flutter analyze lib/modules/auth/application/device_session_controller.dart lib/modules/auth/presentation/pages/auth_web_login_confirm_page.dart test/modules/auth/auth_device_sessions_web_login_test.dart`
Expected: PASS with the owner-chain changes analyzer clean

- [ ] **Step 5: Checkpoint**

```bash
git add lib/modules/auth/application/device_session_controller.dart lib/modules/auth/presentation/pages/auth_web_login_confirm_page.dart test/modules/auth/auth_device_sessions_web_login_test.dart
git commit -m "test: freeze auth device session owner chain"
```

### Task 3: Demote `pc_login_service.dart` To A Compatibility Facade

**Files:**
- Create: `test/wukong_login/pc_login_service_test.dart`
- Modify: `lib/wukong_login/pc_login_service.dart`
- Modify: `test/modules/auth/auth_routes_compile_test.dart`

- [ ] **Step 1: Write the failing compatibility-facade tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/api/login_bridge_api.dart';
import 'package:wukong_im_app/wukong_login/pc_login_service.dart';

void main() {
  test('requestPCLoginQRCode delegates to LoginBridgeApi.getLoginUuid', () async {
    final service = PCLoginService(
      requestLoginUuid: () async => const LoginUuidResult(
        uuid: 'uuid-1',
        qrcode: 'https://example.com/qr/uuid-1',
      ),
      pollLoginStatus: (_) async => const LoginStatusResult(
        status: 'authed',
        authCode: 'auth-1',
      ),
      loadDevices: () async => const <LoginBridgeDeviceRecord>[
        LoginBridgeDeviceRecord(
          id: 1,
          deviceId: 'desktop-1',
          deviceName: 'MacBook Pro（本机）',
          deviceModel: 'macOS',
          lastLogin: '2026-04-08 10:00',
          self: true,
        ),
      ],
      deleteDevice: (_) async {},
      quitPcWeb: () async {},
      pollInterval: const Duration(milliseconds: 1),
    );

    final scene = await service.requestPCLoginQRCode();
    final sessions = await service.getSessions();

    expect(scene, 'uuid-1');
    expect(sessions.single.deviceId, 'desktop-1');
    expect(sessions.single.deviceType, 'macOS');
  });

  test('logoutAllSessions and logoutSession delegate to bridge callbacks', () async {
    final calls = <String>[];
    final service = PCLoginService(
      requestLoginUuid: () async => const LoginUuidResult(
        uuid: 'uuid-1',
        qrcode: 'https://example.com/qr/uuid-1',
      ),
      pollLoginStatus: (_) async => const LoginStatusResult(status: 'waitScan'),
      loadDevices: () async => const <LoginBridgeDeviceRecord>[],
      deleteDevice: (deviceId) async => calls.add('delete:$deviceId'),
      quitPcWeb: () async => calls.add('quit-all'),
    );

    await service.logoutSession('desktop-9');
    await service.logoutAllSessions();

    expect(calls, <String>['delete:desktop-9', 'quit-all']);
  });
}
```

- [ ] **Step 2: Run the compatibility tests to verify they fail**

Run: `flutter test test/wukong_login/pc_login_service_test.dart`
Expected: FAIL because the current service is still stub-heavy and non-injectable

- [ ] **Step 3: Replace the stub owner with a deprecated facade over `LoginBridgeApi`**

```dart
import 'dart:async';
import 'dart:convert';

import '../service/api/login_bridge_api.dart';

typedef RequestLoginUuid = Future<LoginUuidResult> Function();
typedef PollLoginStatus = Future<LoginStatusResult> Function(String uuid);
typedef LoadDevices = Future<List<LoginBridgeDeviceRecord>> Function();
typedef DeleteDevice = Future<void> Function(String deviceId);
typedef QuitPcWeb = Future<void> Function();

@Deprecated('Use AuthRepositoryImpl and LoginBridgeApi from lib/modules/auth instead.')
class PCLoginService {
  PCLoginService({
    RequestLoginUuid? requestLoginUuid,
    PollLoginStatus? pollLoginStatus,
    LoadDevices? loadDevices,
    DeleteDevice? deleteDevice,
    QuitPcWeb? quitPcWeb,
    Duration pollInterval = const Duration(seconds: 2),
  }) : _requestLoginUuid =
           requestLoginUuid ?? (() => LoginBridgeApi.instance.getLoginUuid()),
       _pollLoginStatus =
           pollLoginStatus ?? ((uuid) => LoginBridgeApi.instance.getLoginStatus(uuid)),
       _loadDevices = loadDevices ?? (() => LoginBridgeApi.instance.getDevices()),
       _deleteDevice =
           deleteDevice ?? ((deviceId) => LoginBridgeApi.instance.deleteDevice(deviceId)),
       _quitPcWeb = quitPcWeb ?? (() => LoginBridgeApi.instance.quitPc()),
       _pollInterval = pollInterval;

  final RequestLoginUuid _requestLoginUuid;
  final PollLoginStatus _pollLoginStatus;
  final LoadDevices _loadDevices;
  final DeleteDevice _deleteDevice;
  final QuitPcWeb _quitPcWeb;
  final Duration _pollInterval;

  Timer? _pollingTimer;
  Function(bool success, String? authCode)? onLoginStatusChanged;

  Future<String> requestPCLoginQRCode() async {
    final result = await _requestLoginUuid();
    return result.uuid;
  }

  void startPollingLoginStatus(String scene) {
    stopPollingLoginStatus();
    _pollingTimer = Timer.periodic(_pollInterval, (timer) async {
      final result = await _pollLoginStatus(scene);
      if (!result.isAuthed) {
        return;
      }
      stopPollingLoginStatus();
      onLoginStatusChanged?.call(true, result.authCode);
    });
  }

  void stopPollingLoginStatus() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> logoutAllSessions() => _quitPcWeb();

  Future<void> logoutSession(String deviceId) => _deleteDevice(deviceId);

  Future<List<PCSessionInfo>> getSessions() async {
    final devices = await _loadDevices();
    return devices
        .map(
          (device) => PCSessionInfo(
            deviceId: device.deviceId,
            deviceName: device.deviceName,
            deviceType: device.deviceModel,
            loginTime: 0,
            isMuted: false,
            isOnline: true,
          ),
        )
        .toList();
  }

  String generateQRCodeContent(String scene, String baseUrl) {
    return '$baseUrl/pc_login?scene=$scene';
  }

  String? parseQRCodeContent(String content) {
    try {
      final uri = Uri.parse(content);
      if (uri.queryParameters.containsKey('scene')) {
        return uri.queryParameters['scene'];
      }
      final json = jsonDecode(content) as Map<String, dynamic>;
      return json['scene']?.toString();
    } catch (_) {
      return null;
    }
  }
}
```

- [ ] **Step 4: Re-run the legacy-owner checks**

Run: `flutter test test/wukong_login/pc_login_service_test.dart test/modules/auth/auth_routes_compile_test.dart`
Expected: PASS with the legacy service reduced to a bridge-only facade and wrappers still compiling

Run: `Get-ChildItem -Recurse lib -Filter *.dart | Select-String -Pattern 'PCLoginService\\('`
Expected: output only from `lib/wukong_login/pc_login_service.dart` and any deliberate legacy-only tests, not from production auth/session owners

- [ ] **Step 5: Checkpoint**

```bash
git add lib/wukong_login/pc_login_service.dart test/wukong_login/pc_login_service_test.dart test/modules/auth/auth_routes_compile_test.dart
git commit -m "refactor: demote pc login service to compatibility facade"
```

### Task 4: Clean Mojibake In Active Auth And Scan Surfaces

**Files:**
- Create: `test/modules/auth/auth_copy_test.dart`
- Modify: `lib/modules/auth/presentation/widgets/auth_copy.dart`
- Modify: `lib/modules/auth/presentation/pages/auth_device_sessions_page.dart`
- Modify: `lib/modules/auth/presentation/pages/auth_web_login_confirm_page.dart`
- Modify: `lib/modules/auth/presentation/pages/auth_login_verification_page.dart`
- Modify: `lib/modules/auth/presentation/pages/auth_third_login_page.dart`
- Modify: `lib/service/api/common_api.dart`
- Modify: `lib/service/api/login_bridge_api.dart`
- Modify: `lib/wukong_scan/scan_result_page.dart`
- Modify: `test/service/api/common_api_test.dart`
- Modify: `test/modules/auth/auth_device_sessions_web_login_test.dart`

- [ ] **Step 1: Write the failing copy tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/auth/presentation/widgets/auth_copy.dart';

void main() {
  test('auth copy constants are readable UTF-8 strings', () {
    expect(AuthCopy.loginTitle, '欢迎登录悟空IM');
    expect(AuthCopy.loginButton, '登录');
    expect(AuthCopy.forgotPasswordEntry, '忘记密码');
    expect(AuthCopy.openPrivacyFailed, '无法打开隐私政策页面');
  });
}
```

```dart
testWidgets('scan login confirm shows readable copy', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      ],
      child: MaterialApp(
        home: ScanResultPage(
          result: ScanServiceResult.fromJson({
            'forward': 'native',
            'type': 'loginConfirm',
            'data': {'auth_code': 'auth-1', 'pub_key': 'enc-1'},
          }, 'raw-login-confirm'),
        ),
      ),
    ),
  );

  expect(find.text('检测到登录确认'), findsOneWidget);
  expect(find.text('确认登录'), findsOneWidget);
});
```

- [ ] **Step 2: Run the text-hygiene tests to verify they fail**

Run: `flutter test test/modules/auth/auth_copy_test.dart test/modules/auth/auth_device_sessions_web_login_test.dart test/service/api/common_api_test.dart`
Expected: FAIL because current auth/session strings still contain mojibake

- [ ] **Step 3: Replace the active auth and scan strings with readable copy**

```dart
class AuthCopy {
  AuthCopy._();

  static const String loginTitle = '欢迎登录悟空IM';
  static const String loginButton = '登录';
  static const String registerEntry = '注册';
  static const String registerButton = '注册';
  static const String forgotPasswordEntry = '忘记密码';
  static const String resetPasswordTitle = '验证您的手机号';
  static const String phoneHint = '请输入手机号';
  static const String codeHint = '请输入验证码';
  static const String passwordHint = '请输入密码';
  static const String getCodeButton = '获取验证码';
  static const String confirmButton = '确定';
  static const String agreementPrefix = '我已阅读并同意';
  static const String privacyPolicy = '《隐私政策》';
  static const String userAgreement = '《用户协议》';
  static const String areaCodePickerTitle = '选择国家或地区';
  static const String openPrivacyFailed = '无法打开隐私政策页面';
  static const String openAgreementFailed = '无法打开用户协议页面';
}
```

```dart
return AuthFlowShell(
  title: '登录设备管理',
  subtitle: '查看当前账号最近登录过的设备和会话',
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton.tonal(
        onPressed: state.isQuittingAll ? null : controller.quitAllPcWeb,
        child: Text(state.isQuittingAll ? '退出中...' : '退出全部 PC/Web 登录'),
      ),
    ],
  ),
);
```

```dart
return AuthFlowShell(
  title: '确认 Web 登录',
  subtitle: '检测到来自 PC/Web 的登录授权请求',
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: const [
      Text(
        '请确认是否允许当前 Web 或桌面端登录你的账号。',
        textAlign: TextAlign.center,
      ),
    ],
  ),
);
```

```dart
return AuthFlowShell(
  title: '登录验证',
  subtitle: '你正在一台新设备登录，需要完成安全验证后才能继续。',
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: const [
      Text('系统会向你的安全手机号发送验证码。'),
    ],
  ),
);
```

```dart
if (webLoginUrl.isEmpty) {
  return AppRuntimeCapabilities.fromAppConfigBody(
    body: body,
    webLoginReachable: false,
    webLoginStatusMessage: '服务端未返回 Web 登录地址',
  );
}
```

```dart
ScaffoldMessenger.of(
  context,
).showSnackBar(const SnackBar(content: Text('链接格式不正确。')));
```

- [ ] **Step 4: Re-run the text-hygiene suite**

Run: `flutter test test/modules/auth/auth_copy_test.dart test/modules/auth/auth_device_sessions_web_login_test.dart test/service/api/common_api_test.dart`
Expected: PASS with readable auth/session copy locked down

Run: `flutter analyze lib/modules/auth lib/service/api/common_api.dart lib/service/api/login_bridge_api.dart lib/wukong_scan/scan_result_page.dart`
Expected: PASS with cleaned strings analyzer clean

- [ ] **Step 5: Checkpoint**

```bash
git add lib/modules/auth/presentation/widgets/auth_copy.dart lib/modules/auth/presentation/pages/auth_device_sessions_page.dart lib/modules/auth/presentation/pages/auth_web_login_confirm_page.dart lib/modules/auth/presentation/pages/auth_login_verification_page.dart lib/modules/auth/presentation/pages/auth_third_login_page.dart lib/service/api/common_api.dart lib/service/api/login_bridge_api.dart lib/wukong_scan/scan_result_page.dart test/modules/auth/auth_copy_test.dart test/service/api/common_api_test.dart test/modules/auth/auth_device_sessions_web_login_test.dart
git commit -m "fix: clean auth and scan session copy"
```

### Task 5: Validate The Live Backend And Close Phase 4 Honestly

**Files:**
- Modify only if needed: `/opt/wukongim-prod/src/modules/user/api.go`
- Modify only if needed: `/opt/wukongim-prod/src/modules/user/api_device.go`
- Modify only if needed: `/home/ubuntu/tsdd-task1-repo/TangSengDaoDaoServer-main/modules/user/api.go`
- Modify only if needed: `/home/ubuntu/tsdd-task1-repo/TangSengDaoDaoServer-main/modules/user/api_device.go`

- [ ] **Step 1: Run the full local Phase 4 regression pack**

Run: `flutter analyze lib/modules/auth lib/wukong_login lib/wukong_scan lib/service/api/login_bridge_api.dart lib/service/api/common_api.dart lib/app/navigation`
Expected: PASS

Run: `flutter test test/service/api/login_bridge_api_test.dart test/modules/auth/auth_copy_test.dart test/modules/auth/auth_bootstrap_coordinator_test.dart test/modules/auth/auth_login_page_test.dart test/modules/auth/auth_register_reset_page_test.dart test/modules/auth/auth_verification_profile_flow_test.dart test/modules/auth/auth_device_sessions_web_login_test.dart test/modules/auth/auth_routes_compile_test.dart test/wukong_login/pc_login_service_test.dart test/wukong_scan/scan_service_test.dart`
Expected: PASS

- [ ] **Step 2: Verify the live server and container entry points**

Run: `ssh -F NUL ubuntu@42.194.218.158 "hostname && docker ps --format '{{.Names}}' | grep wukongim_prod-tsdd-api-1"`
Expected: prints `VM-0-13-ubuntu` and the live API container name `wukongim_prod-tsdd-api-1`

Run: `ssh -F NUL ubuntu@42.194.218.158 "sed -n '145,195p' /opt/wukongim-prod/src/modules/user/api.go"`
Expected: shows the production route registrations for devices, quit-PC, login UUID, login status, login verification, and grant-login

- [ ] **Step 3: Exercise the app manually, then capture the live API logs**

Run: `ssh -F NUL ubuntu@42.194.218.158 "docker logs --since 10m wukongim_prod-tsdd-api-1 | grep -E '/v1/user/login|/v1/user/sms/login_check_phone|/v1/user/login/check_phone|/v1/user/devices|/v1/user/pc/quit|/v1/user/loginuuid|/v1/user/loginstatus|/v1/user/grant_login'"`
Expected: log lines showing the exact Phase 4 endpoints hit by the Flutter app after you manually perform:

- phone/password login
- login verification if the backend demands it
- opening device sessions
- deleting a remote device or quitting all PC/Web sessions
- scanning a login-confirm QR and confirming it

- [ ] **Step 4: If the live payload shape diverges, patch the production source before claiming completion**

```go
// /opt/wukongim-prod/src/modules/user/api.go
qrcodeInfo := common.NewQRCodeModel(common.QRCodeTypeScanLogin, map[string]interface{}{
	"app_id":    "wukongchat",
	"status":    common.ScanLoginStatusAuthed,
	"uid":       loginUID,
	"auth_code": authCode,
	"encrypt":   encrypt,
})
err = u.ctx.GetRedisConn().SetAndExpire(
	fmt.Sprintf("%s%s", common.QRCodeCachePrefix, uuid),
	util.ToJson(qrcodeInfo),
	time.Minute*5,
)
```

```go
// /opt/wukongim-prod/src/modules/user/api_device.go
deviceResps = append(deviceResps, deviceResp{
	ID:          device.Id,
	DeviceID:    device.DeviceID,
	DeviceName:  deviceName,
	DeviceModel: device.DeviceModel,
	Self:        selft,
	LastLogin:   util.ToyyyyMMddHHmm(time.Unix(device.LastLogin, 0)),
})
```

- [ ] **Step 5: If a backend patch was needed, rebuild the production API service and re-check the logs**

Run: `ssh -F NUL ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && go test ./modules/user/... && docker compose -f deploy/production/docker-compose.yaml up -d --build tsdd-api"`
Expected: Go user-module tests pass, the `tsdd-api` image rebuilds, and the container returns healthy

Run: `ssh -F NUL ubuntu@42.194.218.158 "docker logs --since 5m wukongim_prod-tsdd-api-1 | tail -n 50"`
Expected: no new auth/device-session handler errors after the rebuild

- [ ] **Step 6: Final manual exit gate**

Verify all of the following directly in the Flutter app before closing Phase 4:

- phone/password login reaches the authenticated runtime
- if login verification is required, it returns to the same bootstrap chain
- device sessions show live data from `/v1/user/devices`
- delete-device or quit-all actions mutate live backend state honestly
- scan login-confirm reaches `AuthWebLoginConfirmPage`
- confirming the Web login hits `/v1/user/grant_login` and succeeds or fails honestly
- every remaining `wukong_login/**` entry lands on the same mainline owner path

- [ ] **Step 7: Checkpoint**

```bash
git add lib/service/api/login_bridge_api.dart lib/modules/auth lib/wukong_login lib/wukong_scan
git commit -m "feat: close phase 4 auth pc-web convergence"
```

## Self-Review

### Spec Coverage

Covered:

- one truthful auth/session chain under `modules/auth/**`
- explicit bridge ownership in `login_bridge_api.dart`
- legacy `pc_login_service.dart` demotion
- wrapper-only `wukong_login/**` validation
- device-session, Web-login confirm, and scan-routing verification
- mojibake cleanup on in-scope production auth/session surfaces
- live-backend validation on `42.194.218.158`
- backend patch path limited to observed Phase 4 blockers

No gaps found against the approved Phase 4 spec.

### Placeholder Scan

This plan contains:

- exact file paths
- concrete tests to add
- concrete commands to run
- explicit backend paths and container names
- concrete Go and Dart snippets for the likely edit points

This plan does not rely on `TODO`, `TBD`, or "implement later" placeholders.

### Type Consistency

The plan consistently uses the existing production ownership chain:

- `AuthRepositoryImpl`
- `DeviceSessionController`
- `AuthWebLoginConfirmPage`
- `LoginBridgeApi`
- `ScanResultPage`
- `PCLoginService` as compatibility-only legacy facade

## Expected Outcome

After this plan is implemented:

- `modules/auth/**` remains the only truthful Flutter auth/session owner chain
- `LoginBridgeApi` becomes test-locked as the exclusive PC/Web bridge owner
- `pc_login_service.dart` stops being a false owner and becomes legacy-only compatibility code
- the active auth/session/scan surfaces no longer ship mojibake
- local tests, live backend logs, and manual runtime evidence all point to the same Phase 4 truth
