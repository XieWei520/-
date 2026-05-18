import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/data/providers/auth_provider.dart';
import 'package:wukong_im_app/modules/auth/application/auth_flow_controller.dart';
import 'package:wukong_im_app/modules/auth/application/auth_providers.dart';
import 'package:wukong_im_app/modules/auth/coordinators/auth_bootstrap_coordinator.dart';
import 'package:wukong_im_app/modules/auth/domain/auth_flow_models.dart';
import 'package:wukong_im_app/modules/auth/domain/auth_repository.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_login_verification_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_login_verification_code_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_profile_completion_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/widgets/auth_action_button.dart';
import 'package:wukong_im_app/modules/auth/presentation/widgets/auth_copy.dart';
import 'package:wukong_im_app/modules/auth/presentation/widgets/auth_form_field.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry_provider.dart';
import 'package:wukong_im_app/service/api/login_bridge_api.dart';

import '../../fakes/noop_im_notification_bridge.dart';

class _RecordingAuthRepository implements AuthRepository {
  AuthCredentialResult loginWithPhoneResult =
      const AuthCredentialResult.failure('login failed');
  AuthCredentialResult verifyLoginCodeResult =
      const AuthCredentialResult.failure('invalid code');
  AuthCredentialResult thirdPartyLoginResult =
      const AuthCredentialResult.failure('third login failed');
  UserInfo completeProfileResult = UserInfo(
    uid: 'u-profile',
    token: 't-profile',
    name: 'Profile User',
    avatar: 'avatar.png',
  );

  int sendLoginVerificationCodeCallCount = 0;
  int sendLoginVerificationCodeAttemptCount = 0;
  int verifyLoginCodeCallCount = 0;
  int thirdPartyLoginCallCount = 0;
  int completeProfileCallCount = 0;
  bool throwOnSendLoginVerificationCode = false;

  String? lastVerificationUid;
  String? lastVerificationCode;
  String? lastProfileName;
  int? lastProfileSex;
  String? lastProfileAvatarFilePath;

