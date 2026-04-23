import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/data/providers/runtime_capabilities_provider.dart';
import 'package:wukong_im_app/modules/auth/application/auth_providers.dart';
import 'package:wukong_im_app/modules/auth/application/device_session_controller.dart';
import 'package:wukong_im_app/modules/auth/domain/auth_flow_models.dart';
import 'package:wukong_im_app/modules/auth/domain/auth_repository.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_device_sessions_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_third_login_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_web_login_confirm_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/widgets/auth_action_button.dart';
import 'package:wukong_im_app/service/api/common_api.dart';
import 'package:wukong_im_app/service/api/login_bridge_api.dart';
import 'package:wukong_im_app/wukong_scan/scan_result_page.dart';
import 'package:wukong_im_app/wukong_scan/scan_service.dart';

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

class _FakeAuthRepository implements AuthRepository {
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
  Future<UserInfo?> getCurrentUser() async => null;

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
    return AuthCredentialResult.success(
      uid: 'third-u-1',
      token: 'third-t-1',
      user: UserInfo(uid: 'third-u-1', token: 'third-t-1', name: 'Third User'),
    );
  }

  @override
  Future<List<LoginBridgeDeviceRecord>> loadDevices() async {
    return const <LoginBridgeDeviceRecord>[];
  }

  @override
  Future<void> deleteDevice(String deviceId) async {}

  @override
  Future<void> quitPcWebSessions() async {}
}

class _TrackingAuthRepository implements AuthRepository {
  _TrackingAuthRepository({List<LoginBridgeDeviceRecord>? initialDevices})
    : _devices = List<LoginBridgeDeviceRecord>.from(
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
  bool failGrant = false;

  @override
  Future<void> grantWebLogin({
    required String authCode,
    String? encrypt,
  }) async {
    calls.add('grant');
    if (failGrant) {
      throw Exception('grant failed');
    }
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
  Future<AuthCredentialResult> loginWithThirdPartyAuthCode(
    String authCode,
  ) async => const AuthCredentialResult.failure('unused');

  @override
  Future<UserInfo?> getCurrentUser() async => null;
}

class _ThirdLoginAuthRepository extends _FakeAuthRepository {
  static const String fixedAuthCode = 'third-auth-code';
  Completer<ThirdLoginStatusResult>? statusCompleter;
  int statusCallCount = 0;
  int _inFlightStatusCallCount = 0;
  int maxConcurrentStatusCallCount = 0;
  int thirdPartyLoginCallCount = 0;

  @override
  Future<String> loadThirdLoginAuthCode() async => fixedAuthCode;

  @override
  Future<ThirdLoginStatusResult> loadThirdLoginStatus(String _) async {
    statusCallCount += 1;
    _inFlightStatusCallCount += 1;
    if (_inFlightStatusCallCount > maxConcurrentStatusCallCount) {
      maxConcurrentStatusCallCount = _inFlightStatusCallCount;
    }
    try {
      final completer = statusCompleter;
      if (completer != null) {
        return await completer.future;
      }
      return const ThirdLoginStatusResult(status: 0);
    } finally {
      _inFlightStatusCallCount -= 1;
    }
  }

  @override
  Future<AuthCredentialResult> loginWithThirdPartyAuthCode(
    String authCode,
  ) async {
    thirdPartyLoginCallCount += 1;
    return super.loginWithThirdPartyAuthCode(authCode);
  }
}

class _FailingDeviceLoadAuthRepository extends _FakeAuthRepository {
  @override
  Future<List<LoginBridgeDeviceRecord>> loadDevices() async {
    throw Exception('load failed');
  }
}

ScanServiceResult _buildScanLoginConfirmResult() {
  return ScanServiceResult.fromJson({
    'forward': 'native',
    'type': 'loginConfirm',
    'data': {'auth_code': 'auth-1', 'pub_key': 'enc-1'},
  }, 'raw-login-confirm');
}

Future<void> _pumpScanLoginConfirmPage(
  WidgetTester tester, {
  AuthRepository? repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          repository ?? _FakeAuthRepository(),
        ),
      ],
      child: MaterialApp(
        home: ScanResultPage(result: _buildScanLoginConfirmResult()),
      ),
    ),
  );
}

