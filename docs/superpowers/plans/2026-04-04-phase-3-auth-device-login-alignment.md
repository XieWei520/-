# Phase 3 Auth And Device Login Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild Flutter authentication and device-login into one authoritative `modules/auth` mainline that matches the TangSengDaoDao Android login family on Android and improves reliability, route coherence, and runtime diagnostics.

**Architecture:** This plan lands a typed auth kernel first, centered on `AuthFlowState`, `AuthRepository`, and `AuthBootstrapCoordinator`, then ports Android-reference pages and side flows onto that kernel. Existing `lib/wukong_login` assets remain available only through compatibility wrappers once the new mainline pages own the router, capability gating, QR login confirmation, device-session management, and profile-completion routing.

**Tech Stack:** Flutter, flutter_riverpod, go_router, dio, flutter_test, existing WKIM Flutter SDK, PowerShell, SSH remote debugging

---

**Workspace Note:** This working copy does not currently contain `.git` metadata. The `git add` and `git commit` commands below are the correct checkpoint commands for the canonical repository checkout. In this local copy, record the same checkpoints together with verification output until the repository is initialized.

## Scope Boundary

This plan only implements the approved Phase 3 auth/device-login design defined in [2026-04-04-phase-3-auth-device-login-alignment-design.md](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/docs/superpowers/specs/2026-04-04-phase-3-auth-device-login-alignment-design.md).

In scope:

- one authoritative auth architecture under `lib/modules/auth`
- typed flow state, repository abstraction, and post-auth bootstrap coordinator
- Android-aligned login, register, reset-password, login-verification, and profile-completion flows
- route-level auth gating for login verification and profile completion
- QR/Web login confirmation, PC/Web device-session management, third-party login capability gating, and scan-result routing
- compatibility wrappers for `lib/modules/auth/*.dart` and `lib/wukong_login/*.dart`
- targeted tests and remote validation against the deployed server when backend behavior is unclear

Out of scope for this plan:

- unrelated chat, contacts, or home-tab parity work
- replacing backend contracts unless testing proves a blocking mismatch
- non-Android-first product redesign
- endpoint/UIKit-wide work from other phases except where auth must integrate with it

## File Structure

### New Files

- `lib/modules/auth/domain/auth_flow_models.dart`
  - Defines `AuthStage`, typed verification context, profile-completion requirements, bootstrap outcome, and the shared `AuthFlowState`.
- `lib/modules/auth/domain/auth_repository.dart`
  - Declares one contract over `AuthApi`, `LoginBridgeApi`, `CommonApi`, and `UserApi`.
- `lib/modules/auth/data/auth_repository_impl.dart`
  - Maps API payloads into the typed auth domain model and centralizes capability gating.
- `lib/modules/auth/coordinators/auth_bootstrap_coordinator.dart`
  - Owns the post-auth transaction: persist token, bind device identity, load current user, initialize IM, register push, sync drafts, and decide whether profile completion is required.
- `lib/modules/auth/application/auth_providers.dart`
  - Wires repository, coordinator, flow controller, and device-session controller providers.
- `lib/modules/auth/application/auth_flow_controller.dart`
  - Owns login, register, reset-password, login verification, and profile-completion submission state.
- `lib/modules/auth/application/device_session_controller.dart`
  - Owns PC/Web login devices, refresh state, delete-device actions, and quit-all-PC state.
- `lib/modules/auth/presentation/widgets/auth_flow_shell.dart`
  - Shared Android-aligned auth scaffold for all new pages.
- `lib/modules/auth/presentation/widgets/auth_area_code_picker.dart`
  - Shared area-code picker reused by login, register, and reset-password.
- `lib/modules/auth/presentation/widgets/auth_copy.dart`
  - Centralizes clean UTF-8 auth copy to remove mojibake from the product path.
- `lib/modules/auth/presentation/pages/auth_login_page.dart`
  - Authoritative Android-style login page.
- `lib/modules/auth/presentation/pages/auth_register_page.dart`
  - Authoritative Android-style register page with phone and username modes.
- `lib/modules/auth/presentation/pages/auth_reset_password_page.dart`
  - Authoritative reset-password page with code countdown.
- `lib/modules/auth/presentation/pages/auth_login_verification_page.dart`
  - Covers Android-style login-auth explain/input flow.
- `lib/modules/auth/presentation/pages/auth_profile_completion_page.dart`
  - Covers post-auth profile completion before home entry.
- `lib/modules/auth/presentation/pages/auth_device_sessions_page.dart`
  - Covers current-device and remote-device management.
- `lib/modules/auth/presentation/pages/auth_web_login_confirm_page.dart`
  - Covers scan-driven or route-driven Web login confirmation.
- `lib/modules/auth/presentation/pages/auth_third_login_page.dart`
  - Covers capability-gated third-party login entry and poll flow.
- `test/modules/auth/auth_bootstrap_coordinator_test.dart`
  - Verifies the shared post-auth bootstrap transaction.
- `test/modules/auth/auth_login_page_test.dart`
  - Verifies Android-style login validation, agreement gating, and navigation entry points.
- `test/modules/auth/auth_register_reset_page_test.dart`
  - Verifies register and reset-password page behavior.
- `test/modules/auth/auth_verification_profile_flow_test.dart`
  - Verifies login verification, profile completion, and route gating.
- `test/modules/auth/auth_device_sessions_web_login_test.dart`
  - Verifies device-center, Web confirm, and scan integration.
- `test/modules/auth/auth_routes_compile_test.dart`
  - Verifies all new auth routes compile and the old wrappers resolve correctly.

### Existing Files To Modify

- `lib/data/providers/auth_provider.dart`
  - Keep it as the runtime session owner, but extend it with `needsProfileCompletion`, bootstrap delegation, and profile completion APIs.
- `lib/service/api/auth_api.dart`
  - Add login-verification endpoints, clean text handling, and response mapping for Android-style auth follow-up.
- `lib/service/api/login_bridge_api.dart`
  - Keep QR/device endpoints authoritative, but normalize device and Web-login payload mapping for the new controller layer.
- `lib/service/api/common_api.dart`
  - Expand runtime capability parsing so auth can hide or disable dead-end entries cleanly.
- `lib/service/api/user_api.dart`
  - Reuse `updateUserInfo(...)` and `uploadAvatar(...)` during profile completion.
- `lib/data/providers/runtime_capabilities_provider.dart`
  - Point capability consumers at the new auth repository/controller layer where needed.
- `lib/app/navigation/app_route_location.dart`
  - Add canonical auth route constants.
- `lib/app/navigation/app_route_resolver.dart`
  - Gate unauthenticated, login-verification, and profile-completion redirects coherently.
- `lib/app/navigation/app_router.dart`
  - Register all new auth and device-login routes.
- `lib/modules/auth/auth_shell.dart`
  - Reduce to a compatibility wrapper or shared visual shell bridge.
- `lib/modules/auth/login_page.dart`
  - Reduce to a thin wrapper over `AuthLoginPage`.
- `lib/modules/auth/register_page.dart`
  - Reduce to a thin wrapper over `AuthRegisterPage`.
- `lib/wukong_login/login_page.dart`
  - Redirect legacy entry to the new mainline login page.
- `lib/wukong_login/pc_login_page.dart`
  - Wrap the new device-session or Web-login surface.
- `lib/wukong_login/web_login_confirm_page.dart`
  - Wrap the new Web-login confirmation page.
- `lib/wukong_login/third_login_page.dart`
  - Wrap the new third-party login page.
- `lib/wukong_login/pc_login_management_page.dart`
  - Wrap the new device-session page.
- `lib/wukong_login/login_exports.dart`
  - Export the new mainline pages instead of the deprecated implementation.
- `lib/wukong_scan/scan_result_page.dart`
  - Route scan results into `AuthWebLoginConfirmPage` when the QR payload is a login confirmation.

## Remote Debugging Requirement

This phase explicitly allows server-assisted validation through `ssh root@103.207.68.33`.

- Use remote inspection when:
  - login-verification payloads do not match the Android contract
  - QR/Web login status changes do not align with local parsing assumptions
  - device-session records or delete/quit actions behave differently from expected
  - runtime capability flags do not expose enough information to gate third-party or Web-login entries safely
- Minimum remote checks:
  - `ssh root@103.207.68.33 "docker ps --format '{{.Names}}'"`
  - `ssh root@103.207.68.33 "docker logs --tail 200 fullstack-tangsengdaodaoserver-1"`
  - `ssh root@103.207.68.33 "grep -n '/v1/user/login' /data/fullstack/wukongimdata/logs/error.log | tail -n 20"`
  - `ssh root@103.207.68.33 "grep -n '/v1/user/devices' /data/fullstack/wukongimdata/logs/error.log | tail -n 20"`

## Verification Commands Used Throughout

- `flutter analyze lib/modules/auth lib/data/providers/auth_provider.dart lib/service/api/auth_api.dart lib/service/api/login_bridge_api.dart lib/service/api/common_api.dart lib/service/api/user_api.dart lib/app/navigation lib/wukong_login lib/wukong_scan/scan_result_page.dart`
- `flutter test test/modules/auth/auth_bootstrap_coordinator_test.dart`
- `flutter test test/modules/auth/auth_login_page_test.dart`
- `flutter test test/modules/auth/auth_register_reset_page_test.dart`
- `flutter test test/modules/auth/auth_verification_profile_flow_test.dart`
- `flutter test test/modules/auth/auth_device_sessions_web_login_test.dart`
- `flutter test test/modules/auth/auth_routes_compile_test.dart`
- `flutter test test/app/navigation/app_router_test.dart test/realtime/device/device_identity_login_flow_test.dart test/wukong_scan/scan_service_test.dart`

### Task 1: Build The Auth Kernel And Bootstrap Coordinator

**Files:**
- Create: `lib/modules/auth/domain/auth_flow_models.dart`
- Create: `lib/modules/auth/domain/auth_repository.dart`
- Create: `lib/modules/auth/data/auth_repository_impl.dart`
- Create: `lib/modules/auth/coordinators/auth_bootstrap_coordinator.dart`
- Create: `lib/modules/auth/application/auth_providers.dart`
- Create: `lib/modules/auth/application/auth_flow_controller.dart`
- Test: `test/modules/auth/auth_bootstrap_coordinator_test.dart`
- Modify: `lib/data/providers/auth_provider.dart`
- Modify: `lib/service/api/auth_api.dart`

