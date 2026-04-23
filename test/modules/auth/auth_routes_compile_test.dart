import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wukong_im_app/app/navigation/auth_route_page.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/data/providers/runtime_capabilities_provider.dart';
import 'package:wukong_im_app/modules/auth/auth_shell.dart';
import 'package:wukong_im_app/modules/auth/application/auth_providers.dart';
import 'package:wukong_im_app/modules/auth/domain/auth_flow_models.dart';
import 'package:wukong_im_app/modules/auth/domain/auth_repository.dart';
import 'package:wukong_im_app/modules/auth/login_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_device_sessions_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_login_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_login_verification_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_login_verification_code_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_profile_completion_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_register_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_reset_password_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_third_login_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_web_login_confirm_page.dart';
import 'package:wukong_im_app/modules/auth/register_page.dart';
import 'package:wukong_im_app/service/api/common_api.dart';
import 'package:wukong_im_app/service/api/login_bridge_api.dart';
import 'package:wukong_im_app/wukong_login/login_page.dart' as legacy_login;
import 'package:wukong_im_app/wukong_login/pc_login_management_page.dart'
    as legacy_pc_manage;
import 'package:wukong_im_app/wukong_login/pc_login_page.dart'
    as legacy_pc_login;
import 'package:wukong_im_app/wukong_login/pc_login_service.dart'
    as legacy_pc_service;
import 'package:wukong_im_app/wukong_login/third_login_page.dart'
    as legacy_third_login;
import 'package:wukong_im_app/wukong_login/web_login_confirm_page.dart'
    as legacy_web_login;

class _CompileAuthRepository implements AuthRepository {
  @override
  Future<AuthCredentialResult> loginWithPhone({
    required String zone,
    required String phone,
    required String password,
  }) async {
    return const AuthCredentialResult.failure('unused');
  }

  @override
  Future<AuthCredentialResult> loginWithUsername({
    required String username,
    required String password,
  }) async {
    return const AuthCredentialResult.failure('unused');
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
    return const AuthCredentialResult.failure('unused');
  }

  @override
  Future<void> sendRegisterCode({
    required String zone,
    required String phone,
  }) async {}

  @override
  Future<void> sendLoginVerificationCode(String uid) async {}

  @override
  Future<AuthCredentialResult> verifyLoginCode({
    required String uid,
    required String code,
  }) async {
    return const AuthCredentialResult.failure('unused');
  }

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
  }) async {
    return UserInfo(uid: 'u-1', token: 't-1', name: name);
  }

  @override
  Future<void> grantWebLogin({
    required String authCode,
    String? encrypt,
  }) async {}

  @override
  Future<String> loadThirdLoginAuthCode() async => 'third-auth-code';

  @override
  Future<ThirdLoginStatusResult> loadThirdLoginStatus(String authCode) async {
    return const ThirdLoginStatusResult(status: 0);
  }

  @override
  Future<AuthCredentialResult> loginWithThirdPartyAuthCode(
    String authCode,
  ) async {
    return const AuthCredentialResult.failure('unused');
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

Future<void> _pumpWithAuthScaffold(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_CompileAuthRepository()),
        runtimeCapabilitiesProvider.overrideWith(
          (ref) async => const AppRuntimeCapabilities(
            webLoginUrl: '',
            webLoginReachable: false,
            webLoginStatusMessage: 'disabled',
            thirdLoginEnabled: true,
            thirdLoginStatusMessage: 'enabled',
          ),
        ),
      ],
      child: MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('auth route helper and wrappers remain constructible', () {
    final page = buildAuthRoutePage<void>(
      key: const ValueKey<String>('auth-route-compile'),
      child: const SizedBox(),
    );

    expect(page, isA<CustomTransitionPage<void>>());
    expect(const LoginPage(), isA<Widget>());
    expect(const RegisterPage(), isA<Widget>());
    expect(
      const AuthFlowShell(title: 'Auth', child: SizedBox()),
      isA<Widget>(),
    );
  });

  testWidgets('all auth pages compile inside ProviderScope', (tester) async {
    await _pumpWithAuthScaffold(tester, const AuthLoginPage());

    expect(const AuthRegisterPage(), isA<Widget>());
    expect(const AuthResetPasswordPage(), isA<Widget>());
    expect(const AuthLoginVerificationPage(), isA<Widget>());
    expect(const AuthLoginVerificationCodePage(), isA<Widget>());
    expect(const AuthProfileCompletionPage(), isA<Widget>());
    expect(const AuthDeviceSessionsPage(), isA<Widget>());
    expect(const AuthWebLoginConfirmPage(authCode: 'auth-1'), isA<Widget>());
    expect(const AuthThirdLoginPage(), isA<Widget>());
  });

  testWidgets('legacy wukong_login entrypoints wrap the new auth pages', (
    tester,
  ) async {
    await _pumpWithAuthScaffold(tester, const legacy_login.LoginPage());
    expect(find.byType(AuthLoginPage), findsOneWidget);

    await _pumpWithAuthScaffold(
      tester,
      const legacy_pc_manage.PCLoginManagementPage(),
    );
    expect(
      find.byKey(const ValueKey<String>('pc-login-management-page')),
      findsOneWidget,
    );

    await _pumpWithAuthScaffold(tester, const legacy_pc_login.PCLoginPage());
    expect(find.byKey(const ValueKey<String>('pc-login-page')), findsOneWidget);

    await _pumpWithAuthScaffold(
      tester,
      const legacy_third_login.ThirdLoginPage(),
    );
    expect(find.byType(AuthThirdLoginPage), findsOneWidget);

    await _pumpWithAuthScaffold(
      tester,
      const legacy_web_login.WebLoginConfirmPage(authCode: 'auth-1'),
    );
    expect(find.byType(AuthWebLoginConfirmPage), findsOneWidget);
  });

  test('legacy PCLoginService facade remains constructible', () {
    expect(
      legacy_pc_service.PCLoginService(),
      isA<legacy_pc_service.PCLoginService>(),
    );
  });
}
