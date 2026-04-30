import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/constants/app_constants.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/modules/auth/application/auth_providers.dart';
import 'package:wukong_im_app/modules/auth/domain/auth_flow_models.dart';
import 'package:wukong_im_app/modules/auth/domain/auth_repository.dart';
import 'package:wukong_im_app/service/api/login_bridge_api.dart';
import 'package:wukong_im_app/service/api/user_api.dart';
import 'package:wukong_im_app/wukong_login/pc_login_management_page.dart';
import 'package:wukong_im_app/wukong_login/pc_login_page.dart';
import 'package:wukong_im_app/wukong_login/pc_login_service.dart';

class _FakeAuthRepository implements AuthRepository {
  int quitPcWebCallCount = 0;

  @override
  Future<List<LoginBridgeDeviceRecord>> loadDevices() async =>
      const <LoginBridgeDeviceRecord>[];

  @override
  Future<void> deleteDevice(String deviceId) async {}

  @override
  Future<void> quitPcWebSessions() async {
    quitPcWebCallCount += 1;
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
    String? displayName,
  }) async => const AuthCredentialResult.failure('unused');

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
  Future<UserInfo?> getCurrentUser() async => null;

  @override
  Future<void> grantWebLogin({
    required String authCode,
    String? encrypt,
  }) async {}

  @override
  Future<String> loadThirdLoginAuthCode() async => 'unused';

  @override
  Future<ThirdLoginStatusResult> loadThirdLoginStatus(String authCode) async =>
      const ThirdLoginStatusResult(status: 0);

  @override
  Future<AuthCredentialResult> loginWithThirdPartyAuthCode(
    String authCode,
  ) async => const AuthCredentialResult.failure('unused');

  @override
  Future<UserInfo> completeProfile({
    required String name,
    int? sex,
    String? avatarFilePath,
  }) async => UserInfo(uid: 'u1', token: 't1', name: name);
}