Future<void> _pumpThirdLoginPage(
  WidgetTester tester, {
  required AuthRepository repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
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
      child: const MaterialApp(home: AuthThirdLoginPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('device session controller loads device records', () async {
    final controller = DeviceSessionController(
      repository: _FakeDeviceRepository(),
    );

    await controller.load();

    expect(controller.state.items, hasLength(1));
    expect(controller.state.items.single.deviceId, 'desktop-1');
  });

  testWidgets('web login confirm page uses shared auth surface contract', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: const MaterialApp(
          home: AuthWebLoginConfirmPage(authCode: 'auth-1', encrypt: 'enc-1'),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('auth-page-panel')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('auth-web-login-confirm')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('auth-web-login-cancel')), findsOneWidget);
    expect(find.text('auth-1'), findsOneWidget);
    expect(
      tester.widget<AuthActionButton>(
        find.byKey(const ValueKey('auth-web-login-confirm')),
      ),
      isNotNull,
    );
    expect(
      tester.widget<AuthActionButton>(
        find.byKey(const ValueKey('auth-web-login-cancel')),
      ),
      isNotNull,
    );
  });

  testWidgets('web login confirm passes authCode and encrypt to repository', (
    tester,
  ) async {
    final repository = _TrackingAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: AuthWebLoginConfirmPage(authCode: 'auth-1', encrypt: 'enc-1'),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('auth-web-login-confirm')));
    await tester.pumpAndSettle();

    expect(repository.grantedAuthCode, 'auth-1');
    expect(repository.grantedEncrypt, 'enc-1');
  });

  testWidgets('web login confirm pops true on successful confirm', (
    tester,
  ) async {
    final repository = _TrackingAuthRepository();
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const SizedBox.shrink(),
        ),
      ),
    );

    final resultFuture = navigatorKey.currentState!.push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            const AuthWebLoginConfirmPage(authCode: 'auth-1', encrypt: 'enc-1'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('auth-web-login-confirm')));
    await tester.pumpAndSettle();

    expect(find.byType(AuthWebLoginConfirmPage), findsNothing);
    expect(await resultFuture, isTrue);
  });

  testWidgets('web login confirm cancel closes without confirmation result', (
    tester,
  ) async {
    final repository = _TrackingAuthRepository();
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const SizedBox.shrink(),
        ),
      ),
    );

    final resultFuture = navigatorKey.currentState!.push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            const AuthWebLoginConfirmPage(authCode: 'auth-1', encrypt: 'enc-1'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('auth-web-login-cancel')));
    await tester.pumpAndSettle();

    expect(find.byType(AuthWebLoginConfirmPage), findsNothing);
    expect(await resultFuture, isNull);
  });

  testWidgets('web login confirm keeps page open and shows error on failure', (
    tester,
  ) async {
    final repository = _TrackingAuthRepository()..failGrant = true;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: AuthWebLoginConfirmPage(authCode: 'auth-1', encrypt: 'enc-1'),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('auth-web-login-confirm')));
    await tester.pumpAndSettle();

    expect(repository.calls.where((call) => call == 'grant').length, 1);
    expect(find.byType(AuthWebLoginConfirmPage), findsOneWidget);
    expect(find.textContaining('grant failed'), findsOneWidget);
  });

  testWidgets(
    'device sessions page removes a remote device and reloads the list',
    (tester) async {
      final repository = _TrackingAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: AuthDeviceSessionsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('auth-page-panel')), findsOneWidget);
      expect(find.byType(AuthActionButton), findsOneWidget);
      expect(
        find.byKey(const ValueKey('auth-device-desktop-1')),
        findsOneWidget,
      );

      repository.calls.clear();

      final removeButton = find.descendant(
        of: find.byKey(const ValueKey('auth-device-desktop-1')),
        matching: find.byType(TextButton),
      );
      expect(removeButton, findsOneWidget);

      await tester.tap(removeButton);
      await tester.pumpAndSettle();

      expect(repository.calls, <String>['delete:desktop-1', 'load']);
      expect(find.byKey(const ValueKey('auth-device-desktop-1')), findsNothing);
    },
  );

  testWidgets('device sessions page exposes a back button that pops', (
    tester,
  ) async {
    final repository = _TrackingAuthRepository();
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const SizedBox.shrink(),
        ),
      ),
    );

    final resultFuture = navigatorKey.currentState!.push<bool>(
      MaterialPageRoute(builder: (_) => const AuthDeviceSessionsPage()),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('auth-device-sessions-back')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AuthDeviceSessionsPage), findsNothing);
    expect(await resultFuture, isNull);
  });

  testWidgets('device sessions page keeps shared surface on empty state', (
    tester,
  ) async {
    final repository = _TrackingAuthRepository(
      initialDevices: const <LoginBridgeDeviceRecord>[],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: AuthDeviceSessionsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('auth-page-panel')), findsOneWidget);
    expect(find.byType(AuthActionButton), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-device-desktop-1')), findsNothing);
  });

  testWidgets('device sessions load failure renders shared status banner', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FailingDeviceLoadAuthRepository(),
          ),
        ],
        child: const MaterialApp(home: AuthDeviceSessionsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('auth-page-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-status-banner')), findsOneWidget);
    expect(find.textContaining('load failed'), findsOneWidget);
  });

  testWidgets(
    'quit-all failure clears on retry instead of leaving the page stuck',
    (tester) async {
      final repository = _TrackingAuthRepository()..failQuitAllOnce = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: AuthDeviceSessionsPage()),
        ),
      );
      await tester.pumpAndSettle();

      final quitAllButton = find.byType(AuthActionButton).first;

      await tester.tap(quitAllButton);
      await tester.pumpAndSettle();
      expect(find.textContaining('quit failed'), findsOneWidget);

      await tester.tap(quitAllButton);
      await tester.pumpAndSettle();
      expect(find.textContaining('quit failed'), findsNothing);
    },
  );

  testWidgets('device sessions page pops after quit-all succeeds', (
    tester,
  ) async {
    final repository = _TrackingAuthRepository();
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const SizedBox.shrink(),
        ),
      ),
    );

    final resultFuture = navigatorKey.currentState!.push<bool>(
      MaterialPageRoute(builder: (_) => const AuthDeviceSessionsPage()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AuthActionButton).first);
    await tester.pumpAndSettle();

    expect(repository.calls, contains('quit-all'));
    expect(find.byType(AuthDeviceSessionsPage), findsNothing);
    expect(await resultFuture, isTrue);
  });

  testWidgets(
    'device sessions page terminates the local session instead of popping when the current PC or Web device quits all sessions',
    (tester) async {
      final repository = _TrackingAuthRepository();
      final navigatorKey = GlobalKey<NavigatorState>();
      var localSessionTerminationCount = 0;
      var routeCompleted = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(repository),
            quitAllShouldTerminateLocalSessionProvider.overrideWithValue(true),
            localSessionTerminatorProvider.overrideWithValue(() async {
              localSessionTerminationCount += 1;
            }),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: const SizedBox.shrink(),
          ),
        ),
      );

      final resultFuture = navigatorKey.currentState!.push<bool>(
        MaterialPageRoute(builder: (_) => const AuthDeviceSessionsPage()),
      );
      resultFuture.then((_) => routeCompleted = true);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(AuthActionButton).first);
      await tester.pumpAndSettle();

      expect(repository.calls, contains('quit-all'));
      expect(localSessionTerminationCount, 1);
      expect(routeCompleted, isFalse);
      expect(find.byType(AuthDeviceSessionsPage), findsOneWidget);
    },
  );

  testWidgets('third login page exposes shared panel and provider cards', (
    tester,
  ) async {
    await _pumpThirdLoginPage(tester, repository: _FakeAuthRepository());

    expect(find.byKey(const ValueKey('auth-page-panel')), findsOneWidget);
    expect(find.text('第三方登录'), findsOneWidget);
    expect(find.text('严格对齐 Android 原版的浏览器授权与轮询登录链路'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('auth-third-login-start')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('auth-third-login-github')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('auth-third-login-gitee')),
      findsOneWidget,
    );
  });

  testWidgets('web login confirm shows Android-style explanatory description', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: const MaterialApp(
          home: AuthWebLoginConfirmPage(authCode: 'auth-1', encrypt: 'enc-1'),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('auth-web-login-description')),
      findsOneWidget,
    );
    expect(find.textContaining('Web'), findsWidgets);
  });

  testWidgets('third login polling is serialized and handles failed status', (
    tester,
  ) async {
    final repository = _ThirdLoginAuthRepository();
    final statusCompleter = Completer<ThirdLoginStatusResult>();
    repository.statusCompleter = statusCompleter;
    const urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');
    final launchedUrls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlLauncherChannel, (methodCall) async {
          if (methodCall.method == 'launch') {
            final arguments =
                methodCall.arguments as Map<Object?, Object?>? ?? const {};
            launchedUrls.add(arguments['url']?.toString() ?? '');
            return true;
          }
          if (methodCall.method == 'canLaunch') {
            return true;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(urlLauncherChannel, null);
    });

    await _pumpThirdLoginPage(tester, repository: repository);

    await tester.tap(find.byKey(const ValueKey('auth-third-login-github')));
    await tester.pump();

    expect(launchedUrls, hasLength(1));
    expect(launchedUrls.single, contains('/v1/user/github?authcode='));

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(repository.statusCallCount, 1);

    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    expect(repository.statusCallCount, 1);
    expect(repository.maxConcurrentStatusCallCount, 1);

    statusCompleter.complete(
      const ThirdLoginStatusResult(status: 2, message: 'poll failed'),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('poll failed'), findsOneWidget);
    expect(repository.thirdPartyLoginCallCount, 0);
  });

  testWidgets('scan login confirm opens the auth web login page', (
    tester,
  ) async {
    await _pumpScanLoginConfirmPage(tester);

    await tester.tap(find.byType(ElevatedButton).first);
    await tester.pumpAndSettle();

    expect(find.byType(AuthWebLoginConfirmPage), findsOneWidget);
  });

  testWidgets('scan login confirm keeps confirm action visible', (
    tester,
  ) async {
    await _pumpScanLoginConfirmPage(tester);

    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