- [ ] **Step 1: Write the failing bootstrap coordinator tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/modules/auth/coordinators/auth_bootstrap_coordinator.dart';
import 'package:wukong_im_app/modules/auth/domain/auth_flow_models.dart';

void main() {
  test('bootstrap completes a normal login into authenticatedReady', () async {
    final calls = <String>[];
    final coordinator = AuthBootstrapCoordinator(
      persistSession: ({required uid, required token}) async {
        calls.add('persist:$uid:$token');
      },
      bindDeviceIdentity: ({required uid, required token}) async {
        calls.add('bind:$uid');
      },
      loadCurrentUser: () async {
        calls.add('load-user');
        return UserInfo(uid: 'u100', token: 't100', name: 'Wukong', avatar: 'avatar.png');
      },
      connectIm: (user) async => calls.add('connect-im:${user.uid}'),
      registerPush: () async => calls.add('push'),
      syncDrafts: () async => calls.add('drafts'),
    );

    final result = await coordinator.bootstrap(
      const AuthCredentialResult.success(
        uid: 'u100',
        token: 't100',
        user: UserInfo(uid: 'u100', token: 't100'),
      ),
    );

    expect(result.stage, AuthStage.authenticatedReady);
    expect(result.user?.uid, 'u100');
    expect(
      calls,
      <String>[
        'persist:u100:t100',
        'bind:u100',
        'load-user',
        'connect-im:u100',
        'push',
        'drafts',
      ],
    );
  });

  test('bootstrap redirects to profile completion when required fields are missing', () async {
    final coordinator = AuthBootstrapCoordinator(
      persistSession: ({required uid, required token}) async {},
      bindDeviceIdentity: ({required uid, required token}) async {},
      loadCurrentUser: () async => UserInfo(uid: 'u101', token: 't101', name: '', avatar: ''),
      connectIm: (_) async {},
      registerPush: () async {},
      syncDrafts: () async {},
    );

    final result = await coordinator.bootstrap(
      const AuthCredentialResult.success(
        uid: 'u101',
        token: 't101',
        user: UserInfo(uid: 'u101', token: 't101'),
      ),
    );

    expect(result.stage, AuthStage.awaitingProfileCompletion);
    expect(result.requiresProfileCompletion, isTrue);
  });
}
```

- [ ] **Step 2: Run the bootstrap tests to verify they fail**

Run: `flutter test test/modules/auth/auth_bootstrap_coordinator_test.dart`
Expected: FAIL with missing `AuthBootstrapCoordinator`, missing `AuthCredentialResult`, or missing `AuthStage.awaitingProfileCompletion`

- [ ] **Step 3: Implement the typed auth models, repository contract, and bootstrap coordinator**

```dart
// lib/modules/auth/domain/auth_flow_models.dart
import 'package:flutter/foundation.dart';

import '../../../data/models/user.dart';

enum AuthStage {
  restoringSession,
  unauthenticated,
  submittingCredentials,
  awaitingLoginVerification,
  awaitingRegistrationCode,
  awaitingPasswordResetCode,
  awaitingProfileCompletion,
  bootstrappingAuthenticatedSession,
  authenticatedReady,
  loadingExternalLoginConfirmation,
  managingDeviceSessions,
}

@immutable
class LoginVerificationContext {
  const LoginVerificationContext({
    required this.uid,
    required this.zone,
    required this.phone,
  });

  final String uid;
  final String zone;
  final String phone;
}

@immutable
class AuthFlowState {
  const AuthFlowState({
    this.stage = AuthStage.unauthenticated,
    this.zone = '86',
    this.isLoading = false,
    this.errorMessage,
    this.verificationContext,
  });

  final AuthStage stage;
  final String zone;
  final bool isLoading;
  final String? errorMessage;
  final LoginVerificationContext? verificationContext;

  AuthFlowState copyWith({
    AuthStage? stage,
    String? zone,
    bool? isLoading,
    String? errorMessage,
    LoginVerificationContext? verificationContext,
  }) {
    return AuthFlowState(
      stage: stage ?? this.stage,
      zone: zone ?? this.zone,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      verificationContext: verificationContext ?? this.verificationContext,
    );
  }
}

@immutable
class AuthCredentialResult {
  const AuthCredentialResult.success({
    required this.uid,
    required this.token,
    required this.user,
    this.requiresLoginVerification = false,
    this.verificationContext,
  }) : success = true,
       message = null;

  const AuthCredentialResult.failure(this.message)
      : success = false,
        uid = '',
        token = '',
        user = null,
        requiresLoginVerification = false,
        verificationContext = null;

  final bool success;
  final String uid;
  final String token;
  final UserInfo? user;
  final String? message;
  final bool requiresLoginVerification;
  final LoginVerificationContext? verificationContext;
}

@immutable
class AuthBootstrapResult {
  const AuthBootstrapResult({
    required this.stage,
    this.user,
  });

  final AuthStage stage;
  final UserInfo? user;

  bool get requiresProfileCompletion =>
      stage == AuthStage.awaitingProfileCompletion;
}
```

```dart
// lib/modules/auth/domain/auth_repository.dart
import '../../../data/models/user.dart';
import 'auth_flow_models.dart';

abstract class AuthRepository {
  Future<AuthCredentialResult> loginWithPhone({
    required String zone,
    required String phone,
    required String password,
  });

  Future<AuthCredentialResult> loginWithUsername({
    required String username,
    required String password,
  });

  Future<void> sendRegisterCode({
    required String zone,
    required String phone,
  });

  Future<void> sendResetPasswordCode({
    required String zone,
    required String phone,
  });

  Future<void> resetPassword({
    required String zone,
    required String phone,
    required String code,
    required String newPassword,
  });

  Future<UserInfo?> getCurrentUser();
}
```

```dart
// lib/modules/auth/coordinators/auth_bootstrap_coordinator.dart
import '../../../data/models/user.dart';
import '../domain/auth_flow_models.dart';

typedef PersistSession = Future<void> Function({
  required String uid,
  required String token,
});
typedef BindDeviceIdentity = Future<void> Function({
  required String uid,
  required String token,
});
typedef LoadCurrentUser = Future<UserInfo?> Function();
typedef ConnectIm = Future<void> Function(UserInfo user);
typedef RegisterPush = Future<void> Function();
typedef SyncDrafts = Future<void> Function();

class AuthBootstrapCoordinator {
  AuthBootstrapCoordinator({
    required PersistSession persistSession,
    required BindDeviceIdentity bindDeviceIdentity,
    required LoadCurrentUser loadCurrentUser,
    required ConnectIm connectIm,
    required RegisterPush registerPush,
    required SyncDrafts syncDrafts,
  }) : _persistSession = persistSession,
       _bindDeviceIdentity = bindDeviceIdentity,
       _loadCurrentUser = loadCurrentUser,
       _connectIm = connectIm,
       _registerPush = registerPush,
       _syncDrafts = syncDrafts;

  final PersistSession _persistSession;
  final BindDeviceIdentity _bindDeviceIdentity;
  final LoadCurrentUser _loadCurrentUser;
  final ConnectIm _connectIm;
  final RegisterPush _registerPush;
  final SyncDrafts _syncDrafts;

  Future<AuthBootstrapResult> bootstrap(AuthCredentialResult result) async {
    if (!result.success || result.user == null) {
      throw StateError(result.message ?? 'Auth bootstrap requires a successful credential result.');
    }

    await _persistSession(uid: result.uid, token: result.token);
    await _bindDeviceIdentity(uid: result.uid, token: result.token);
    final remoteUser = await _loadCurrentUser();
    final user = remoteUser ?? result.user!;
    await _connectIm(user);
    await _registerPush();
    await _syncDrafts();

    if ((user.name ?? '').trim().isEmpty || (user.avatar ?? '').trim().isEmpty) {
      return AuthBootstrapResult(
        stage: AuthStage.awaitingProfileCompletion,
        user: user,
      );
    }

    return AuthBootstrapResult(
      stage: AuthStage.authenticatedReady,
      user: user,
    );
  }
}
```

- [ ] **Step 4: Extend the repository implementation, controller wiring, and session provider**

```dart
// lib/modules/auth/application/auth_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/storage_utils.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../service/api/api_client.dart';
import '../../../service/api/auth_api.dart';
import '../../../service/api/common_api.dart';
import '../../../service/api/login_bridge_api.dart';
import '../../../service/api/user_api.dart';
import '../coordinators/auth_bootstrap_coordinator.dart';
import '../data/auth_repository_impl.dart';
import '../domain/auth_repository.dart';
import 'auth_flow_controller.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    authApi: AuthApi.instance,
    loginBridgeApi: LoginBridgeApi.instance,
    commonApi: CommonApi.instance,
    userApi: UserApi.instance,
  );
});

final authBootstrapCoordinatorProvider = Provider<AuthBootstrapCoordinator>((ref) {
  final notifier = ref.read(authProvider.notifier);
  return AuthBootstrapCoordinator(
    persistSession: ({required uid, required token}) async {
      await StorageUtils.setUid(uid);
      await StorageUtils.setToken(token);
      ApiClient.instance.setToken(token);
    },
    bindDeviceIdentity: ({required uid, required token}) {
      return notifier.bindDeviceIdentity(uid: uid, token: token);
    },
    loadCurrentUser: notifier.loadCurrentUser,
    connectIm: notifier.connectAuthenticatedSession,
    registerPush: notifier.registerPushAfterLogin,
    syncDrafts: notifier.syncDraftScope,
  );
});

final authFlowControllerProvider =
    StateNotifierProvider.autoDispose<AuthFlowController, AuthFlowState>((ref) {
  return AuthFlowController(
    repository: ref.read(authRepositoryProvider),
    bootstrapCoordinator: ref.read(authBootstrapCoordinatorProvider),
    authNotifier: ref.read(authProvider.notifier),
  );
});
```

```dart
// lib/data/providers/auth_provider.dart
class AuthState {
  final bool isLoggedIn;
  final bool needsProfileCompletion;
  final UserInfo? userInfo;
  final bool isRestoringSession;
  final bool isLoading;
  final String? error;

