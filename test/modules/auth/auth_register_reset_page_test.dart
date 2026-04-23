import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wukong_im_app/app/navigation/app_route_location.dart';
import 'package:wukong_im_app/core/config/app_config.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/data/providers/auth_provider.dart';
import 'package:wukong_im_app/data/providers/runtime_capabilities_provider.dart';
import 'package:wukong_im_app/modules/auth/application/auth_flow_controller.dart';
import 'package:wukong_im_app/modules/auth/application/auth_providers.dart';
import 'package:wukong_im_app/modules/auth/coordinators/auth_bootstrap_coordinator.dart';
import 'package:wukong_im_app/modules/auth/domain/auth_flow_models.dart';
import 'package:wukong_im_app/modules/auth/domain/auth_repository.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_login_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_register_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_reset_password_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/widgets/auth_action_button.dart';
import 'package:wukong_im_app/modules/auth/presentation/widgets/auth_copy.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry_provider.dart';
import 'package:wukong_im_app/service/api/common_api.dart';
import 'package:wukong_im_app/service/api/login_bridge_api.dart';
import 'package:wukong_im_app/widgets/wk_button.dart';

class _RecordingAuthRepository implements AuthRepository {
  int sendRegisterCodeAttemptCount = 0;
  int sendRegisterCodeCallCount = 0;
  int sendResetPasswordCodeAttemptCount = 0;
  int sendResetPasswordCodeCallCount = 0;
  int resetPasswordCallCount = 0;
  int registerWithPhoneCallCount = 0;
  bool throwOnSendRegisterCode = false;
  bool throwOnSendResetPasswordCode = false;
  bool throwOnResetPassword = false;

  String? lastSendRegisterCodeZone;
  String? lastSendRegisterCodePhone;
  String? lastSendResetPasswordCodeZone;
  String? lastSendResetPasswordCodePhone;
  String? lastResetZone;
  String? lastResetPhone;
  String? lastResetCode;
  String? lastResetPassword;
  String? lastRegisterZone;
  String? lastRegisterPhone;
  String? lastRegisterCode;
  String? lastRegisterPassword;
  String? lastRegisterInviteCode;
  String? lastRegisterDisplayName;