  @override
  Future<AuthCredentialResult> loginWithPhone({
    required String zone,
    required String phone,
    required String password,
  }) async {
    return loginWithPhoneResult;
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
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendRegisterCode({required String zone, required String phone}) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendResetPasswordCode({
    required String zone,
    required String phone,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> resetPassword({
    required String zone,
    required String phone,
    required String code,
    required String newPassword,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<UserInfo?> getCurrentUser() async => null;

  @override
  Future<void> sendLoginVerificationCode(String uid) async {
    sendLoginVerificationCodeAttemptCount += 1;
    sendLoginVerificationCodeCallCount += 1;
    lastVerificationUid = uid;
    if (throwOnSendLoginVerificationCode) {
      throw Exception('send login verification code failed');
    }
  }

  @override
  Future<AuthCredentialResult> verifyLoginCode({
    required String uid,
    required String code,
  }) async {
    verifyLoginCodeCallCount += 1;
    lastVerificationUid = uid;
    lastVerificationCode = code;
    return verifyLoginCodeResult;
  }

  @override
  Future<void> grantWebLogin({required String authCode, String? encrypt}) {
    throw UnimplementedError();
  }

  @override
  Future<String> loadThirdLoginAuthCode() {
    throw UnimplementedError();
  }

  @override
  Future<ThirdLoginStatusResult> loadThirdLoginStatus(String authCode) {
    throw UnimplementedError();
  }

  @override
  Future<AuthCredentialResult> loginWithThirdPartyAuthCode(
    String authCode,
  ) async {
    thirdPartyLoginCallCount += 1;
    return thirdPartyLoginResult;
  }

  @override
  Future<List<LoginBridgeDeviceRecord>> loadDevices() {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteDevice(String deviceId) {
    throw UnimplementedError();
  }

  @override
  Future<void> quitPcWebSessions() {
    throw UnimplementedError();
  }

  @override
  Future<UserInfo> completeProfile({
    required String name,
    int? sex,
    String? avatarFilePath,
  }) async {
    completeProfileCallCount += 1;
    lastProfileName = name;
    lastProfileSex = sex;
    lastProfileAvatarFilePath = avatarFilePath;
    return completeProfileResult;
  }
}

class _RecordingAuthNotifier extends AuthNotifier {
  _RecordingAuthNotifier(super.ref);

  int commitBootstrapResultCallCount = 0;
  int completeProfileCallCount = 0;

  @override
  Future<void> commitBootstrapResult(AuthBootstrapResult result) async {
    commitBootstrapResultCallCount += 1;
    await super.commitBootstrapResult(result);
  }

  @override
  Future<void> completeProfile(UserInfo userInfo) async {
    completeProfileCallCount += 1;
    await super.completeProfile(userInfo);
  }
}

_RecordingAuthNotifier _buildAuthNotifier() {
  final telemetry = RealtimeRolloutTelemetry(flushInterval: Duration.zero);
  addTearDown(telemetry.dispose);
  final container = ProviderContainer(
    overrides: [
      noopImNotificationBridgeOverride(),
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
  UserInfo? bootstrapUser,
}) {
  return AuthFlowController(
    repository: repository,
    bootstrapCoordinator: AuthBootstrapCoordinator(
      persistSession:
          ({required uid, required token, required imToken}) async {},
      rollbackSession: () async {},
      bindDeviceIdentity: ({required uid, required token}) async {},
      loadCurrentUser: () async => bootstrapUser,
      initializeAuthenticatedRuntime: (_) async {},
      registerPush: () async {},
      syncDrafts: () async {},
    ),
    authNotifier: notifier,
  );
}

Future<void> _pumpVerificationIntroPage(
  WidgetTester tester, {
  required AuthFlowController controller,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authFlowControllerProvider.overrideWith((ref) => controller)],
      child: const MaterialApp(home: AuthLoginVerificationPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpVerificationCodePage(
  WidgetTester tester, {
  required AuthFlowController controller,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authFlowControllerProvider.overrideWith((ref) => controller)],
      child: const MaterialApp(home: AuthLoginVerificationCodePage()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpProfilePage(
  WidgetTester tester, {
  required AuthFlowController controller,
  Future<String?> Function()? pickAvatar,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authFlowControllerProvider.overrideWith((ref) => controller),
        if (pickAvatar != null)
          authProfileAvatarPickerProvider.overrideWithValue(pickAvatar),
      ],
      child: const MaterialApp(home: AuthProfileCompletionPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _expectOkDialog(
  WidgetTester tester, {
  required String message,
}) async {
  final dialog = find.byType(AlertDialog);
  expect(dialog, findsOneWidget);
  expect(
    find.descendant(of: dialog, matching: find.text(message)),
    findsOneWidget,
  );
  await tester.tap(find.descendant(of: dialog, matching: find.text('确定')));
  await tester.pumpAndSettle();
}

Future<void> _dismissOkDialogIfPresent(WidgetTester tester) async {
  final okFinder = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text('确定'),
  );
  if (okFinder.evaluate().isEmpty) {
    return;
  }
  await tester.tap(okFinder.last);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'login with phone enters awaitingLoginVerification when required',
    () async {
      final repository = _RecordingAuthRepository()
        ..loginWithPhoneResult = AuthCredentialResult.verificationRequired(
          uid: 'u-verify',
          phone: '13800138000',
        );
      final notifier = _buildAuthNotifier();
      final controller = _buildController(
        repository: repository,
        notifier: notifier,
      );

      await controller.loginWithPhone(
        zone: '0086',
        phone: '13800138000',
        password: '123456',
      );

      expect(controller.state.stage, AuthStage.awaitingLoginVerification);
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.loginVerificationContext?.uid, 'u-verify');
      expect(controller.state.loginVerificationContext?.phone, '13800138000');
      expect(
        controller.state.loginVerificationContext?.step,
        AuthLoginVerificationStep.introduction,
      );
      expect(notifier.commitBootstrapResultCallCount, 0);
    },
  );

  test(
    'sendLoginVerificationCode accepts fixed code shortcut and skips repository send',
    () async {
      const fixedCode = '123456';
      final repository = _RecordingAuthRepository()
        ..loginWithPhoneResult = AuthCredentialResult.verificationRequired(
          uid: 'u-verify',
          phone: '13800138000',
        );
      final notifier = _buildAuthNotifier();
      final controller = _buildController(
        repository: repository,
        notifier: notifier,
      );

      await controller.loginWithPhone(
        zone: '0086',
        phone: '13800138000',
        password: '123456',
      );
      await controller.sendLoginVerificationCode(
        uid: 'u-verify',
        prefilledCode: fixedCode,
      );

      expect(repository.sendLoginVerificationCodeCallCount, 0);
      expect(
        controller.state.loginVerificationContext?.step,
        AuthLoginVerificationStep.codeEntry,
      );
      expect(
        controller.state.loginVerificationContext?.prefilledCode,
        fixedCode,
      );
    },
  );

  test(
    'verifyLoginCode bootstraps authenticated session after success',
    () async {
      final repository = _RecordingAuthRepository()
        ..loginWithPhoneResult = AuthCredentialResult.verificationRequired(
          uid: 'u-verify',
          phone: '13800138000',
        )
        ..verifyLoginCodeResult = AuthCredentialResult.success(
          uid: 'u-verify',
          token: 't-verify',
          user: UserInfo(
            uid: 'u-verify',
            token: 't-verify',
            name: 'WuKong',
            avatar: 'avatar.png',
          ),
        );
      final notifier = _buildAuthNotifier();
      final controller = _buildController(
        repository: repository,
        notifier: notifier,
        bootstrapUser: UserInfo(
          uid: 'u-verify',
          token: 't-verify',
          name: 'WuKong',
          avatar: 'avatar.png',
        ),
      );

      await controller.loginWithPhone(
        zone: '0086',
        phone: '13800138000',
        password: '123456',
      );
      await controller.verifyLoginCode(uid: 'u-verify', code: '654321');

      expect(repository.verifyLoginCodeCallCount, 1);
      expect(repository.lastVerificationUid, 'u-verify');
      expect(repository.lastVerificationCode, '654321');
      expect(controller.state.stage, AuthStage.authenticatedReady);
      expect(controller.state.loginVerificationContext, isNull);
      expect(notifier.commitBootstrapResultCallCount, 1);
    },
  );

  test(
    'loginWithThirdPartyAuthCode bootstraps authenticated session after success',
    () async {
      final repository = _RecordingAuthRepository()
        ..thirdPartyLoginResult = AuthCredentialResult.success(
          uid: 'u-third',
          token: 't-third',
          user: UserInfo(
            uid: 'u-third',
            token: 't-third',
            name: 'Third Login User',
            avatar: 'avatar.png',
          ),
        );
      final notifier = _buildAuthNotifier();
      final controller = _buildController(
        repository: repository,
        notifier: notifier,
        bootstrapUser: UserInfo(
          uid: 'u-third',
          token: 't-third',
          name: 'Third Login User',
          avatar: 'avatar.png',
        ),
      );

      await controller.loginWithThirdPartyAuthCode('third-auth-code');

      expect(repository.thirdPartyLoginCallCount, 1);
      expect(controller.state.stage, AuthStage.authenticatedReady);
      expect(controller.state.loginVerificationContext, isNull);
      expect(notifier.commitBootstrapResultCallCount, 1);
    },
  );

  test(
    'completeProfile clears needsProfileCompletion through auth notifier',
    () async {
      final repository = _RecordingAuthRepository()
        ..loginWithPhoneResult = AuthCredentialResult.success(
          uid: 'u-profile',
          token: 't-profile',
          user: UserInfo(uid: 'u-profile', token: 't-profile'),
        )
        ..completeProfileResult = UserInfo(
          uid: 'u-profile',
          token: 't-profile',
          name: 'Monkey King',
          avatar: 'avatar.png',
          sex: 1,
        );
      final notifier = _buildAuthNotifier();
      final controller = _buildController(
        repository: repository,
        notifier: notifier,
        bootstrapUser: UserInfo(
          uid: 'u-profile',
          token: 't-profile',
          name: '',
          avatar: '',
        ),
      );

      await controller.loginWithPhone(
        zone: '0086',
        phone: '13800138000',
        password: '123456',
      );

      expect(controller.state.stage, AuthStage.awaitingProfileCompletion);
      expect(notifier.state.needsProfileCompletion, isTrue);

      await controller.completeProfile(name: 'Monkey King', sex: 1);

      expect(repository.completeProfileCallCount, 1);
      expect(repository.lastProfileName, 'Monkey King');
      expect(repository.lastProfileSex, 1);
      expect(controller.state.stage, AuthStage.authenticatedReady);
      expect(notifier.completeProfileCallCount, 1);
      expect(notifier.state.needsProfileCompletion, isFalse);
      expect(notifier.state.userInfo?.name, 'Monkey King');
    },
  );

  testWidgets(
    'login verification introduction page starts fixed code flow without repository send',
    (tester) async {
      const fixedCode = '123456';
      final repository = _RecordingAuthRepository()
        ..loginWithPhoneResult = AuthCredentialResult.verificationRequired(
          uid: 'u-verify',
          phone: '13800138000',
        );
      final notifier = _buildAuthNotifier();
      final controller = _buildController(
        repository: repository,
        notifier: notifier,
      );

      await controller.loginWithPhone(
        zone: '0086',
        phone: '13800138000',
        password: '123456',
      );
      await _pumpVerificationIntroPage(tester, controller: controller);

      expect(find.byKey(const ValueKey('auth-page-panel')), findsOneWidget);
      expect(find.byKey(const ValueKey('auth-status-banner')), findsOneWidget);
      expect(find.text(AuthCopy.loginVerificationTitle), findsOneWidget);
      expect(find.text(AuthCopy.loginVerificationStartButton), findsOneWidget);
      expect(
        find.byKey(const ValueKey('auth-login-verification-start')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('auth-login-verification-start')),
      );
      await tester.pumpAndSettle();

      expect(repository.sendLoginVerificationCodeCallCount, 0);
      expect(
        controller.state.loginVerificationContext?.step,
        AuthLoginVerificationStep.codeEntry,
      );
      expect(
        controller.state.loginVerificationContext?.prefilledCode,
        fixedCode,
      );
    },
  );

  testWidgets(
    'login verification introduction page exposes back action and clears verification state',
    (tester) async {
      final repository = _RecordingAuthRepository()
        ..loginWithPhoneResult = AuthCredentialResult.verificationRequired(
          uid: 'u-verify',
          phone: '13800138000',
        );
      final notifier = _buildAuthNotifier();
      final controller = _buildController(
        repository: repository,
        notifier: notifier,
      );

      await controller.loginWithPhone(
        zone: '0086',
        phone: '13800138000',
        password: '123456',
      );
      await _pumpVerificationIntroPage(tester, controller: controller);

      final backFinder = find.byKey(
        const ValueKey('auth-login-verification-back'),
      );
      expect(backFinder, findsOneWidget);

      await tester.tap(backFinder);
      await tester.pumpAndSettle();

      expect(controller.state.stage, AuthStage.unauthenticated);
      expect(controller.state.loginVerificationContext, isNull);
    },
  );

  testWidgets(
    'login verification code page auto-fills hidden fixed code and submits it',
    (tester) async {
      const fixedCode = '123456';
      final repository = _RecordingAuthRepository()
        ..loginWithPhoneResult = AuthCredentialResult.verificationRequired(
          uid: 'u-verify',
          phone: '13800138000',
        )
        ..verifyLoginCodeResult = AuthCredentialResult.success(
          uid: 'u-verify',
          token: 't-verify',
          user: UserInfo(
            uid: 'u-verify',
            token: 't-verify',
            name: 'WuKong',
            avatar: 'avatar.png',
          ),
        );
      final notifier = _buildAuthNotifier();
      final controller = _buildController(
        repository: repository,
        notifier: notifier,
        bootstrapUser: UserInfo(
          uid: 'u-verify',
          token: 't-verify',
          name: 'WuKong',
          avatar: 'avatar.png',
        ),
      );

      await controller.loginWithPhone(
        zone: '0086',
        phone: '13800138000',
        password: '123456',
      );
      await controller.sendLoginVerificationCode(
        uid: 'u-verify',
        prefilledCode: fixedCode,
      );
      await _pumpVerificationCodePage(tester, controller: controller);

      await _dismissOkDialogIfPresent(tester);
      expect(find.byKey(const ValueKey('auth-page-panel')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('auth-login-verification-resend')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('auth-login-verification-submit')),
        findsOneWidget,
      );
      expect(
        tester.widget<AuthActionButton>(
          find.byKey(const ValueKey('auth-login-verification-submit')),
        ),
        isNotNull,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('auth-login-verification-code-field')),
            )
            .controller
            ?.text,
        fixedCode,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('auth-login-verification-code-field')),
            )
            .obscureText,
        isTrue,
      );
      await tester.tap(
        find.byKey(const ValueKey('auth-login-verification-submit')),
      );
      await tester.pumpAndSettle();

      expect(repository.sendLoginVerificationCodeCallCount, 0);
      expect(repository.verifyLoginCodeCallCount, 1);
      expect(repository.lastVerificationCode, fixedCode);
    },
  );

  testWidgets(
    'login verification code page exposes back action and returns to verification introduction',
    (tester) async {
      const fixedCode = '123456';
      final repository = _RecordingAuthRepository()
        ..loginWithPhoneResult = AuthCredentialResult.verificationRequired(
          uid: 'u-verify',
          phone: '13800138000',
        );
      final notifier = _buildAuthNotifier();
      final controller = _buildController(
        repository: repository,
        notifier: notifier,
      );

      await controller.loginWithPhone(
        zone: '0086',
        phone: '13800138000',
        password: '123456',
      );
      await controller.sendLoginVerificationCode(
        uid: 'u-verify',
        prefilledCode: fixedCode,
      );
      await _pumpVerificationCodePage(tester, controller: controller);

      await _dismissOkDialogIfPresent(tester);

      final backFinder = find.byKey(
        const ValueKey('auth-login-verification-code-back'),
      );
      expect(backFinder, findsOneWidget);

      await tester.tap(backFinder);
      await tester.pumpAndSettle();

      expect(controller.state.stage, AuthStage.awaitingLoginVerification);
      expect(
        controller.state.loginVerificationContext?.step,
        AuthLoginVerificationStep.introduction,
      );
      expect(controller.state.loginVerificationContext?.prefilledCode, isNull);
    },
  );

  testWidgets(
    'login verification code page starts with resend countdown after fixed code shortcut',
    (tester) async {
      const fixedCode = '123456';
      final repository = _RecordingAuthRepository()
        ..loginWithPhoneResult = AuthCredentialResult.verificationRequired(
          uid: 'u-verify',
          phone: '13800138000',
        );
      final notifier = _buildAuthNotifier();
      final controller = _buildController(
        repository: repository,
        notifier: notifier,
      );

      await controller.loginWithPhone(
        zone: '0086',
        phone: '13800138000',
        password: '123456',
      );
      await controller.sendLoginVerificationCode(
        uid: 'u-verify',
        prefilledCode: fixedCode,
      );
      await _pumpVerificationCodePage(tester, controller: controller);

      expect(find.text('59'), findsOneWidget);
      final resendButton = tester.widget<AuthActionButton>(
        find.byKey(const ValueKey('auth-login-verification-resend')),
      );
      expect(resendButton.onPressed, isNull);
    },
  );

  testWidgets(
    'login verification resend reapplies fixed code without repository send',
    (tester) async {
      const fixedCode = '123456';
      const successMessage = '验证码获取成功';
      final repository = _RecordingAuthRepository()
        ..loginWithPhoneResult = AuthCredentialResult.verificationRequired(
          uid: 'u-verify',
          phone: '13800138000',
        );
      final notifier = _buildAuthNotifier();
      final controller = _buildController(
        repository: repository,
        notifier: notifier,
      );

      await controller.loginWithPhone(
        zone: '0086',
        phone: '13800138000',
        password: '123456',
      );
      await controller.sendLoginVerificationCode(
        uid: 'u-verify',
        prefilledCode: fixedCode,
      );
      await _pumpVerificationCodePage(tester, controller: controller);
      await _expectOkDialog(tester, message: successMessage);

      await tester.pump(const Duration(seconds: 59));
      await tester.pump();

      final resendFinder = find.byKey(
        const ValueKey('auth-login-verification-resend'),
      );
      expect(resendFinder, findsOneWidget);
      expect(
        tester.widget<AuthActionButton>(resendFinder).onPressed,
        isNotNull,
      );

      await tester.tap(resendFinder);
      await tester.pumpAndSettle();
      await _expectOkDialog(tester, message: successMessage);

      expect(repository.sendLoginVerificationCodeAttemptCount, 0);
      expect(repository.sendLoginVerificationCodeCallCount, 0);
      expect(tester.widget<AuthActionButton>(resendFinder).onPressed, isNull);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('auth-login-verification-code-field')),
            )
            .controller
            ?.text,
        fixedCode,
      );
    },
  );

  testWidgets(
    'profile completion page requires avatar selection before submit',
    (tester) async {
      final repository = _RecordingAuthRepository()
        ..loginWithPhoneResult = AuthCredentialResult.success(
          uid: 'u-profile',
          token: 't-profile',
          user: UserInfo(uid: 'u-profile', token: 't-profile'),
        );
      final notifier = _buildAuthNotifier();
      final controller = _buildController(
        repository: repository,
        notifier: notifier,
        bootstrapUser: UserInfo(
          uid: 'u-profile',
          token: 't-profile',
          name: '',
          avatar: '',
        ),
      );

      await controller.loginWithPhone(
        zone: '0086',
        phone: '13800138000',
        password: '123456',
      );
      await _pumpProfilePage(
        tester,
        controller: controller,
        pickAvatar: () async => 'selected/avatar.png',
      );

      expect(find.byKey(const ValueKey('auth-page-panel')), findsOneWidget);
      expect(find.byType(AuthFormField), findsOneWidget);
      expect(find.byKey(const ValueKey('auth-profile-avatar')), findsOneWidget);
      expect(find.byKey(const ValueKey('auth-profile-name')), findsOneWidget);
      expect(find.byKey(const ValueKey('auth-profile-submit')), findsOneWidget);
      expect(
        tester.widget<AuthActionButton>(
          find.byKey(const ValueKey('auth-profile-submit')),
        ),
        isNotNull,
      );

      await tester.enterText(
        find.byKey(const ValueKey('auth-profile-name')),
        'Monkey King',
      );
      await tester.tap(find.byKey(const ValueKey('auth-profile-submit')));
      await tester.pumpAndSettle();

      expect(repository.completeProfileCallCount, 0);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('确定'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('auth-profile-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('auth-profile-submit')));
      await tester.pumpAndSettle();

      expect(repository.completeProfileCallCount, 1);
      expect(repository.lastProfileName, 'Monkey King');
      expect(repository.lastProfileAvatarFilePath, 'selected/avatar.png');
    },
  );

  testWidgets(
    'profile completion page requires name even after avatar is selected',
    (tester) async {
      final repository = _RecordingAuthRepository()
        ..loginWithPhoneResult = AuthCredentialResult.success(
          uid: 'u-profile',
          token: 't-profile',
          user: UserInfo(uid: 'u-profile', token: 't-profile'),
        );
      final notifier = _buildAuthNotifier();
      final controller = _buildController(
        repository: repository,
        notifier: notifier,
        bootstrapUser: UserInfo(
          uid: 'u-profile',
          token: 't-profile',
          name: '',
          avatar: '',
        ),
      );

      await controller.loginWithPhone(
        zone: '0086',
        phone: '13800138000',
        password: '123456',
      );
      await _pumpProfilePage(
        tester,
        controller: controller,
        pickAvatar: () async => 'selected/avatar.png',
      );

      await tester.tap(find.byKey(const ValueKey('auth-profile-avatar')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('auth-profile-submit')));
      await tester.pumpAndSettle();

      expect(repository.completeProfileCallCount, 0);
      expect(find.byType(AlertDialog), findsOneWidget);
    },
  );
}