  AuthState({
    this.isLoggedIn = false,
    this.needsProfileCompletion = false,
    this.userInfo,
    this.isRestoringSession = false,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    bool? needsProfileCompletion,
    UserInfo? userInfo,
    bool? isRestoringSession,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      needsProfileCompletion: needsProfileCompletion ?? this.needsProfileCompletion,
      userInfo: userInfo ?? this.userInfo,
      isRestoringSession: isRestoringSession ?? this.isRestoringSession,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  Future<void> bindDeviceIdentity({
    required String uid,
    required String token,
  }) {
    return _deviceIdentityAuthority.bindAuthenticatedSession(
      userId: uid,
      token: token,
    );
  }

  Future<UserInfo?> loadCurrentUser() => _currentUserLoader();

  Future<void> connectAuthenticatedSession(UserInfo user) async {
    state = state.copyWith(
      isLoggedIn: true,
      userInfo: user,
      isRestoringSession: false,
      isLoading: false,
      error: null,
    );
  }

  Future<void> registerPushAfterLogin() => PushService.instance.handleLogin();

  Future<void> syncDraftScope() => _syncDraftScope();

  Future<void> commitBootstrapResult(AuthBootstrapResult result) async {
    state = state.copyWith(
      isLoggedIn: true,
      needsProfileCompletion: result.requiresProfileCompletion,
      userInfo: result.user,
      isRestoringSession: false,
      isLoading: false,
      error: null,
    );
  }
}
```

```dart
// lib/service/api/auth_api.dart
class LoginResp {
  bool get requiresLoginVerification =>
      code == 11016 ||
      code == 11017 ||
      (msg?.toLowerCase().contains('verification') ?? false);

  LoginVerificationContext? toVerificationContext({
    required String zone,
    required String phone,
  }) {
    if (!requiresLoginVerification || data?.uid?.trim().isEmpty != false) {
      return null;
    }
    return LoginVerificationContext(
      uid: data!.uid!.trim(),
      zone: zone,
      phone: phone,
    );
  }
}
```

- [ ] **Step 5: Run the targeted auth-kernel verification**

Run: `flutter test test/modules/auth/auth_bootstrap_coordinator_test.dart`
Expected: PASS with the bootstrap flow covering both ready and profile-completion outcomes

Run: `flutter analyze lib/modules/auth lib/data/providers/auth_provider.dart lib/service/api/auth_api.dart`
Expected: PASS with no analyzer errors in the new auth kernel files

- [ ] **Step 6: Checkpoint**

```bash
git add lib/modules/auth/domain/auth_flow_models.dart lib/modules/auth/domain/auth_repository.dart lib/modules/auth/data/auth_repository_impl.dart lib/modules/auth/coordinators/auth_bootstrap_coordinator.dart lib/modules/auth/application/auth_providers.dart lib/modules/auth/application/auth_flow_controller.dart lib/data/providers/auth_provider.dart lib/service/api/auth_api.dart test/modules/auth/auth_bootstrap_coordinator_test.dart
git commit -m "feat: add auth kernel and bootstrap coordinator"
```

### Task 2: Rebuild The Mainline Login Page And Shared Auth Widgets

**Files:**
- Create: `lib/modules/auth/presentation/widgets/auth_flow_shell.dart`
- Create: `lib/modules/auth/presentation/widgets/auth_area_code_picker.dart`
- Create: `lib/modules/auth/presentation/widgets/auth_copy.dart`
- Create: `lib/modules/auth/presentation/pages/auth_login_page.dart`
- Test: `test/modules/auth/auth_login_page_test.dart`
- Modify: `lib/modules/auth/login_page.dart`
- Modify: `lib/modules/auth/auth_shell.dart`

- [ ] **Step 1: Write the failing login-page widget tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_login_page.dart';

void main() {
  testWidgets('login page blocks submit until terms are accepted', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AuthLoginPage()),
      ),
    );

    await tester.enterText(find.byKey(const ValueKey('auth-login-phone')), '13800138000');
    await tester.enterText(find.byKey(const ValueKey('auth-login-password')), '123456');
    await tester.tap(find.byKey(const ValueKey('auth-login-submit')));
    await tester.pump();

    expect(find.text('请先同意隐私政策和用户协议'), findsOneWidget);
  });

  testWidgets('login page opens the shared area-code picker and navigation entries', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AuthLoginPage()),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('auth-zone-trigger')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('auth-area-code-picker')), findsOneWidget);

    await tester.tap(find.text('+1').last);
    await tester.pumpAndSettle();
    expect(find.text('+1'), findsWidgets);

    expect(find.byKey(const ValueKey('auth-open-register')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-open-reset-password')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the login-page tests to verify they fail**

Run: `flutter test test/modules/auth/auth_login_page_test.dart`
Expected: FAIL with missing `AuthLoginPage`, missing area-code picker keys, or missing clean UTF-8 copy

- [ ] **Step 3: Implement the shared auth shell, clean copy map, area-code picker, and new login page**

```dart
// lib/modules/auth/presentation/widgets/auth_copy.dart
class AuthCopy {
  static const String loginTitle = '欢迎登录';
  static const String loginPhoneHint = '请输入手机号';
  static const String loginPasswordHint = '请输入密码';
  static const String acceptAgreementFirst = '请先同意隐私政策和用户协议';
  static const String register = '注册';
  static const String forgotPassword = '忘记密码';
  static const String login = '登录';
  static const String countryPickerTitle = '选择国家或地区';
}
```

```dart
// lib/modules/auth/presentation/widgets/auth_area_code_picker.dart
import 'package:flutter/material.dart';

@immutable
class AuthAreaCode {
  const AuthAreaCode({
    required this.name,
    required this.code,
  });

  final String name;
  final String code;
}

const defaultAuthAreaCodes = <AuthAreaCode>[
  AuthAreaCode(name: '中国', code: '86'),
  AuthAreaCode(name: '美国', code: '1'),
  AuthAreaCode(name: '英国', code: '44'),
  AuthAreaCode(name: '日本', code: '81'),
  AuthAreaCode(name: '韩国', code: '82'),
];

Future<AuthAreaCode?> showAuthAreaCodePicker(
  BuildContext context, {
  required String selectedCode,
}) {
  return showModalBottomSheet<AuthAreaCode>(
    context: context,
    builder: (context) {
      return ListView(
        key: const ValueKey('auth-area-code-picker'),
        children: defaultAuthAreaCodes
            .map(
              (item) => ListTile(
                key: ValueKey('auth-area-code-${item.code}'),
                title: Text(item.name),
                trailing: Text('+${item.code}'),
                selected: item.code == selectedCode,
                onTap: () => Navigator.of(context).pop(item),
              ),
            )
            .toList(growable: false),
      );
    },
  );
}
```

```dart
// lib/modules/auth/presentation/widgets/auth_flow_shell.dart
import 'package:flutter/material.dart';

class AuthFlowShell extends StatelessWidget {
  const AuthFlowShell({
    super.key,
    required this.title,
    required this.child,
    this.leading,
    this.footer,
  });

  final String title;
  final Widget child;
  final Widget? leading;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (leading != null) Align(alignment: Alignment.centerLeft, child: leading!),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: child,
              ),
            ),
            if (footer != null) Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: footer!,
            ),
          ],
        ),
      ),
    );
  }
}
```

```dart
// lib/modules/auth/presentation/pages/auth_login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigation/app_route_location.dart';
import '../../application/auth_providers.dart';
import '../widgets/auth_area_code_picker.dart';
import '../widgets/auth_copy.dart';
import '../widgets/auth_flow_shell.dart';

class AuthLoginPage extends ConsumerStatefulWidget {
  const AuthLoginPage({super.key});

  @override
  ConsumerState<AuthLoginPage> createState() => _AuthLoginPageState();
}

class _AuthLoginPageState extends ConsumerState<AuthLoginPage> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  String _zone = '86';
  bool _agreed = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authFlowControllerProvider);
    return AuthFlowShell(
      title: AuthCopy.loginTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextButton(
            key: const ValueKey('auth-zone-trigger'),
            onPressed: _selectZone,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('+$_zone'),
            ),
          ),
          TextField(
            key: const ValueKey('auth-login-phone'),
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: AuthCopy.loginPhoneHint),
          ),
          TextField(
            key: const ValueKey('auth-login-password'),
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: AuthCopy.loginPasswordHint,
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          CheckboxListTile(
            value: _agreed,
            onChanged: (value) => setState(() => _agreed = value ?? false),
            title: const Text('我已阅读并同意《隐私政策》《用户协议》'),
          ),
          FilledButton(
            key: const ValueKey('auth-login-submit'),
            onPressed: state.isLoading ? null : _submit,
            child: const Text(AuthCopy.login),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                key: const ValueKey('auth-open-register'),
                onPressed: () => context.push(AppRouteLocation.authRegister),
                child: const Text(AuthCopy.register),
              ),
              TextButton(
                key: const ValueKey('auth-open-reset-password'),
                onPressed: () => context.push(AppRouteLocation.authResetPassword),
                child: const Text(AuthCopy.forgotPassword),
              ),
            ],
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(state.errorMessage!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }

  Future<void> _selectZone() async {
    final selected = await showAuthAreaCodePicker(
      context,
      selectedCode: _zone,
    );
    if (selected != null && mounted) {
      setState(() => _zone = selected.code);
    }
  }

  Future<void> _submit() async {
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AuthCopy.acceptAgreementFirst)),
      );
      return;
    }
    await ref.read(authFlowControllerProvider.notifier).loginWithPhone(
          zone: _zone,
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
        );
  }
}
```

```dart
// lib/modules/auth/login_page.dart
import 'package:flutter/widgets.dart';