Future<void> _pumpManagementPage(
  WidgetTester tester, {
  _FakeAuthRepository? repository,
  Future<void> Function(int value)? updateMuteOfApp,
  Future<PcOnlineState> Function()? loadOnlineState,
  VoidCallback? onRefresh,
  VoidCallback? onOpenFileHelper,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    AppConstants.keyUid: 'u-1',
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          repository ?? _FakeAuthRepository(),
        ),
      ],
      child: MaterialApp(
        home: PCLoginManagementPage(
          updateMuteOfApp: updateMuteOfApp,
          loadOnlineState:
              loadOnlineState ??
              () async => const PcOnlineState(online: 1, muteOfApp: 0),
          onRefresh: onRefresh,
          onOpenFileHelper: onOpenFileHelper,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pc login management page renders Android control surface', (
    tester,
  ) async {
    await _pumpManagementPage(tester, updateMuteOfApp: (_) async {});

    expect(
      find.byKey(const ValueKey<String>('pc-login-management-page')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('pc-login-management-notice')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('pc-login-management-mute')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('pc-login-management-file-helper')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('pc-login-management-quit-all')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('pc-login-management-lock')),
      findsOneWidget,
    );
  });

  testWidgets('pc login management page toggles lock presentation', (
    tester,
  ) async {
    await _pumpManagementPage(tester, updateMuteOfApp: (_) async {});

    expect(find.textContaining('Locked'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('pc-login-management-lock')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Locked'), findsWidgets);
  });

  testWidgets('pc login management page toggles mute_of_app and persists it', (
    tester,
  ) async {
    final updates = <int>[];
    await _pumpManagementPage(
      tester,
      updateMuteOfApp: (value) async {
        updates.add(value);
      },
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('pc-login-management-mute')),
    );
    await tester.pumpAndSettle();

    expect(updates, <int>[1]);
    expect(
      (await SharedPreferences.getInstance()).getInt('u-1_mute_of_app'),
      1,
    );
  });

  testWidgets('pc login management page syncs remote mute state on load', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.keyUid: 'u-1',
      'u-1_mute_of_app': 0,
    });

    await _pumpManagementPage(
      tester,
      updateMuteOfApp: (_) async {},
      loadOnlineState: () async => const PcOnlineState(online: 1, muteOfApp: 1),
    );

    expect(find.text('Muted'), findsWidgets);
    expect(
      (await SharedPreferences.getInstance()).getInt('u-1_mute_of_app'),
      1,
    );
    expect((await SharedPreferences.getInstance()).getInt('u-1_pc_online'), 1);
  });

  testWidgets('pc login management page refreshes online state when resumed', (
    tester,
  ) async {
    var callCount = 0;
    await _pumpManagementPage(
      tester,
      updateMuteOfApp: (_) async {},
      loadOnlineState: () async {
        callCount += 1;
        return PcOnlineState(online: 1, muteOfApp: callCount == 1 ? 0 : 1);
      },
    );

    expect(callCount, 1);
    expect(find.text('Muted'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(callCount, 2);
    expect(find.text('Muted'), findsWidgets);
    expect(
      (await SharedPreferences.getInstance()).getInt('u-1_mute_of_app'),
      1,
    );
  });

  testWidgets('pc login management page opens file helper action', (
    tester,
  ) async {
    var opened = false;
    await _pumpManagementPage(
      tester,
      updateMuteOfApp: (_) async {},
      onOpenFileHelper: () {
        opened = true;
      },
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('pc-login-management-file-helper')),
    );
    await tester.pumpAndSettle();

    expect(opened, isTrue);
  });

  testWidgets('pc login management page quits pc login and refreshes caller', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.keyUid: 'u-1',
    });
    final repository = _FakeAuthRepository();
    var refreshCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PCLoginManagementPage(
                        updateMuteOfApp: (_) async {},
                        loadOnlineState: () async =>
                            const PcOnlineState(online: 1, muteOfApp: 0),
                        onRefresh: () {
                          refreshCount += 1;
                        },
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('pc-login-management-quit-all')),
    );
    await tester.pumpAndSettle();

    expect(repository.quitPcWebCallCount, 1);
    expect(refreshCount, greaterThan(0));
    expect(find.byType(PCLoginManagementPage), findsNothing);
  });

  testWidgets('pc login page no longer ignores legacy callbacks', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.keyUid: 'u-1',
    });
    final repository = _FakeAuthRepository();
    final authCodes = <String>[];
    var refreshCount = 0;
    final service = PCLoginService(
      requestLoginUuid: () async => const LoginUuidResult(
        uuid: 'scene-1',
        qrcode: 'https://example.com/qr',
      ),
      pollLoginStatus: (_) async =>
          const LoginStatusResult(status: 'authed', authCode: 'auth-1'),
      loadDevices: () async => const <LoginBridgeDeviceRecord>[],
      deleteDevice: (_) async {},
      quitPcWeb: () async {},
      pollInterval: const Duration(milliseconds: 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: PCLoginPage(
            service: service,
            onAuthCodeReceived: authCodes.add,
            onRefresh: () {
              refreshCount += 1;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 5));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('pc-login-page')), findsOneWidget);
    expect(authCodes, <String>['auth-1']);
    expect(refreshCount, greaterThan(0));
  });

  testWidgets('pc login page renders Android web-login guide actions', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PCLoginPage()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('pc-login-page')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('pc-login-copy-url')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('pc-login-open-scan')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('pc-login-open-management')),
      findsOneWidget,
    );
  });

  testWidgets('pc login pages show Chinese copy under zh locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale('zh', 'CN'),
        supportedLocales: const <Locale>[
          Locale('zh', 'CN'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: PCLoginPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('\u7535\u8111\u7aef\u767b\u5f55'), findsOneWidget);
    expect(find.text('\u590d\u5236\u5730\u5740'), findsOneWidget);
    expect(find.text('\u626b\u63cf\u4e8c\u7ef4\u7801'), findsOneWidget);

    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.keyUid: 'u-1',
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: MaterialApp(
          locale: Locale('zh', 'CN'),
          supportedLocales: const <Locale>[
            Locale('zh', 'CN'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: PCLoginManagementPage(
            updateMuteOfApp: _noopMuteUpdate,
            loadOnlineState: _defaultOnlineState,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('\u624b\u673a\u9759\u97f3'), findsOneWidget);
    expect(find.text('\u6587\u4ef6\u4f20\u8f93\u52a9\u624b'), findsOneWidget);
    expect(
      find.text(
        '\u9000\u51fa\u5168\u90e8\u7535\u8111\u7aef/\u7f51\u9875\u7aef\u767b\u5f55',
      ),
      findsOneWidget,
    );
  });
}

Future<void> _noopMuteUpdate(int value) async {}

Future<PcOnlineState> _defaultOnlineState() async =>
    const PcOnlineState(online: 1, muteOfApp: 0);