  @override
  Future<AuthCredentialResult> loginWithPhone({
    required String zone,
    required String phone,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthCredentialResult> loginWithUsername({
    required String username,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthCredentialResult> registerWithPhone({
    required String zone,
    required String phone,
    required String code,
    required String password,
    String? inviteCode,
    String? displayName,
  }) async {
    registerWithPhoneCallCount += 1;
    lastRegisterZone = zone;
    lastRegisterPhone = phone;
    lastRegisterCode = code;
    lastRegisterPassword = password;
    lastRegisterInviteCode = inviteCode;
    lastRegisterDisplayName = displayName;
    return AuthCredentialResult.success(
      uid: 'u-register',
      token: 't-register',
      user: UserInfo(
        uid: 'u-register',
        token: 't-register',
        name: 'Register User',
        avatar: 'avatar.png',
        phone: phone,
        zone: zone,
      ),
    );
  }

  @override
  Future<void> resetPassword({
    required String zone,
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    if (throwOnResetPassword) {
      throw Exception('reset password failed');
    }
    resetPasswordCallCount += 1;
    lastResetZone = zone;
    lastResetPhone = phone;
    lastResetCode = code;
    lastResetPassword = newPassword;
  }

  @override
  Future<void> sendRegisterCode({
    required String zone,
    required String phone,
  }) async {
    sendRegisterCodeAttemptCount += 1;
    lastSendRegisterCodeZone = zone;
    lastSendRegisterCodePhone = phone;
    if (throwOnSendRegisterCode) {
      throw Exception('send register code failed');
    }
    sendRegisterCodeCallCount += 1;
  }

  @override
  Future<void> sendResetPasswordCode({
    required String zone,
    required String phone,
  }) async {
    sendResetPasswordCodeAttemptCount += 1;
    lastSendResetPasswordCodeZone = zone;
    lastSendResetPasswordCodePhone = phone;
    if (throwOnSendResetPasswordCode) {
      throw Exception('send reset code failed');
    }
    sendResetPasswordCodeCallCount += 1;
  }

  @override
  Future<void> sendLoginVerificationCode(String uid) async {}

  @override
  Future<AuthCredentialResult> verifyLoginCode({
    required String uid,
    required String code,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<UserInfo> completeProfile({
    required String name,
    int? sex,
    String? avatarFilePath,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> grantWebLogin({
    required String authCode,
    String? encrypt,
  }) async {}

  @override
  Future<String> loadThirdLoginAuthCode() async => 'auth-code';

  @override
  Future<ThirdLoginStatusResult> loadThirdLoginStatus(String authCode) async {
    return const ThirdLoginStatusResult(status: 0);
  }

  @override
  Future<AuthCredentialResult> loginWithThirdPartyAuthCode(
    String authCode,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<List<LoginBridgeDeviceRecord>> loadDevices() async {
    return const <LoginBridgeDeviceRecord>[];
  }

  @override
  Future<void> deleteDevice(String deviceId) async {}

  @override
  Future<void> quitPcWebSessions() async {}

  @override
  Future<UserInfo?> getCurrentUser() async => null;
}

class _RecordingAuthNotifier extends AuthNotifier {
  _RecordingAuthNotifier(super.ref);

  int commitBootstrapResultCallCount = 0;
  AuthBootstrapResult? lastBootstrapResult;

  @override
  Future<void> commitBootstrapResult(AuthBootstrapResult result) async {
    commitBootstrapResultCallCount += 1;
    lastBootstrapResult = result;
    await super.commitBootstrapResult(result);
  }
}

_RecordingAuthNotifier _buildAuthNotifier() {
  final telemetry = RealtimeRolloutTelemetry(flushInterval: Duration.zero);
  addTearDown(telemetry.dispose);
  final container = ProviderContainer(
    overrides: [
      authProvider.overrideWith((ref) => _RecordingAuthNotifier(ref)),
      authCurrentUserLoaderProvider.overrideWithValue(() async => null),
      authDraftSyncProvider.overrideWithValue(() async {}),
      realtimeRolloutTelemetryProvider.overrideWithValue(telemetry),
    ],
  );
  addTearDown(container.dispose);
  return container.read(authProvider.notifier) as _RecordingAuthNotifier;
}

AuthFlowController _buildController({
  required _RecordingAuthRepository repository,
  required _RecordingAuthNotifier notifier,
}) {
  return AuthFlowController(
    repository: repository,
    bootstrapCoordinator: _buildBootstrapCoordinator(),
    authNotifier: notifier,
  );
}

AuthBootstrapCoordinator _buildBootstrapCoordinator() {
  return AuthBootstrapCoordinator(
    persistSession: ({required uid, required token, required imToken}) async {},
    rollbackSession: () async {},
    bindDeviceIdentity: ({required uid, required token}) async {},
    loadCurrentUser: () async => UserInfo(
      uid: 'u-register',
      token: 't-register',
      name: 'Register User',
      avatar: 'avatar.png',
    ),
    initializeAuthenticatedRuntime: (_) async {},
    registerPush: () async {},
    syncDrafts: () async {},
  );
}

Future<void> _pumpRegisterPage(
  WidgetTester tester, {
  required _RecordingAuthRepository repository,
  AppRuntimeCapabilities? capabilities,
}) async {
  final notifier = _buildAuthNotifier();
  final controller = _buildController(
    repository: repository,
    notifier: notifier,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authFlowControllerProvider.overrideWith((ref) => controller),
        runtimeCapabilitiesProvider.overrideWith(
          (ref) async =>
              capabilities ??
              const AppRuntimeCapabilities(
                webLoginUrl: '',
                webLoginReachable: false,
                webLoginStatusMessage: 'disabled',
              ),
        ),
      ],
      child: const MaterialApp(home: AuthRegisterPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpResetPage(
  WidgetTester tester, {
  required _RecordingAuthRepository repository,
}) async {
  final notifier = _buildAuthNotifier();
  final controller = _buildController(
    repository: repository,
    notifier: notifier,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authFlowControllerProvider.overrideWith((ref) => controller)],
      child: const MaterialApp(home: AuthResetPasswordPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpResetPageWithParentRoute(
  WidgetTester tester, {
  required _RecordingAuthRepository repository,
}) async {
  final notifier = _buildAuthNotifier();
  final controller = _buildController(
    repository: repository,
    notifier: notifier,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authFlowControllerProvider.overrideWith((ref) => controller)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                const Text('parent-page'),
                WKTextButton(
                  key: const ValueKey('open_reset_page_button'),
                  text: 'open',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AuthResetPasswordPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('open_reset_page_button')));
  await tester.pumpAndSettle();
}

Future<void> _pumpRegisterPageWithParentRoute(
  WidgetTester tester, {
  required _RecordingAuthRepository repository,
}) async {
  final notifier = _buildAuthNotifier();
  final controller = _buildController(
    repository: repository,
    notifier: notifier,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authFlowControllerProvider.overrideWith((ref) => controller),
        runtimeCapabilitiesProvider.overrideWith(
          (ref) async => const AppRuntimeCapabilities(
            webLoginUrl: '',
            webLoginReachable: false,
            webLoginStatusMessage: 'disabled',
          ),
        ),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                const Text('register-parent-page'),
                WKTextButton(
                  key: const ValueKey('open_register_page_button'),
                  text: 'open',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AuthRegisterPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('open_register_page_button')));
  await tester.pumpAndSettle();
}

Future<void> _pumpRegisterPageWithGoRouterDirectEntry(
  WidgetTester tester, {
  required _RecordingAuthRepository repository,
}) async {
  final notifier = _buildAuthNotifier();
  final controller = _buildController(
    repository: repository,
    notifier: notifier,
  );
  final router = GoRouter(
    initialLocation: AppRouteLocation.register,
    routes: <RouteBase>[
      GoRoute(
        path: AppRouteLocation.login,
        builder: (context, state) => const AuthLoginPage(),
      ),
      GoRoute(
        path: AppRouteLocation.register,
        builder: (context, state) => const AuthRegisterPage(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authFlowControllerProvider.overrideWith((ref) => controller),
        runtimeCapabilitiesProvider.overrideWith(
          (ref) async => const AppRuntimeCapabilities(
            webLoginUrl: '',
            webLoginReachable: false,
            webLoginStatusMessage: 'disabled',
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectStatusBanner(
  WidgetTester tester, {
  required String message,
  String? detail,
}) {
  expect(find.byType(AlertDialog), findsNothing);
  expect(find.byKey(const ValueKey('auth-status-banner')), findsOneWidget);
  expect(find.text(message), findsWidgets);
  if (detail != null) {
    expect(find.text(detail), findsWidgets);
  }
}

void main() {
  const registerSendCodeActionKey = ValueKey<String>(
    'auth-register-send-code-action',
  );
  const resetSendCodeActionKey = ValueKey<String>(
    'auth-reset-send-code-action',
  );
  const registerPrimaryActionKey = ValueKey<String>(
    'auth-register-primary-action',
  );
  const registerSecondaryActionKey = ValueKey<String>(
    'auth-register-secondary-action',
  );

  testWidgets('register page renders within shared auth panel', (tester) async {
    final repository = _RecordingAuthRepository();

    await _pumpRegisterPage(
      tester,
      repository: repository,
      capabilities: const AppRuntimeCapabilities(
        webLoginUrl: '',
        webLoginReachable: false,
        webLoginStatusMessage: 'disabled',
        registerInviteEnabled: true,
        registerInviteRequired: true,
      ),
    );

    expect(find.text('创建账号'), findsOneWidget);
    expect(find.text('信息平权'), findsWidgets);
    expect(find.text('让全天下的人没有信息差'), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-brand-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-form-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-page-panel')), findsOneWidget);
    expect(find.byKey(registerSendCodeActionKey), findsOneWidget);
    expect(
      tester.widget<AuthActionButton>(find.byKey(registerSendCodeActionKey)),
      isNotNull,
    );
    expect(find.byKey(registerPrimaryActionKey), findsOneWidget);
    expect(find.byKey(registerSecondaryActionKey), findsOneWidget);
    expect(
      find.byKey(const ValueKey('auth_login_zone_trigger')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('auth_register_phone_field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('auth_register_code_field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('auth_register_password_field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('auth_register_nickname_field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('auth_register_invite_field')),
      findsOneWidget,
    );
    expect(find.text(AuthCopy.agreementPrefix), findsOneWidget);
    expect(find.text(AuthCopy.privacyPolicy), findsOneWidget);
    expect(find.text(AuthCopy.userAgreement), findsOneWidget);
    expect(find.text(AuthCopy.loginButton), findsOneWidget);
    expect(find.text('用户名注册'), findsNothing);
  });

  testWidgets(
    'register send-code auto-fills fixed code, hides it, and locks phone field',
    (tester) async {
      const fixedCode = '123456';
      final repository = _RecordingAuthRepository();

      await _pumpRegisterPage(tester, repository: repository);

      await tester.enterText(
        find.byKey(const ValueKey('auth_register_phone_field')),
        '13800138000',
      );
      await tester.pump();

      await tester.tap(find.byKey(registerSendCodeActionKey));
      await tester.pumpAndSettle();

      _expectStatusBanner(
        tester,
        message: AuthCopy.fixedCodeSuccessSummary,
        detail: AuthCopy.fixedCodeSuccessDetail,
      );
      expect(repository.sendRegisterCodeAttemptCount, 0);
      expect(repository.sendRegisterCodeCallCount, 0);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('auth_register_code_field')),
            )
            .controller
            ?.text,
        fixedCode,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('auth_register_code_field')),
            )
            .obscureText,
        isTrue,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('auth_register_phone_field')),
            )
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<AuthActionButton>(find.byKey(registerSendCodeActionKey))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'register send-code skips repository failures in fixed-code mode',
    (tester) async {
      const fixedCode = '123456';
      final repository = _RecordingAuthRepository()
        ..throwOnSendRegisterCode = true;

      await _pumpRegisterPage(tester, repository: repository);

      await tester.enterText(
        find.byKey(const ValueKey('auth_register_phone_field')),
        '13800138000',
      );
      await tester.pump();

      await tester.tap(find.byKey(registerSendCodeActionKey));
      await tester.pumpAndSettle();

      _expectStatusBanner(
        tester,
        message: AuthCopy.fixedCodeSuccessSummary,
        detail: AuthCopy.fixedCodeSuccessDetail,
      );
      expect(repository.sendRegisterCodeAttemptCount, 0);
      expect(repository.sendRegisterCodeCallCount, 0);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('auth_register_phone_field')),
            )
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<AuthActionButton>(find.byKey(registerSendCodeActionKey))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('auth_register_code_field')),
            )
            .controller
            ?.text,
        fixedCode,
      );
    },
  );

  testWidgets('register send-code button disabled until phone is non-empty', (
    tester,
  ) async {
    final repository = _RecordingAuthRepository();

    await _pumpRegisterPage(tester, repository: repository);

    final buttonFinder = find.byKey(registerSendCodeActionKey);
    expect(buttonFinder, findsOneWidget);
    expect(tester.widget<AuthActionButton>(buttonFinder).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('auth_register_phone_field')),
      '13800138000',
    );
    await tester.pump();

    expect(tester.widget<AuthActionButton>(buttonFinder).onPressed, isNotNull);
  });

  testWidgets(
    'register primary action stays disabled until phone, code, and password are non-empty',
    (tester) async {
      final repository = _RecordingAuthRepository();

      await _pumpRegisterPage(tester, repository: repository);

      final primaryActionFinder = find.byKey(registerPrimaryActionKey);
      expect(primaryActionFinder, findsOneWidget);
      expect(
        tester.widget<AuthActionButton>(primaryActionFinder).onPressed,
        isNull,
      );

      await tester.enterText(
        find.byKey(const ValueKey('auth_register_phone_field')),
        '13800138000',
      );
      await tester.pump();
      expect(
        tester.widget<AuthActionButton>(primaryActionFinder).onPressed,
        isNull,
      );

      await tester.enterText(
        find.byKey(const ValueKey('auth_register_code_field')),
        '123456',
      );
      await tester.pump();
      expect(
        tester.widget<AuthActionButton>(primaryActionFinder).onPressed,
        isNull,
      );

      await tester.enterText(
        find.byKey(const ValueKey('auth_register_password_field')),
        '123456',
      );
      await tester.pump();
      expect(
        tester.widget<AuthActionButton>(primaryActionFinder).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('register submit forwards trimmed optional nickname', (
    tester,
  ) async {
    final repository = _RecordingAuthRepository();

    await _pumpRegisterPage(tester, repository: repository);

    await tester.enterText(
      find.byKey(const ValueKey('auth_register_phone_field')),
      '13800138000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth_register_code_field')),
      '123456',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth_register_password_field')),
      '123456',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth_register_nickname_field')),
      '  Display Name  ',
    );
    await tester.tap(find.byKey(const ValueKey('auth_login_terms_toggle')));
    await tester.pump();

    await tester.ensureVisible(find.byKey(registerPrimaryActionKey));
    await tester.tap(find.byKey(registerPrimaryActionKey));
    await tester.pumpAndSettle();

    expect(repository.registerWithPhoneCallCount, 1);
    expect(repository.lastRegisterDisplayName, 'Display Name');
  });

  testWidgets(
    'register submit validates agreement before password length before invite-required',
    (tester) async {
      final repository = _RecordingAuthRepository();

      await _pumpRegisterPage(
        tester,
        repository: repository,
        capabilities: const AppRuntimeCapabilities(
          webLoginUrl: '',
          webLoginReachable: false,
          webLoginStatusMessage: 'disabled',
          registerInviteEnabled: true,
          registerInviteRequired: true,
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('auth_register_phone_field')),
        '13800138000',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth_register_code_field')),
        '123456',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth_register_password_field')),
        '12345',
      );
      await tester.pump();

      await tester.ensureVisible(find.byKey(registerPrimaryActionKey));
      await tester.tap(find.byKey(registerPrimaryActionKey));
      await tester.pumpAndSettle();
      _expectStatusBanner(
        tester,
        message: AuthCopy.validationSummary,
        detail: AuthCopy.errorAgreementRequired,
      );
      expect(
        find.byKey(const ValueKey('auth_register_agreement_error')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('auth_login_terms_toggle')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(registerPrimaryActionKey));
      await tester.tap(find.byKey(registerPrimaryActionKey));
      await tester.pumpAndSettle();
      _expectStatusBanner(
        tester,
        message: AuthCopy.validationSummary,
        detail: AuthCopy.errorPasswordLength,
      );
      expect(
        find.byKey(const ValueKey('auth_register_password_error')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('auth_register_password_field')),
        '123456',
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(registerPrimaryActionKey));
      await tester.tap(find.byKey(registerPrimaryActionKey));
      await tester.pumpAndSettle();
      _expectStatusBanner(
        tester,
        message: AuthCopy.validationSummary,
        detail: AuthCopy.errorInviteRequired,
      );
      expect(
        find.byKey(const ValueKey('auth_register_invite_error')),
        findsOneWidget,
      );
    },
  );

  testWidgets('register invite hint reflects required runtime capability', (
    tester,
  ) async {
    final repository = _RecordingAuthRepository();

    await _pumpRegisterPage(
      tester,
      repository: repository,
      capabilities: const AppRuntimeCapabilities(
        webLoginUrl: '',
        webLoginReachable: false,
        webLoginStatusMessage: 'disabled',
        registerInviteEnabled: true,
        registerInviteRequired: true,
      ),
    );

    final inviteField = tester.widget<TextField>(
      find.byKey(const ValueKey('auth_register_invite_field')),
    );
    expect(
      inviteField.decoration?.hintText,
      AuthCopy.inviteCodeHint(required: true),
    );
  });

  testWidgets('register invite hint reflects optional runtime capability', (
    tester,
  ) async {
    final repository = _RecordingAuthRepository();

    await _pumpRegisterPage(
      tester,
      repository: repository,
      capabilities: const AppRuntimeCapabilities(
        webLoginUrl: '',
        webLoginReachable: false,
        webLoginStatusMessage: 'disabled',
        registerInviteEnabled: true,
        registerInviteRequired: false,
      ),
    );

    final inviteField = tester.widget<TextField>(
      find.byKey(const ValueKey('auth_register_invite_field')),
    );
    expect(
      inviteField.decoration?.hintText,
      AuthCopy.inviteCodeHint(required: false),
    );
  });

  testWidgets('register IME done submit still enforces invite required', (
    tester,
  ) async {
    final repository = _RecordingAuthRepository();

    await _pumpRegisterPage(
      tester,
      repository: repository,
      capabilities: const AppRuntimeCapabilities(
        webLoginUrl: '',
        webLoginReachable: false,
        webLoginStatusMessage: 'disabled',
        registerInviteEnabled: true,
        registerInviteRequired: true,
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('auth_register_phone_field')),
      '13800138000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth_register_code_field')),
      '123456',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth_register_password_field')),
      '123456',
    );
    await tester.tap(find.byKey(const ValueKey('auth_login_terms_toggle')));
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('auth_register_password_field')),
    );
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(repository.registerWithPhoneCallCount, 0);
    expect(
      find.byKey(const ValueKey('auth_register_invite_error')),
      findsOneWidget,
    );
  });

  testWidgets('register secondary action pops back when page was pushed', (
    tester,
  ) async {
    final repository = _RecordingAuthRepository();

    await _pumpRegisterPageWithParentRoute(tester, repository: repository);

    expect(find.byType(AuthRegisterPage), findsOneWidget);
    await tester.ensureVisible(find.byKey(registerSecondaryActionKey));
    await tester.tap(find.byKey(registerSecondaryActionKey));
    await tester.pumpAndSettle();

    expect(find.text('register-parent-page'), findsOneWidget);
    expect(find.byType(AuthRegisterPage), findsNothing);
  });

  testWidgets(
    'register secondary action navigates to login when opened as root page',
    (tester) async {
      final repository = _RecordingAuthRepository();

      await _pumpRegisterPage(tester, repository: repository);

      await tester.ensureVisible(find.byKey(registerSecondaryActionKey));
      await tester.tap(find.byKey(registerSecondaryActionKey));
      await tester.pumpAndSettle();

      expect(find.byType(AuthRegisterPage), findsNothing);
      expect(
        find.byKey(const ValueKey('auth-login-primary-action')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'register secondary action navigates to login for direct GoRouter register route entry',
    (tester) async {
      final repository = _RecordingAuthRepository();

      await _pumpRegisterPageWithGoRouterDirectEntry(
        tester,
        repository: repository,
      );

      expect(find.byType(AuthRegisterPage), findsOneWidget);

      await tester.ensureVisible(find.byKey(registerSecondaryActionKey));
      await tester.tap(find.byKey(registerSecondaryActionKey));
      await tester.pumpAndSettle();

      expect(find.byType(AuthRegisterPage), findsNothing);
      expect(
        find.byKey(const ValueKey('auth-login-primary-action')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'reset page uses shared auth panel contract and submit triggers controller flow',
    (tester) async {
      final repository = _RecordingAuthRepository();

      await _pumpResetPage(tester, repository: repository);

      expect(find.text(AuthCopy.resetPasswordTitle), findsOneWidget);
      expect(
        find.text('通过短信验证码恢复${AppConfig.appName}访问权限'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('auth-page-panel')), findsOneWidget);
      expect(find.byKey(const ValueKey('auth-status-banner')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('auth_login_zone_trigger')),
        findsOneWidget,
      );
      expect(find.byKey(resetSendCodeActionKey), findsOneWidget);
      expect(
        tester.widget<AuthActionButton>(find.byKey(resetSendCodeActionKey)),
        isNotNull,
      );
      expect(
        find.byKey(const ValueKey('auth_reset_submit_button')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('auth_login_zone_trigger')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('auth_area_code_sheet')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('auth_area_code_option_0001')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('auth_reset_phone_field')),
        '5551234',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth_reset_code_field')),
        '123456',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth_reset_password_field')),
        '123456',
      );
      await tester.tap(find.byKey(const ValueKey('auth_reset_submit_button')));
      await tester.pumpAndSettle();

      expect(repository.resetPasswordCallCount, 1);
      expect(repository.lastResetZone, '0001');
      expect(repository.lastResetPhone, '5551234');
      expect(repository.lastResetCode, '123456');
      expect(repository.lastResetPassword, '123456');
    },
  );

  testWidgets(
    'reset send-code auto-fills fixed code, hides it, and locks phone field',
    (tester) async {
      const fixedCode = '123456';
      final repository = _RecordingAuthRepository();

      await _pumpResetPage(tester, repository: repository);

      await tester.enterText(
        find.byKey(const ValueKey('auth_reset_phone_field')),
        '13800138000',
      );
      await tester.pump();

      await tester.tap(find.byKey(resetSendCodeActionKey));
      await tester.pumpAndSettle();

      _expectStatusBanner(
        tester,
        message: AuthCopy.fixedCodeSuccessSummary,
        detail: AuthCopy.fixedCodeSuccessDetail,
      );
      expect(repository.sendResetPasswordCodeAttemptCount, 0);
      expect(repository.sendResetPasswordCodeCallCount, 0);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('auth_reset_code_field')),
            )
            .controller
            ?.text,
        fixedCode,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('auth_reset_code_field')),
            )
            .obscureText,
        isTrue,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('auth_reset_phone_field')),
            )
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<AuthActionButton>(find.byKey(resetSendCodeActionKey))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('reset send-code skips repository failures in fixed-code mode', (
    tester,
  ) async {
    const fixedCode = '123456';
    final repository = _RecordingAuthRepository()
      ..throwOnSendResetPasswordCode = true;

    await _pumpResetPage(tester, repository: repository);

    await tester.enterText(
      find.byKey(const ValueKey('auth_reset_phone_field')),
      '13800138000',
    );
    await tester.pump();

    await tester.tap(find.byKey(resetSendCodeActionKey));
    await tester.pumpAndSettle();

    _expectStatusBanner(
      tester,
      message: AuthCopy.fixedCodeSuccessSummary,
      detail: AuthCopy.fixedCodeSuccessDetail,
    );
    expect(repository.sendResetPasswordCodeAttemptCount, 0);
    expect(repository.sendResetPasswordCodeCallCount, 0);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('auth_reset_phone_field')),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<AuthActionButton>(find.byKey(resetSendCodeActionKey))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('auth_reset_code_field')),
          )
          .controller
          ?.text,
      fixedCode,
    );
  });

  testWidgets('reset submit failure does not pop the page', (tester) async {
    final repository = _RecordingAuthRepository()..throwOnResetPassword = true;

    await _pumpResetPageWithParentRoute(tester, repository: repository);

    await tester.enterText(
      find.byKey(const ValueKey('auth_reset_phone_field')),
      '13800138000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth_reset_code_field')),
      '123456',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth_reset_password_field')),
      '123456',
    );
    await tester.tap(find.byKey(const ValueKey('auth_reset_submit_button')));
    await tester.pumpAndSettle();

    expect(find.byType(AuthResetPasswordPage), findsOneWidget);
    expect(find.text('parent-page'), findsNothing);
  });
}