import 'presentation/pages/auth_login_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) => const AuthLoginPage();
}
```

- [ ] **Step 4: Run the login-page verification**

Run: `flutter test test/modules/auth/auth_login_page_test.dart`
Expected: PASS with agreement gating, shared area-code picker, and navigation entry points covered

Run: `flutter analyze lib/modules/auth`
Expected: PASS with the new login page and widget files analyzer-clean

- [ ] **Step 5: Checkpoint**

```bash
git add lib/modules/auth/presentation/widgets/auth_flow_shell.dart lib/modules/auth/presentation/widgets/auth_area_code_picker.dart lib/modules/auth/presentation/widgets/auth_copy.dart lib/modules/auth/presentation/pages/auth_login_page.dart lib/modules/auth/login_page.dart lib/modules/auth/auth_shell.dart test/modules/auth/auth_login_page_test.dart
git commit -m "feat: rebuild the mainline auth login page"
```

### Task 3: Port Registration And Reset Password Onto The New Auth Flow Controller

**Files:**
- Create: `lib/modules/auth/presentation/pages/auth_register_page.dart`
- Create: `lib/modules/auth/presentation/pages/auth_reset_password_page.dart`
- Test: `test/modules/auth/auth_register_reset_page_test.dart`
- Modify: `lib/modules/auth/application/auth_flow_controller.dart`
- Modify: `lib/modules/auth/domain/auth_repository.dart`
- Modify: `lib/modules/auth/data/auth_repository_impl.dart`
- Modify: `lib/modules/auth/register_page.dart`
- Modify: `lib/service/api/auth_api.dart`

- [ ] **Step 1: Write the failing register/reset widget tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_register_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_reset_password_page.dart';

void main() {
  testWidgets('phone register page exposes code countdown and two modes', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AuthRegisterPage()),
      ),
    );

    expect(find.text('手机号注册'), findsOneWidget);
    expect(find.text('用户名注册'), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-register-send-code')), findsOneWidget);
  });

  testWidgets('reset password page reuses the shared area code picker and submit key', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AuthResetPasswordPage()),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('auth-zone-trigger')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('auth-area-code-picker')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-reset-submit')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the register/reset tests to verify they fail**

Run: `flutter test test/modules/auth/auth_register_reset_page_test.dart`
Expected: FAIL with missing register/reset pages or missing send-code and submit keys

- [ ] **Step 3: Extend the repository and flow controller with register/reset operations**

```dart
// lib/modules/auth/domain/auth_repository.dart
abstract class AuthRepository {
  Future<AuthCredentialResult> registerWithPhone({
    required String zone,
    required String phone,
    required String code,
    required String password,
    required String name,
  });

  Future<AuthCredentialResult> registerWithUsername({
    required String username,
    required String password,
    String? name,
  });

  Future<void> sendRegisterCode({
    required String zone,
    required String phone,
  });

  Future<void> sendResetPasswordCode({
    required String zone,
    required String phone,
  });

  Future<void> resetPassword({
    required String zone,
    required String phone,
    required String code,
    required String newPassword,
  });
}
```

```dart
// lib/modules/auth/application/auth_flow_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/auth_provider.dart';
import '../coordinators/auth_bootstrap_coordinator.dart';
import '../domain/auth_flow_models.dart';
import '../domain/auth_repository.dart';

class AuthFlowController extends StateNotifier<AuthFlowState> {
  AuthFlowController({
    required AuthRepository repository,
    required AuthBootstrapCoordinator bootstrapCoordinator,
    required AuthNotifier authNotifier,
  }) : _repository = repository,
       _bootstrapCoordinator = bootstrapCoordinator,
       _authNotifier = authNotifier,
       super(const AuthFlowState());

  final AuthRepository _repository;
  final AuthBootstrapCoordinator _bootstrapCoordinator;
  final AuthNotifier _authNotifier;

  Future<void> loginWithPhone({
    required String zone,
    required String phone,
    required String password,
  }) async {
    state = state.copyWith(
      stage: AuthStage.submittingCredentials,
      isLoading: true,
      errorMessage: null,
      zone: zone,
    );

    final result = await _repository.loginWithPhone(
      zone: zone,
      phone: phone,
      password: password,
    );

    if (!result.success) {
      state = state.copyWith(
        stage: AuthStage.unauthenticated,
        isLoading: false,
        errorMessage: result.message,
      );
      return;
    }

    final bootstrapResult = await _bootstrapCoordinator.bootstrap(result);
    await _authNotifier.commitBootstrapResult(bootstrapResult);
    state = state.copyWith(
      stage: bootstrapResult.stage,
      isLoading: false,
    );
  }

  Future<void> registerWithPhone({
    required String zone,
    required String phone,
    required String code,
    required String password,
    required String name,
  }) async {
    state = state.copyWith(stage: AuthStage.awaitingRegistrationCode, isLoading: true);
    final result = await _repository.registerWithPhone(
      zone: zone,
      phone: phone,
      code: code,
      password: password,
      name: name,
    );
    if (!result.success) {
      state = state.copyWith(
        stage: AuthStage.unauthenticated,
        isLoading: false,
        errorMessage: result.message,
      );
      return;
    }

    final bootstrapResult = await _bootstrapCoordinator.bootstrap(result);
    await _authNotifier.commitBootstrapResult(bootstrapResult);
    state = state.copyWith(stage: bootstrapResult.stage, isLoading: false);
  }

  Future<void> sendRegisterCode({
    required String zone,
    required String phone,
  }) {
    return _repository.sendRegisterCode(zone: zone, phone: phone);
  }

  Future<void> sendResetPasswordCode({
    required String zone,
    required String phone,
  }) {
    return _repository.sendResetPasswordCode(zone: zone, phone: phone);
  }

  Future<void> resetPassword({
    required String zone,
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    state = state.copyWith(stage: AuthStage.awaitingPasswordResetCode, isLoading: true);
    await _repository.resetPassword(
      zone: zone,
      phone: phone,
      code: code,
      newPassword: newPassword,
    );
    state = state.copyWith(stage: AuthStage.unauthenticated, isLoading: false);
  }
}
```

```dart
// lib/modules/auth/data/auth_repository_impl.dart
import '../../../service/api/auth_api.dart';
import '../../../service/api/common_api.dart';
import '../../../service/api/login_bridge_api.dart';
import '../../../service/api/user_api.dart';
import '../domain/auth_flow_models.dart';
import '../domain/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthApi authApi,
    required LoginBridgeApi loginBridgeApi,
    required CommonApi commonApi,
    required UserApi userApi,
  }) : _authApi = authApi,
       _loginBridgeApi = loginBridgeApi,
       _commonApi = commonApi,
       _userApi = userApi;

  final AuthApi _authApi;
  final LoginBridgeApi _loginBridgeApi;
  final CommonApi _commonApi;
  final UserApi _userApi;

  @override
  Future<AuthCredentialResult> registerWithPhone({
    required String zone,
    required String phone,
    required String code,
    required String password,
    required String name,
  }) async {
    final resp = await _authApi.register(
      username: '$zone$phone',
      password: password,
      zone: zone,
      phone: phone,
      code: code,
      name: name,
    );
    if (!resp.success || resp.data?.uid == null || resp.data?.token == null) {
      return AuthCredentialResult.failure(resp.msg ?? '注册失败');
    }
    return AuthCredentialResult.success(
      uid: resp.data!.uid!,
      token: resp.data!.token!,
      user: UserInfo(
        uid: resp.data!.uid!,
        token: resp.data!.token!,
        name: resp.data!.name ?? name,
        phone: phone,
        zone: zone,
      ),
    );
  }

  @override
  Future<AuthCredentialResult> registerWithUsername({
    required String username,
    required String password,
    String? name,
  }) async {
    final resp = await _authApi.usernameRegister(
      username: username,
      password: password,
      name: name,
    );
    if (!resp.success || resp.data?.uid == null || resp.data?.token == null) {
      return AuthCredentialResult.failure(resp.msg ?? '注册失败');
    }
    return AuthCredentialResult.success(
      uid: resp.data!.uid!,
      token: resp.data!.token!,
      user: UserInfo(
        uid: resp.data!.uid!,
        token: resp.data!.token!,
        username: username,
        name: resp.data!.name ?? name,
      ),
    );
  }

  @override
  Future<void> sendRegisterCode({
    required String zone,
    required String phone,
  }) {
    return _authApi.sendRegisterCode(phone, zone: zone);
  }

  @override
  Future<void> sendResetPasswordCode({
    required String zone,
    required String phone,
  }) {
    return _authApi.sendForgetPwdCode(phone, zone: zone);
  }

  @override
  Future<void> resetPassword({
    required String zone,
    required String phone,
    required String code,
    required String newPassword,
  }) {
    return _authApi.resetPassword(
      phone,
      code,
      newPassword,
      zone: zone,
    );
  }
}
```

- [ ] **Step 4: Implement the new register and reset-password pages**

```dart
// lib/modules/auth/presentation/pages/auth_register_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth_providers.dart';
import '../widgets/auth_area_code_picker.dart';
import '../widgets/auth_flow_shell.dart';

class AuthRegisterPage extends ConsumerStatefulWidget {
  const AuthRegisterPage({super.key});

  @override
  ConsumerState<AuthRegisterPage> createState() => _AuthRegisterPageState();
}

class _AuthRegisterPageState extends ConsumerState<AuthRegisterPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _countdown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthFlowShell(
      title: '创建新账号',
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '手机号注册'),
              Tab(text: '用户名注册'),
            ],
          ),
          SizedBox(
            height: 560,
            child: TabBarView(
              controller: _tabController,
              children: [
                _PhoneRegisterForm(
                  countdown: _countdown,
                  onSendCode: _sendCode,
                ),
                const _UsernameRegisterForm(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendCode(String zone, String phone) async {
    await ref.read(authFlowControllerProvider.notifier).sendRegisterCode(
          zone: zone,
          phone: phone,
        );
    setState(() => _countdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _countdown == 0) {
        timer.cancel();
        return;
      }
      setState(() => _countdown -= 1);
    });
  }
}
```

```dart
// lib/modules/auth/presentation/pages/auth_reset_password_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth_providers.dart';
import '../widgets/auth_area_code_picker.dart';
import '../widgets/auth_flow_shell.dart';

class AuthResetPasswordPage extends ConsumerStatefulWidget {
  const AuthResetPasswordPage({super.key});

  @override
  ConsumerState<AuthResetPasswordPage> createState() =>
      _AuthResetPasswordPageState();
}

class _AuthResetPasswordPageState
    extends ConsumerState<AuthResetPasswordPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  String _zone = '86';

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthFlowShell(
      title: '重置登录密码',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextButton(
            key: const ValueKey('auth-zone-trigger'),
            onPressed: _pickZone,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('+$_zone'),
            ),
          ),
          TextField(controller: _phoneController, decoration: const InputDecoration(labelText: '手机号')),
          TextField(controller: _codeController, decoration: const InputDecoration(labelText: '验证码')),
          TextField(controller: _passwordController, decoration: const InputDecoration(labelText: '新密码')),
          FilledButton(
            key: const ValueKey('auth-reset-submit'),
            onPressed: _submit,
            child: const Text('确认重置'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickZone() async {
    final selected = await showAuthAreaCodePicker(context, selectedCode: _zone);
    if (selected != null && mounted) {
      setState(() => _zone = selected.code);
    }
  }

  Future<void> _submit() {
    return ref.read(authFlowControllerProvider.notifier).resetPassword(
          zone: _zone,
          phone: _phoneController.text.trim(),
          code: _codeController.text.trim(),
          newPassword: _passwordController.text,
        );
  }
}
```

```dart
// lib/modules/auth/register_page.dart
import 'package:flutter/widgets.dart';

import 'presentation/pages/auth_register_page.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) => const AuthRegisterPage();
}
```

- [ ] **Step 5: Run the register/reset verification**

Run: `flutter test test/modules/auth/auth_register_reset_page_test.dart`
Expected: PASS with register modes, send-code entry, shared area-code picker, and reset submit flow covered

Run: `flutter analyze lib/modules/auth lib/service/api/auth_api.dart`
Expected: PASS with the new register/reset pages and repository/controller changes analyzer-clean

- [ ] **Step 6: Checkpoint**

```bash
git add lib/modules/auth/presentation/pages/auth_register_page.dart lib/modules/auth/presentation/pages/auth_reset_password_page.dart lib/modules/auth/application/auth_flow_controller.dart lib/modules/auth/domain/auth_repository.dart lib/modules/auth/data/auth_repository_impl.dart lib/modules/auth/register_page.dart lib/service/api/auth_api.dart test/modules/auth/auth_register_reset_page_test.dart
git commit -m "feat: port register and reset password to the new auth flow"
```

### Task 4: Add Login Verification, Profile Completion, And Route Gating

**Files:**
- Create: `lib/modules/auth/presentation/pages/auth_login_verification_page.dart`
- Create: `lib/modules/auth/presentation/pages/auth_profile_completion_page.dart`
- Test: `test/modules/auth/auth_verification_profile_flow_test.dart`
- Modify: `lib/modules/auth/application/auth_flow_controller.dart`
- Modify: `lib/modules/auth/domain/auth_repository.dart`
- Modify: `lib/modules/auth/data/auth_repository_impl.dart`
- Modify: `lib/data/providers/auth_provider.dart`
- Modify: `lib/service/api/auth_api.dart`
- Modify: `lib/service/api/user_api.dart`
- Modify: `lib/app/navigation/app_route_location.dart`
- Modify: `lib/app/navigation/app_route_resolver.dart`
- Modify: `lib/app/navigation/app_router.dart`

- [ ] **Step 1: Write the failing verification/profile flow tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/app/navigation/app_route_location.dart';
import 'package:wukong_im_app/app/navigation/app_route_resolver.dart';
import 'package:wukong_im_app/data/providers/auth_provider.dart';
import 'package:wukong_im_app/modules/auth/domain/auth_flow_models.dart';

void main() {
  test('route resolver keeps verification flow on the dedicated page', () {
    final redirect = AppRouteResolver.resolve(
      authState: AuthState(),
      authFlowState: const AuthFlowState(
        stage: AuthStage.awaitingLoginVerification,
      ),
      location: '/home',
    );

    expect(redirect, AppRouteLocation.authLoginVerification);
  });

  test('route resolver sends incomplete profiles to profile completion', () {
    final redirect = AppRouteResolver.resolve(
      authState: AuthState(
        isLoggedIn: true,
        needsProfileCompletion: true,
      ),
      authFlowState: const AuthFlowState(
        stage: AuthStage.awaitingProfileCompletion,
      ),
      location: '/home',
    );

    expect(redirect, AppRouteLocation.authProfileCompletion);
  });
}
```

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_login_verification_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_profile_completion_page.dart';

void main() {
  testWidgets('login verification page exposes send-code and confirm actions', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AuthLoginVerificationPage()),
      ),
    );

    expect(find.byKey(const ValueKey('auth-login-verification-send-code')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-login-verification-submit')), findsOneWidget);
  });

  testWidgets('profile completion page blocks entry until submit is available', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AuthProfileCompletionPage()),
      ),
    );

    expect(find.byKey(const ValueKey('auth-profile-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-profile-submit')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the verification/profile tests to verify they fail**

Run: `flutter test test/modules/auth/auth_verification_profile_flow_test.dart`
Expected: FAIL with missing route constants, missing resolver overload, missing verification/profile pages, or missing controller methods

- [ ] **Step 3: Add verification APIs and flow-controller transitions**

```dart
// lib/modules/auth/domain/auth_repository.dart
abstract class AuthRepository {
  Future<void> sendLoginVerificationCode(String uid);

  Future<AuthCredentialResult> verifyLoginCode({
    required String uid,
    required String code,
  });

  Future<UserInfo> completeProfile({
    required String name,
    int? sex,
    String? avatarFilePath,
  });
}
```

```dart
// lib/service/api/auth_api.dart
Future<void> sendLoginVerificationCode(String uid) async {
  final response = await _client.post(
    'user/sms/login_check_phone',
    options: _plainTextOptions,
    data: jsonEncode({'uid': uid}),
  );
  _throwIfFailed(response, fallbackMessage: '发送登录验证短信失败');
}

Future<LoginResp> verifyLoginCode({
  required String uid,
  required String code,
}) async {
  final response = await _client.post(
    'user/login/check_phone',
    options: _plainTextOptions,
    data: jsonEncode({'uid': uid, 'code': code}),
  );
  return LoginResp.fromJson(
    _normalizeResponseData(response.data),
    statusCode: response.statusCode,
  );
}
```

```dart
// lib/modules/auth/data/auth_repository_impl.dart
@override
Future<AuthCredentialResult> loginWithPhone({
  required String zone,
  required String phone,
  required String password,
}) async {
  final resp = await _authApi.login(phone, password, zone: zone);
  if (resp.requiresLoginVerification) {
    final context = resp.toVerificationContext(zone: zone, phone: phone);
    if (context != null) {
      return AuthCredentialResult.success(
        uid: context.uid,
        token: '',
        user: UserInfo(uid: context.uid),
        requiresLoginVerification: true,
        verificationContext: context,
      );
    }
  }
  if (!resp.success || resp.data?.uid == null || resp.data?.token == null) {
    return AuthCredentialResult.failure(resp.msg ?? '登录失败');
  }
  return AuthCredentialResult.success(
    uid: resp.data!.uid!,
    token: resp.data!.token!,
    user: resp.data!.toUserInfo(),
  );
}

@override
Future<void> sendLoginVerificationCode(String uid) {
  return _authApi.sendLoginVerificationCode(uid);
}

@override
Future<AuthCredentialResult> verifyLoginCode({
  required String uid,
  required String code,
}) async {
  final resp = await _authApi.verifyLoginCode(uid: uid, code: code);
  if (!resp.success || resp.data?.uid == null || resp.data?.token == null) {
    return AuthCredentialResult.failure(resp.msg ?? '登录验证失败');
  }
  return AuthCredentialResult.success(
    uid: resp.data!.uid!,
    token: resp.data!.token!,
    user: resp.data!.toUserInfo(),
  );
}

@override
Future<UserInfo> completeProfile({
  required String name,
  int? sex,
  String? avatarFilePath,
}) async {
  String? avatarUrl;
  if (avatarFilePath != null && avatarFilePath.trim().isNotEmpty) {
    avatarUrl = await _userApi.uploadAvatar(avatarFilePath.trim());
  }
  await _userApi.updateUserInfo(
    name: name,
    sex: sex,
    avatar: avatarUrl,
  );
  return _userApi.getCurrentUser();
}
```

```dart
// lib/modules/auth/application/auth_flow_controller.dart
Future<void> loginWithPhone({
  required String zone,
  required String phone,
  required String password,
}) async {
  state = state.copyWith(
    stage: AuthStage.submittingCredentials,
    isLoading: true,
    errorMessage: null,
    zone: zone,
  );

  final result = await _repository.loginWithPhone(
    zone: zone,
    phone: phone,
    password: password,
  );

  if (result.requiresLoginVerification && result.verificationContext != null) {
    state = state.copyWith(
      stage: AuthStage.awaitingLoginVerification,
      isLoading: false,
      verificationContext: result.verificationContext,
    );
    return;
  }

  if (!result.success) {
    state = state.copyWith(
      stage: AuthStage.unauthenticated,
      isLoading: false,
      errorMessage: result.message,
    );
    return;
  }

  final bootstrapResult = await _bootstrapCoordinator.bootstrap(result);
  await _authNotifier.commitBootstrapResult(bootstrapResult);
  state = state.copyWith(stage: bootstrapResult.stage, isLoading: false);
}

Future<void> sendLoginVerificationCode() async {
  final context = state.verificationContext;
  if (context == null) {
    return;
  }
  await _repository.sendLoginVerificationCode(context.uid);
}

Future<void> verifyLoginCode(String code) async {
  final context = state.verificationContext;
  if (context == null) {
    return;
  }
  state = state.copyWith(stage: AuthStage.awaitingLoginVerification, isLoading: true);
  final result = await _repository.verifyLoginCode(
    uid: context.uid,
    code: code,
  );
  if (!result.success) {
    state = state.copyWith(isLoading: false, errorMessage: result.message);
    return;
  }
  final bootstrapResult = await _bootstrapCoordinator.bootstrap(result);
  await _authNotifier.commitBootstrapResult(bootstrapResult);
  state = state.copyWith(stage: bootstrapResult.stage, isLoading: false);
}

Future<void> completeProfile({
  required String name,
  int? sex,
  String? avatarFilePath,
}) async {
  state = state.copyWith(stage: AuthStage.awaitingProfileCompletion, isLoading: true);
  final user = await _repository.completeProfile(
    name: name,
    sex: sex,
    avatarFilePath: avatarFilePath,
  );
  _authNotifier.completeProfile(user);
  state = state.copyWith(
    stage: AuthStage.authenticatedReady,
    isLoading: false,
    errorMessage: null,
  );
}

Future<void> loginWithThirdPartyAuthCode(String authCode) async {
  state = state.copyWith(
    stage: AuthStage.submittingCredentials,
    isLoading: true,
    errorMessage: null,
  );
  final result = await _repository.loginWithThirdPartyAuthCode(authCode);
  if (!result.success) {
    state = state.copyWith(
      stage: AuthStage.unauthenticated,
      isLoading: false,
      errorMessage: result.message,
    );
    return;
  }
  final bootstrapResult = await _bootstrapCoordinator.bootstrap(result);
  await _authNotifier.commitBootstrapResult(bootstrapResult);
  state = state.copyWith(stage: bootstrapResult.stage, isLoading: false);
}
```

- [ ] **Step 4: Add profile-completion session updates and auth route gating**

```dart
// lib/data/providers/auth_provider.dart
class AuthNotifier extends StateNotifier<AuthState> {
  void completeProfile(UserInfo user) {
    state = state.copyWith(
      isLoggedIn: true,
      needsProfileCompletion: false,
      userInfo: user,
      error: null,
    );
  }
}
```

```dart
// lib/app/navigation/app_route_location.dart
class AppRouteLocation {
  static const String authRegister = '/auth/register';
  static const String authResetPassword = '/auth/reset-password';
  static const String authLoginVerification = '/auth/login-verification';
  static const String authProfileCompletion = '/auth/profile-completion';
  static const String authDeviceSessions = '/auth/device-sessions';
  static const String authWebLoginConfirm = '/auth/web-login-confirm';
  static const String authThirdLogin = '/auth/third-login';
}
```

```dart
// lib/app/navigation/app_route_resolver.dart
class AppRouteResolver {
  static String? resolve({
    required AuthState authState,
    required AuthFlowState authFlowState,
    required String location,
  }) {
    final path = _normalizePath(location);

    if (authState.isRestoringSession) {
      return path == AppRouteLocation.boot ? null : AppRouteLocation.boot;
    }

    if (authFlowState.stage == AuthStage.awaitingLoginVerification) {
      return path == AppRouteLocation.authLoginVerification
          ? null
          : AppRouteLocation.authLoginVerification;
    }

    if (!authState.isLoggedIn) {
      final guestAllowed = <String>{
        AppRouteLocation.login,
        AppRouteLocation.authRegister,
        AppRouteLocation.authResetPassword,
      };
      return guestAllowed.contains(path) ? null : AppRouteLocation.login;
    }

    if (authState.needsProfileCompletion) {
      return path == AppRouteLocation.authProfileCompletion
          ? null
          : AppRouteLocation.authProfileCompletion;
    }

    if (path == AppRouteLocation.root ||
        path == AppRouteLocation.boot ||
        path == AppRouteLocation.login ||
        path == AppRouteLocation.authLoginVerification) {
      return AppRouteLocation.home;
    }

    return null;
  }
}
```

- [ ] **Step 5: Implement the new verification and profile-completion pages plus router entries**

```dart
// lib/app/navigation/app_router.dart
redirect: (context, state) {
  final authState = ref.read(authProvider);
  final authFlowState = ref.read(authFlowControllerProvider);
  return AppRouteResolver.resolve(
    authState: authState,
    authFlowState: authFlowState,
    location: state.uri.toString(),
  );
},
routes: <RouteBase>[
  GoRoute(
    path: AppRouteLocation.authRegister,
    builder: (context, state) => const AuthRegisterPage(),
  ),
  GoRoute(
    path: AppRouteLocation.authResetPassword,
    builder: (context, state) => const AuthResetPasswordPage(),
  ),
  GoRoute(
    path: AppRouteLocation.authLoginVerification,
    builder: (context, state) => const AuthLoginVerificationPage(),
  ),
  GoRoute(
    path: AppRouteLocation.authProfileCompletion,
    builder: (context, state) => const AuthProfileCompletionPage(),
  ),
]
```

```dart
// lib/modules/auth/presentation/pages/auth_login_verification_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth_providers.dart';
import '../widgets/auth_flow_shell.dart';

class AuthLoginVerificationPage extends ConsumerStatefulWidget {
  const AuthLoginVerificationPage({super.key});

  @override
  ConsumerState<AuthLoginVerificationPage> createState() =>
      _AuthLoginVerificationPageState();
}

class _AuthLoginVerificationPageState
    extends ConsumerState<AuthLoginVerificationPage> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authFlowControllerProvider);
    final contextData = state.verificationContext;
    return AuthFlowShell(
      title: '登录验证',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('为了保护账号安全，请先完成短信验证。'),
          if (contextData != null)
            Text('验证码将发送到 +${contextData.zone} ${contextData.phone}'),
          const SizedBox(height: 16),
          FilledButton.tonal(
            key: const ValueKey('auth-login-verification-send-code'),
            onPressed: () {
              ref.read(authFlowControllerProvider.notifier).sendLoginVerificationCode();
            },
            child: const Text('发送验证码'),
          ),
          TextField(
            controller: _codeController,
            decoration: const InputDecoration(labelText: '验证码'),
          ),
          FilledButton(
            key: const ValueKey('auth-login-verification-submit'),
            onPressed: () {
              ref.read(authFlowControllerProvider.notifier).verifyLoginCode(
                    _codeController.text.trim(),
                  );
            },
            child: const Text('确认登录'),
          ),
        ],
      ),
    );
  }
}
```

```dart
// lib/modules/auth/presentation/pages/auth_profile_completion_page.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth_providers.dart';
import '../widgets/auth_flow_shell.dart';

class AuthProfileCompletionPage extends ConsumerStatefulWidget {
  const AuthProfileCompletionPage({super.key});

  @override
  ConsumerState<AuthProfileCompletionPage> createState() =>
      _AuthProfileCompletionPageState();
}

class _AuthProfileCompletionPageState
    extends ConsumerState<AuthProfileCompletionPage> {
  final _nameController = TextEditingController();
  String? _avatarFilePath;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthFlowShell(
      title: '完善个人资料',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            key: const ValueKey('auth-profile-avatar'),
            onPressed: _pickAvatar,
            child: Text(_avatarFilePath == null ? '选择头像' : '已选择头像'),
          ),
          TextField(
            key: const ValueKey('auth-profile-name'),
            controller: _nameController,
            decoration: const InputDecoration(labelText: '昵称'),
          ),
          FilledButton(
            key: const ValueKey('auth-profile-submit'),
            onPressed: () {
              ref.read(authFlowControllerProvider.notifier).completeProfile(
                    name: _nameController.text.trim(),
                    avatarFilePath: _avatarFilePath,
                  );
            },
            child: const Text('完成并进入应用'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      allowMultiple: false,
      withData: false,
    );
    final path = result?.files.single.path?.trim() ?? '';
    if (path.isEmpty || !mounted) {
      return;
    }
    setState(() => _avatarFilePath = path);
  }
}
```

- [ ] **Step 6: Run the verification/profile and router verification**

Run: `flutter test test/modules/auth/auth_verification_profile_flow_test.dart`
Expected: PASS with verification, profile completion, and route redirect coverage green

Run: `flutter test test/app/navigation/app_router_test.dart`
Expected: PASS with router redirects updated for register, reset-password, verification, and profile-completion routes

Run: `flutter analyze lib/modules/auth lib/app/navigation lib/service/api/auth_api.dart lib/data/providers/auth_provider.dart`
Expected: PASS with the controller, routes, and new pages analyzer-clean

- [ ] **Step 7: Checkpoint**

```bash
git add lib/modules/auth/presentation/pages/auth_login_verification_page.dart lib/modules/auth/presentation/pages/auth_profile_completion_page.dart lib/modules/auth/application/auth_flow_controller.dart lib/modules/auth/domain/auth_repository.dart lib/modules/auth/data/auth_repository_impl.dart lib/data/providers/auth_provider.dart lib/service/api/auth_api.dart lib/service/api/user_api.dart lib/app/navigation/app_route_location.dart lib/app/navigation/app_route_resolver.dart lib/app/navigation/app_router.dart test/modules/auth/auth_verification_profile_flow_test.dart
git commit -m "feat: add login verification and profile completion routing"
```

### Task 5: Integrate Web Login Confirmation, Device Sessions, Third-Party Login, And Scan Routing

**Files:**
- Create: `lib/modules/auth/application/device_session_controller.dart`
- Create: `lib/modules/auth/presentation/pages/auth_device_sessions_page.dart`
- Create: `lib/modules/auth/presentation/pages/auth_web_login_confirm_page.dart`
- Create: `lib/modules/auth/presentation/pages/auth_third_login_page.dart`
- Test: `test/modules/auth/auth_device_sessions_web_login_test.dart`
- Modify: `lib/modules/auth/domain/auth_repository.dart`
- Modify: `lib/modules/auth/data/auth_repository_impl.dart`
- Modify: `lib/modules/auth/application/auth_providers.dart`
- Modify: `lib/service/api/login_bridge_api.dart`
- Modify: `lib/service/api/common_api.dart`
- Modify: `lib/data/providers/runtime_capabilities_provider.dart`
- Modify: `lib/app/navigation/app_router.dart`
- Modify: `lib/wukong_scan/scan_result_page.dart`

- [ ] **Step 1: Write the failing device/Web-login/scan tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/auth/application/device_session_controller.dart';
import 'package:wukong_im_app/service/api/login_bridge_api.dart';

class _FakeDeviceRepository implements DeviceSessionRepository {
  @override
  Future<List<LoginBridgeDeviceRecord>> loadDevices() async {
    return const <LoginBridgeDeviceRecord>[
      LoginBridgeDeviceRecord(
        id: 1,
        deviceId: 'desktop-1',
        deviceName: 'MacBook Pro',
        deviceModel: 'macOS',
        lastLogin: '2026-04-04 12:00:00',
        self: false,
      ),
    ];
  }

  @override
  Future<void> deleteDevice(String deviceId) async {}

  @override
  Future<void> quitPcWebSessions() async {}
}

void main() {
  test('device session controller loads device records', () async {
    final controller = DeviceSessionController(repository: _FakeDeviceRepository());

    await controller.load();

    expect(controller.state.items, hasLength(1));
    expect(controller.state.items.single.deviceId, 'desktop-1');
  });
}
```

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_third_login_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_web_login_confirm_page.dart';

void main() {
  testWidgets('web login confirm page shows confirm and cancel actions', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AuthWebLoginConfirmPage(authCode: 'auth-1', encrypt: 'enc-1'),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('auth-web-login-confirm')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-web-login-cancel')), findsOneWidget);
  });

  testWidgets('third login page exposes capability-gated start button', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AuthThirdLoginPage()),
      ),
    );

    expect(find.byKey(const ValueKey('auth-third-login-start')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the device/Web-login tests to verify they fail**

Run: `flutter test test/modules/auth/auth_device_sessions_web_login_test.dart`
Expected: FAIL with missing `DeviceSessionController`, missing auth device pages, or missing scan-routing integration

- [ ] **Step 3: Add device-session and external-login repository APIs**

```dart
// lib/modules/auth/domain/auth_repository.dart
abstract class DeviceSessionRepository {
  Future<List<LoginBridgeDeviceRecord>> loadDevices();
  Future<void> deleteDevice(String deviceId);
  Future<void> quitPcWebSessions();
}

abstract class AuthRepository implements DeviceSessionRepository {
  Future<void> grantWebLogin({
    required String authCode,
    String? encrypt,
  });

  Future<String> loadThirdLoginAuthCode();

  Future<ThirdLoginStatusResult> loadThirdLoginStatus(String authCode);

  Future<AuthCredentialResult> loginWithThirdPartyAuthCode(String authCode);
}
```

```dart
// lib/modules/auth/data/auth_repository_impl.dart
@override
Future<List<LoginBridgeDeviceRecord>> loadDevices() {
  return _loginBridgeApi.getDevices();
}

@override
Future<void> deleteDevice(String deviceId) {
  return _loginBridgeApi.deleteDevice(deviceId);
}

@override
Future<void> quitPcWebSessions() {
  return _loginBridgeApi.quitPc();
}

@override
Future<void> grantWebLogin({
  required String authCode,
  String? encrypt,
}) {
  return _loginBridgeApi.grantLogin(authCode, encrypt: encrypt);
}

@override
Future<String> loadThirdLoginAuthCode() {
  return _loginBridgeApi.getThirdLoginAuthCode();
}

@override
Future<ThirdLoginStatusResult> loadThirdLoginStatus(String authCode) {
  return _loginBridgeApi.getThirdLoginAuthStatus(authCode);
}

@override
Future<AuthCredentialResult> loginWithThirdPartyAuthCode(String authCode) async {
  final resp = await _loginBridgeApi.loginWithAuthCode(authCode);
  if (!resp.success || resp.data?.uid == null || resp.data?.token == null) {
    return AuthCredentialResult.failure(resp.msg ?? '第三方登录失败');
  }
  return AuthCredentialResult.success(
    uid: resp.data!.uid!,
    token: resp.data!.token!,
    user: resp.data!.toUserInfo(),
  );
}
```

```dart
// lib/modules/auth/application/device_session_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../service/api/login_bridge_api.dart';
import '../domain/auth_repository.dart';

@immutable
class DeviceSessionState {
  const DeviceSessionState({
    this.items = const <LoginBridgeDeviceRecord>[],
    this.isLoading = false,
    this.isQuittingAll = false,
    this.error,
  });

  final List<LoginBridgeDeviceRecord> items;
  final bool isLoading;
  final bool isQuittingAll;
  final String? error;

  DeviceSessionState copyWith({
    List<LoginBridgeDeviceRecord>? items,
    bool? isLoading,
    bool? isQuittingAll,
    String? error,
  }) {
    return DeviceSessionState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isQuittingAll: isQuittingAll ?? this.isQuittingAll,
      error: error,
    );
  }
}

class DeviceSessionController extends StateNotifier<DeviceSessionState> {
  DeviceSessionController({
    required DeviceSessionRepository repository,
  }) : _repository = repository,
       super(const DeviceSessionState());

  final DeviceSessionRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await _repository.loadDevices();
      state = state.copyWith(items: items, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> remove(String deviceId) async {
    await _repository.deleteDevice(deviceId);
    await load();
  }

  Future<void> quitAllPcWeb() async {
    state = state.copyWith(isQuittingAll: true, error: null);
    try {
      await _repository.quitPcWebSessions();
      await load();
    } finally {
      state = state.copyWith(isQuittingAll: false);
    }
  }
}
```

- [ ] **Step 4: Wire capability-gated pages and scan-result routing**

```dart
// lib/modules/auth/application/auth_providers.dart
final deviceSessionControllerProvider =
    StateNotifierProvider.autoDispose<DeviceSessionController, DeviceSessionState>((ref) {
  return DeviceSessionController(
    repository: ref.read(authRepositoryProvider),
  )..load();
});
```

```dart
// lib/service/api/common_api.dart
class AppRuntimeCapabilities {
  const AppRuntimeCapabilities({
    required this.webLoginUrl,
    required this.webLoginReachable,
    required this.webLoginStatusMessage,
    this.thirdLoginEnabled = false,
    this.thirdLoginStatusMessage = '服务端未开启第三方登录',
    this.inviteCodeRequired = false,
    this.inviteCodeStatusMessage = '当前注册无需邀请码',
    this.shortNoEditable = false,
    this.shortNoEditStatusMessage = '',
    this.phoneSearchEnabled = true,
    this.phoneSearchStatusMessage = '',
    this.momentsEnabled = true,
    this.momentsStatusMessage = '',
  });

  final bool thirdLoginEnabled;
  final String thirdLoginStatusMessage;
  final bool inviteCodeRequired;
  final String inviteCodeStatusMessage;
}
```

```dart
// lib/app/navigation/app_router.dart
GoRoute(
  path: AppRouteLocation.authDeviceSessions,
  builder: (context, state) => const AuthDeviceSessionsPage(),
),
GoRoute(
  path: AppRouteLocation.authWebLoginConfirm,
  builder: (context, state) => AuthWebLoginConfirmPage(
    authCode: state.uri.queryParameters['authCode'] ?? '',
    encrypt: state.uri.queryParameters['encrypt'],
  ),
),
GoRoute(
  path: AppRouteLocation.authThirdLogin,
  builder: (context, state) => const AuthThirdLoginPage(),
),
```

```dart
// lib/modules/auth/presentation/pages/auth_web_login_confirm_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth_providers.dart';
import '../widgets/auth_flow_shell.dart';

class AuthWebLoginConfirmPage extends ConsumerWidget {
  const AuthWebLoginConfirmPage({
    super.key,
    required this.authCode,
    this.encrypt,
  });

  final String authCode;
  final String? encrypt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuthFlowShell(
      title: '确认 Web 登录',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('请确认是否允许当前 Web 或桌面端登录你的账号。'),
          FilledButton(
            key: const ValueKey('auth-web-login-confirm'),
            onPressed: () async {
              await ref.read(authRepositoryProvider).grantWebLogin(
                    authCode: authCode,
                    encrypt: encrypt,
                  );
            },
            child: const Text('确认登录'),
          ),
          OutlinedButton(
            key: const ValueKey('auth-web-login-cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
}
```

```dart
// lib/modules/auth/presentation/pages/auth_device_sessions_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth_providers.dart';
import '../widgets/auth_flow_shell.dart';

class AuthDeviceSessionsPage extends ConsumerWidget {
  const AuthDeviceSessionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deviceSessionControllerProvider);
    final controller = ref.read(deviceSessionControllerProvider.notifier);
    return AuthFlowShell(
      title: '登录设备管理',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.tonal(
            onPressed: state.isQuittingAll ? null : controller.quitAllPcWeb,
            child: const Text('退出全部 PC/Web 登录'),
          ),
          ...state.items.map(
            (item) => ListTile(
              key: ValueKey('auth-device-${item.deviceId}'),
              title: Text(item.deviceName),
              subtitle: Text(item.lastLogin),
              trailing: item.self
                  ? const Text('当前设备')
                  : TextButton(
                      onPressed: () => controller.remove(item.deviceId),
                      child: const Text('移除'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
```

```dart
// lib/modules/auth/presentation/pages/auth_third_login_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/runtime_capabilities_provider.dart';
import '../../application/auth_providers.dart';
import '../widgets/auth_flow_shell.dart';

class AuthThirdLoginPage extends ConsumerStatefulWidget {
  const AuthThirdLoginPage({super.key});

  @override
  ConsumerState<AuthThirdLoginPage> createState() => _AuthThirdLoginPageState();
}

class _AuthThirdLoginPageState extends ConsumerState<AuthThirdLoginPage> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = ref.watch(runtimeCapabilitiesProvider);
    return AuthFlowShell(
      title: '第三方登录',
      child: capabilities.when(
        data: (data) {
          if (!data.thirdLoginEnabled) {
            return Text(data.thirdLoginStatusMessage);
          }
          return FilledButton(
            key: const ValueKey('auth-third-login-start'),
            onPressed: _startThirdLogin,
            child: const Text('开始第三方登录'),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Text(error.toString()),
      ),
    );
  }

  Future<void> _startThirdLogin() async {
    final authCode = await ref.read(authRepositoryProvider).loadThirdLoginAuthCode();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final status = await ref.read(authRepositoryProvider).loadThirdLoginStatus(authCode);
      if (status.isSuccess && mounted) {
        _timer?.cancel();
        await ref.read(authFlowControllerProvider.notifier).loginWithThirdPartyAuthCode(authCode);
      }
    });
  }
}
```

```dart
// lib/wukong_scan/scan_result_page.dart
if (result.type == ScanResultType.webLogin &&
    result.authCode.isNotEmpty) {
  context.push(
    '${AppRouteLocation.authWebLoginConfirm}?authCode=${Uri.encodeComponent(result.authCode)}&encrypt=${Uri.encodeComponent(result.encrypt ?? '')}',
  );
  return;
}
```

- [ ] **Step 5: Register the new routes and run the external-login verification**

Run: `flutter test test/modules/auth/auth_device_sessions_web_login_test.dart`
Expected: PASS with device loading, Web-login confirmation actions, and third-login entry coverage green

Run: `flutter analyze lib/modules/auth lib/service/api/login_bridge_api.dart lib/service/api/common_api.dart lib/wukong_scan/scan_result_page.dart`
Expected: PASS with device-session, third-login, and scan-route changes analyzer-clean

Run: `flutter test test/wukong_scan/scan_service_test.dart`
Expected: PASS with scan-service behavior unchanged apart from routed login confirmation

- [ ] **Step 6: Validate real backend behavior if any payload mismatch remains**

Run: `ssh root@103.207.68.33 "docker ps --format '{{.Names}}'"`
Expected: includes `fullstack-tangsengdaodaoserver-1`

Run: `ssh root@103.207.68.33 "docker logs --tail 200 fullstack-tangsengdaodaoserver-1 | grep -E 'loginuuid|loginstatus|grant_login|thirdlogin|devices'"`
Expected: confirms the deployed payload shape for QR login, device sessions, and third-party login endpoints

- [ ] **Step 7: Checkpoint**

```bash
git add lib/modules/auth/application/device_session_controller.dart lib/modules/auth/presentation/pages/auth_device_sessions_page.dart lib/modules/auth/presentation/pages/auth_web_login_confirm_page.dart lib/modules/auth/presentation/pages/auth_third_login_page.dart lib/modules/auth/domain/auth_repository.dart lib/modules/auth/data/auth_repository_impl.dart lib/modules/auth/application/auth_providers.dart lib/service/api/login_bridge_api.dart lib/service/api/common_api.dart lib/data/providers/runtime_capabilities_provider.dart lib/app/navigation/app_router.dart lib/wukong_scan/scan_result_page.dart test/modules/auth/auth_device_sessions_web_login_test.dart
git commit -m "feat: add web login confirmation and device session flows"
```

### Task 6: Converge Legacy Entrypoints, Clean Auth Copy, And Run Full Validation

**Files:**
- Create: `test/modules/auth/auth_routes_compile_test.dart`
- Modify: `lib/modules/auth/login_page.dart`
- Modify: `lib/modules/auth/register_page.dart`
- Modify: `lib/modules/auth/auth_shell.dart`
- Modify: `lib/wukong_login/login_page.dart`
- Modify: `lib/wukong_login/pc_login_page.dart`
- Modify: `lib/wukong_login/web_login_confirm_page.dart`
- Modify: `lib/wukong_login/third_login_page.dart`
- Modify: `lib/wukong_login/pc_login_management_page.dart`
- Modify: `lib/wukong_login/login_exports.dart`
- Modify: `lib/app/navigation/app_router.dart`

- [ ] **Step 1: Write the failing route-compile and compatibility tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_device_sessions_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_login_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_login_verification_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_profile_completion_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_register_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_reset_password_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_third_login_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_web_login_confirm_page.dart';
import 'package:wukong_im_app/wukong_login/login_page.dart' as legacy_login;
import 'package:wukong_im_app/wukong_login/pc_login_management_page.dart' as legacy_pc_manage;

void main() {
  testWidgets('all auth pages compile inside ProviderScope', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AuthLoginPage()),
      ),
    );

    expect(const AuthRegisterPage(), isA<Widget>());
    expect(const AuthResetPasswordPage(), isA<Widget>());
    expect(const AuthLoginVerificationPage(), isA<Widget>());
    expect(const AuthProfileCompletionPage(), isA<Widget>());
    expect(const AuthDeviceSessionsPage(), isA<Widget>());
    expect(const AuthWebLoginConfirmPage(authCode: 'auth-1'), isA<Widget>());
    expect(const AuthThirdLoginPage(), isA<Widget>());
  });

  testWidgets('legacy wukong_login entrypoints wrap the new auth pages', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: legacy_login.LoginPage()),
      ),
    );

    expect(find.byType(AuthLoginPage), findsOneWidget);
    expect(const legacy_pc_manage.PCLoginManagementPage(), isA<Widget>());
  });
}
```

- [ ] **Step 2: Run the compatibility tests to verify they fail**

Run: `flutter test test/modules/auth/auth_routes_compile_test.dart`
Expected: FAIL with legacy wrappers still bound to old implementations or with new auth pages not fully routable

- [ ] **Step 3: Replace the legacy entrypoints with thin wrappers over the new mainline**

```dart
// lib/wukong_login/login_page.dart
import 'package:flutter/widgets.dart';

import '../modules/auth/presentation/pages/auth_login_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) => const AuthLoginPage();
}
```

```dart
// lib/modules/auth/auth_shell.dart
export 'presentation/widgets/auth_flow_shell.dart';
```

```dart
// lib/wukong_login/pc_login_page.dart
import 'package:flutter/widgets.dart';

import '../modules/auth/presentation/pages/auth_device_sessions_page.dart';

class PCLoginPage extends StatelessWidget {
  const PCLoginPage({super.key});

  @override
  Widget build(BuildContext context) => const AuthDeviceSessionsPage();
}
```

```dart
// lib/wukong_login/web_login_confirm_page.dart
import 'package:flutter/widgets.dart';

import '../modules/auth/presentation/pages/auth_web_login_confirm_page.dart';

class WebLoginConfirmPage extends StatelessWidget {
  const WebLoginConfirmPage({
    super.key,
    required this.authCode,
    this.encrypt,
  });

  final String authCode;
  final String? encrypt;

  @override
  Widget build(BuildContext context) {
    return AuthWebLoginConfirmPage(
      authCode: authCode,
      encrypt: encrypt,
    );
  }
}
```

```dart
// lib/wukong_login/third_login_page.dart
import 'package:flutter/widgets.dart';

import '../modules/auth/presentation/pages/auth_third_login_page.dart';

class ThirdLoginPage extends StatelessWidget {
  const ThirdLoginPage({super.key});

  @override
  Widget build(BuildContext context) => const AuthThirdLoginPage();
}
```

```dart
// lib/wukong_login/pc_login_management_page.dart
import 'package:flutter/widgets.dart';

import '../modules/auth/presentation/pages/auth_device_sessions_page.dart';

class PCLoginManagementPage extends StatelessWidget {
  const PCLoginManagementPage({super.key});

  @override
  Widget build(BuildContext context) => const AuthDeviceSessionsPage();
}
```

```dart
// lib/wukong_login/login_exports.dart
export '../modules/auth/presentation/pages/auth_login_page.dart';
export '../modules/auth/presentation/pages/auth_device_sessions_page.dart';
export '../modules/auth/presentation/pages/auth_web_login_confirm_page.dart';
export '../modules/auth/presentation/pages/auth_third_login_page.dart';
```

- [ ] **Step 4: Run the full auth verification matrix**

Run: `flutter analyze lib/modules/auth lib/data/providers/auth_provider.dart lib/service/api/auth_api.dart lib/service/api/login_bridge_api.dart lib/service/api/common_api.dart lib/service/api/user_api.dart lib/app/navigation lib/wukong_login lib/wukong_scan/scan_result_page.dart`
Expected: PASS with the whole auth/device-login mainline analyzer-clean

Run: `flutter test test/modules/auth/auth_bootstrap_coordinator_test.dart test/modules/auth/auth_login_page_test.dart test/modules/auth/auth_register_reset_page_test.dart test/modules/auth/auth_verification_profile_flow_test.dart test/modules/auth/auth_device_sessions_web_login_test.dart test/modules/auth/auth_routes_compile_test.dart`
Expected: PASS with all new auth tests green

Run: `flutter test test/app/navigation/app_router_test.dart test/realtime/device/device_identity_login_flow_test.dart test/wukong_scan/scan_service_test.dart`
Expected: PASS with router, device identity, and scan flows still green

- [ ] **Step 5: Verify the deployed server against the completed auth flow set**

Run: `ssh root@103.207.68.33 "docker ps --format '{{.Names}}'"`
Expected: includes `fullstack-tangsengdaodaoserver-1`

Run: `ssh root@103.207.68.33 "docker logs --tail 300 fullstack-tangsengdaodaoserver-1 | grep -E 'login_check_phone|check_phone|loginuuid|grant_login|thirdlogin|devices'"`
Expected: no backend-side errors for login verification, QR confirmation, or device-session endpoints after the Flutter flow set is exercised

- [ ] **Step 6: Checkpoint**

```bash
git add lib/modules/auth/login_page.dart lib/modules/auth/register_page.dart lib/modules/auth/auth_shell.dart lib/wukong_login/login_page.dart lib/wukong_login/pc_login_page.dart lib/wukong_login/web_login_confirm_page.dart lib/wukong_login/third_login_page.dart lib/wukong_login/pc_login_management_page.dart lib/wukong_login/login_exports.dart lib/app/navigation/app_router.dart test/modules/auth/auth_routes_compile_test.dart
git commit -m "feat: converge legacy auth entrypoints on the new mainline"
```

## Self-Review Checklist

- Spec coverage:
  - the auth kernel, repository, and bootstrap transaction are covered by Task 1
  - Android-style login and shared area-code behavior are covered by Task 2
  - register and reset-password flows are covered by Task 3
  - login verification, profile completion, and route gating are covered by Task 4
  - Web login confirmation, device sessions, third-party login, and scan routing are covered by Task 5
  - legacy wrapper convergence and final verification are covered by Task 6
- Placeholder scan:
  - no `TODO`, `TBD`, or "implement later" markers remain in executable steps
  - every task includes explicit file paths, concrete code, and exact verification commands
- Type consistency:
  - `AuthFlowState`, `AuthStage`, `AuthCredentialResult`, `AuthBootstrapResult`, `AuthRepository`, `DeviceSessionController`, and the auth route constants use one stable naming scheme through the whole plan

## Expected Outcome

After this plan is implemented:

- Android users enter one authoritative auth mainline rooted in `lib/modules/auth`
- login, register, reset-password, login-verification, profile completion, Web-login confirmation, device-session management, and third-party login all follow one typed state and routing contract
- post-auth bootstrap happens once, in one coordinator, instead of being reimplemented across multiple pages
- old `wukong_login` pages stop competing with the mainline and become thin compatibility surfaces
- the Flutter app keeps Android-visible behavior while exceeding the reference implementation in orchestration, diagnostics, and resilience
