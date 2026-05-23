import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/data/providers/auth_provider.dart';
import 'package:wukong_im_app/data/providers/runtime_capabilities_provider.dart';
import 'package:wukong_im_app/modules/auth/application/auth_providers.dart';
import 'package:wukong_im_app/modules/auth/domain/auth_flow_models.dart';
import 'package:wukong_im_app/modules/auth/domain/auth_login_preferences.dart';
import 'package:wukong_im_app/modules/auth/domain/auth_login_preferences_store.dart';
import 'package:wukong_im_app/modules/auth/domain/auth_repository.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_login_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/pages/auth_reset_password_page.dart';
import 'package:wukong_im_app/modules/auth/presentation/widgets/auth_area_code_picker.dart';
import 'package:wukong_im_app/modules/auth/presentation/widgets/auth_copy.dart';
import 'package:wukong_im_app/modules/auth/presentation/widgets/auth_flow_shell.dart';
import 'package:wukong_im_app/service/api/common_api.dart';
import 'package:wukong_im_app/service/api/login_bridge_api.dart';
import 'package:wukong_im_app/widgets/wk_design_tokens.dart';
import 'package:wukong_im_app/widgets/wk_sub_page_scaffold.dart';

class _PendingLoginAuthRepository implements AuthRepository {
  _PendingLoginAuthRepository(this._pendingLogin);

  final Future<AuthCredentialResult> _pendingLogin;
  int loginCallCount = 0;

  @override
  Future<AuthCredentialResult> loginWithPhone({
    required String zone,
    required String phone,
    required String password,
  }) {
    loginCallCount += 1;
    return _pendingLogin;
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
  Future<UserInfo?> getCurrentUser() {
    throw UnimplementedError();
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
  Future<AuthCredentialResult> loginWithThirdPartyAuthCode(String authCode) {
    throw UnimplementedError();
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
  Future<void> sendRegisterCode({required String zone, required String phone}) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendLoginVerificationCode(String uid) {
    throw UnimplementedError();
  }

  @override
  Future<AuthCredentialResult> verifyLoginCode({
    required String uid,
    required String code,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendResetPasswordCode({
    required String zone,
    required String phone,
  }) {
    throw UnimplementedError();
  }
}

class _RecordingAuthLoginPreferencesStore implements AuthLoginPreferencesStore {
  _RecordingAuthLoginPreferencesStore({
    AuthLoginPreferences initial = const AuthLoginPreferences(),
    Future<void> Function()? beforeSave,
  }) : _stored = initial.normalize(),
       _beforeSave = beforeSave;

  AuthLoginPreferences _stored;
  final Future<void> Function()? _beforeSave;
  int loadCallCount = 0;
  int saveCallCount = 0;
  int disableAutoLoginCallCount = 0;
  final List<AuthLoginPreferences> saveHistory = <AuthLoginPreferences>[];

  AuthLoginPreferences get stored => _stored;

  @override
  Future<AuthLoginPreferences> load() async {
    loadCallCount += 1;
    return _stored;
  }

  @override
  Future<void> save(AuthLoginPreferences preferences) async {
    saveCallCount += 1;
    final beforeSave = _beforeSave;
    if (beforeSave != null) {
      await beforeSave();
    }
    _stored = preferences.normalize();
    saveHistory.add(_stored);
  }

  @override
  Future<void> clearSavedSecret({bool keepPhone = true}) async {}

  @override
  Future<void> disableAutoLogin() async {
    disableAutoLoginCallCount += 1;
    _stored = AuthLoginPreferences(
      zoneCode: _stored.zoneCode,
      phone: _stored.phone,
      password: _stored.password,
      rememberPassword: _stored.rememberPassword,
      autoLogin: false,
    ).normalize();
  }
}

class _DeferredAuthLoginPreferencesStore implements AuthLoginPreferencesStore {
  _DeferredAuthLoginPreferencesStore({
    AuthLoginPreferences initial = const AuthLoginPreferences(),
  }) : _stored = initial.normalize();

  final Completer<void> _loadCompleter = Completer<void>();
  AuthLoginPreferences _stored;
  int saveCallCount = 0;

  void completeLoad([AuthLoginPreferences? preferences]) {
    if (preferences != null) {
      _stored = preferences.normalize();
    }
    if (_loadCompleter.isCompleted) {
      return;
    }
    _loadCompleter.complete();
  }

  @override
  Future<AuthLoginPreferences> load() async {
    await _loadCompleter.future;
    return _stored;
  }

  @override
  Future<void> save(AuthLoginPreferences preferences) async {
    saveCallCount += 1;
    _stored = preferences.normalize();
  }

  @override
  Future<void> clearSavedSecret({bool keepPhone = true}) async {}

  @override
  Future<void> disableAutoLogin() async {
    _stored = AuthLoginPreferences(
      zoneCode: _stored.zoneCode,
      phone: _stored.phone,
      password: _stored.password,
      rememberPassword: _stored.rememberPassword,
      autoLogin: false,
    ).normalize();
  }
}

void main() {
  const loginPrimaryActionKey = ValueKey<String>('auth-login-primary-action');
  const rememberPasswordSwitchKey = ValueKey<String>(
    'auth_login_remember_password_switch',
  );
  const autoLoginSwitchKey = ValueKey<String>('auth_login_auto_login_switch');

  Future<void> pumpLoginPage(
    WidgetTester tester, {
    List<Override> overrides = const <Override>[],
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(home: AuthLoginPage()),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
  }

  bool switchValue(WidgetTester tester, ValueKey<String> key) {
    return tester.widget<WKAndroidSwitch>(find.byKey(key)).value;
  }

  void expectStatusBanner(
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

  test('normalizes hk/tw area code to five-digit international format', () {
    const hk = AuthAreaCodeOption(zoneCode: '0852', countryName: '中国香港');
    const tw = AuthAreaCodeOption(zoneCode: '0886', countryName: '中国台湾');
    const cn = AuthAreaCodeOption(zoneCode: '86', countryName: '中国');
    const us = AuthAreaCodeOption(zoneCode: '1', countryName: '美国');

    expect(hk.normalizedZoneCode, '00852');
    expect(tw.normalizedZoneCode, '00886');
    expect(cn.normalizedZoneCode, '0086');
    expect(us.normalizedZoneCode, '0001');
  });

  test(
    'explicit logout disables auto-login persistence hook',
    () async {
      var autoLoginDisabled = false;
      final container = ProviderContainer(
        overrides: [
          authLogoutRequestProvider.overrideWithValue(() async {}),
          authAutoLoginDisablerProvider.overrideWithValue(() async {
            autoLoginDisabled = true;
          }),
          authCurrentUserLoaderProvider.overrideWithValue(() async => null),
          authDraftSyncProvider.overrideWithValue(() async {}),
        ],
      );

      await container.read(authProvider.notifier).logout();

      expect(autoLoginDisabled, isTrue);
    },
    skip:
        'Logout invalidates async runtime notifiers that race in widget tests',
  );

  testWidgets(
    'auth flow shell does not throw on small viewport with tall content',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(320, 480));

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthFlowShell(
            title: AuthCopy.loginButton,
            child: SizedBox(height: 900, child: Placeholder()),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('renders login within shared auth panel on desktop viewport', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1366, 900));

    await pumpLoginPage(tester);

    expect(find.byKey(const ValueKey('auth-brand-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-form-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-page-panel')), findsOneWidget);
    expect(find.text('欢迎登录'), findsOneWidget);
    expect(find.text('信息平权'), findsWidgets);
    expect(find.text('InfoEquity'), findsNothing);
    expect(find.text('让全天下的人没有信息差'), findsOneWidget);
    expect(find.text('使用手机号和密码进入信息平权'), findsOneWidget);
    expect(find.text('真实信息更快抵达'), findsOneWidget);
    expect(find.text('统一可信入口'), findsOneWidget);
    expect(find.text(AuthCopy.loginBrandHighlights.last), findsOneWidget);
    expect(find.byKey(loginPrimaryActionKey), findsOneWidget);
    expect(
      find.byKey(const ValueKey('auth_login_phone_field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('auth_login_password_field')),
      findsOneWidget,
    );
  });

  testWidgets('login page uses liquid-glass auth stage', (tester) async {
    await pumpLoginPage(tester);

    final background = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('wk_login_background')),
    );
    final decoration = background.decoration as BoxDecoration;
    expect(decoration.color, const Color(0xFFF0F4F8));

    final stageShell = tester.widget<Container>(
      find.byKey(const ValueKey<String>('auth-stage-shell')),
    );
    final shellDecoration = stageShell.decoration! as BoxDecoration;
    expect(shellDecoration.borderRadius, BorderRadius.circular(20));
  });

  testWidgets('login page footer shows the ICP filing link', (tester) async {
    await pumpLoginPage(tester);

    final filingLink = find.byKey(
      const ValueKey<String>('auth_login_icp_link'),
    );

    expect(filingLink, findsOneWidget);
    expect(
      find.textContaining('\u6e58ICP\u59072026016828\u53f7'),
      findsOneWidget,
    );
    expect(tester.widget<TextButton>(filingLink).onPressed, isNotNull);

    final textStyle = tester
        .widget<TextButton>(filingLink)
        .style
        ?.textStyle
        ?.resolve(<WidgetState>{});
    expect(textStyle?.fontFamily, WKFontFamily.primary);
    expect(textStyle?.fontFamilyFallback, contains('Microsoft YaHei UI'));
  });

  testWidgets('renders remember-password and auto-login toggles', (
    tester,
  ) async {
    await pumpLoginPage(tester);

    expect(find.text(AuthCopy.rememberPasswordToggle), findsOneWidget);
    expect(find.text(AuthCopy.autoLoginToggle), findsOneWidget);
    expect(find.byKey(rememberPasswordSwitchKey), findsOneWidget);
    expect(find.byKey(autoLoginSwitchKey), findsOneWidget);
  });

  testWidgets('supports Android-style API base URL edit and reset surface', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await pumpLoginPage(
      tester,
      overrides: [
        runtimeCapabilitiesProvider.overrideWith(
          (ref) async => const AppRuntimeCapabilities(
            webLoginUrl: '',
            webLoginReachable: false,
            webLoginStatusMessage: 'disabled',
            canModifyApiUrl: true,
          ),
        ),
      ],
    );

    final editSurface = find.byKey(
      const ValueKey<String>('auth_login_base_url_edit'),
    );
    final resetSurface = find.byKey(
      const ValueKey<String>('auth_login_base_url_reset'),
    );

    expect(editSurface, findsOneWidget);
    expect(resetSurface, findsNothing);

    await tester.ensureVisible(editSurface);
    await tester.tap(editSurface);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('auth_login_base_url_input')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('auth_login_base_url_input')),
      '127.0.0.1:5001',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('auth_login_base_url_confirm')),
    );
    await tester.pumpAndSettle();

    expect(find.text('http://127.0.0.1:5001'), findsOneWidget);
    expect(resetSurface, findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString(
        'auth_login_api_base_url',
      ),
      'http://127.0.0.1:5001',
    );

    await tester.ensureVisible(resetSurface);
    await tester.tap(resetSurface);
    await tester.pumpAndSettle();

    expect(resetSurface, findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getString(
        'auth_login_api_base_url',
      ),
      '',
    );
  });

  testWidgets(
    'hides API base URL edit surface when runtime appconfig disables it',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await pumpLoginPage(
        tester,
        overrides: [
          runtimeCapabilitiesProvider.overrideWith(
            (ref) async => const AppRuntimeCapabilities(
              webLoginUrl: '',
              webLoginReachable: false,
              webLoginStatusMessage: 'disabled',
              canModifyApiUrl: false,
            ),
          ),
        ],
      );

      expect(
        find.byKey(const ValueKey<String>('auth_login_base_url_edit')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('auth_login_base_url_reset')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'enabling auto-login forces remember-password and turning remember off clears auto-login',
    (tester) async {
      final preferencesStore = _RecordingAuthLoginPreferencesStore();
      await pumpLoginPage(
        tester,
        overrides: [
          authLoginPreferencesStoreProvider.overrideWithValue(preferencesStore),
        ],
      );

      expect(switchValue(tester, rememberPasswordSwitchKey), isFalse);
      expect(switchValue(tester, autoLoginSwitchKey), isFalse);

      await tester.tap(find.byKey(autoLoginSwitchKey));
      await tester.pumpAndSettle();

      expect(switchValue(tester, autoLoginSwitchKey), isTrue);
      expect(switchValue(tester, rememberPasswordSwitchKey), isTrue);

      await tester.tap(find.byKey(rememberPasswordSwitchKey));
      await tester.pumpAndSettle();

      expect(switchValue(tester, rememberPasswordSwitchKey), isFalse);
      expect(switchValue(tester, autoLoginSwitchKey), isFalse);
      expect(preferencesStore.stored.rememberPassword, isFalse);
      expect(preferencesStore.stored.autoLogin, isFalse);
    },
  );

  testWidgets('restores saved login preferences into fields and toggles', (
    tester,
  ) async {
    final preferencesStore = _RecordingAuthLoginPreferencesStore(
      initial: const AuthLoginPreferences(
        zoneCode: '0001',
        phone: '5551234',
        password: 'secret123',
        rememberPassword: true,
        autoLogin: false,
      ),
    );

    await pumpLoginPage(
      tester,
      overrides: [
        authLoginPreferencesStoreProvider.overrideWithValue(preferencesStore),
      ],
    );

    expect(find.text('+1'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('auth_login_phone_field')),
          )
          .controller
          ?.text,
      '5551234',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('auth_login_password_field')),
          )
          .controller
          ?.text,
      'secret123',
    );
    expect(switchValue(tester, rememberPasswordSwitchKey), isTrue);
    expect(switchValue(tester, autoLoginSwitchKey), isFalse);
  });

  testWidgets('async preference restore does not overwrite user edits', (
    tester,
  ) async {
    final preferencesStore = _DeferredAuthLoginPreferencesStore();

    await pumpLoginPage(
      tester,
      settle: false,
      overrides: [
        authLoginPreferencesStoreProvider.overrideWithValue(preferencesStore),
      ],
    );

    await tester.enterText(
      find.byKey(const ValueKey('auth_login_phone_field')),
      '13800138000',
    );
    await tester.pump();

    preferencesStore.completeLoad(
      const AuthLoginPreferences(
        zoneCode: '0001',
        phone: '5551234',
        password: 'oldpass',
        rememberPassword: true,
        autoLogin: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('auth_login_phone_field')),
          )
          .controller
          ?.text,
      '13800138000',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('auth_login_password_field')),
          )
          .controller
          ?.text,
      isEmpty,
    );
    expect(switchValue(tester, rememberPasswordSwitchKey), isFalse);
    expect(switchValue(tester, autoLoginSwitchKey), isFalse);
  });

  testWidgets(
    'non-preference interactions do not save defaults before async restore completes',
    (tester) async {
      final preferencesStore = _DeferredAuthLoginPreferencesStore(
        initial: const AuthLoginPreferences(
          zoneCode: '0086',
          phone: '13800138000',
          password: 'oldpass',
          rememberPassword: true,
          autoLogin: false,
        ),
      );

      await pumpLoginPage(
        tester,
        settle: false,
        overrides: [
          authLoginPreferencesStoreProvider.overrideWithValue(preferencesStore),
        ],
      );

      await tester.tap(find.byKey(const ValueKey('auth_login_terms_toggle')));
      await tester.pump();

      expect(preferencesStore.saveCallCount, 0);

      preferencesStore.completeLoad();
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('auth_login_phone_field')),
            )
            .controller
            ?.text,
        '13800138000',
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('auth_login_password_field')),
            )
            .controller
            ?.text,
        'oldpass',
      );
      expect(switchValue(tester, rememberPasswordSwitchKey), isTrue);
      expect(switchValue(tester, autoLoginSwitchKey), isFalse);
    },
  );

  testWidgets(
    'saved auto-login credentials trigger exactly one automatic login attempt',
    (tester) async {
      final preferencesStore = _RecordingAuthLoginPreferencesStore(
        initial: const AuthLoginPreferences(
          zoneCode: '0086',
          phone: '13800138000',
          password: '123456',
          rememberPassword: true,
          autoLogin: true,
        ),
      );
      final pendingLogin = Completer<AuthCredentialResult>();
      final repository = _PendingLoginAuthRepository(pendingLogin.future);

      await pumpLoginPage(
        tester,
        settle: false,
        overrides: [
          authLoginPreferencesStoreProvider.overrideWithValue(preferencesStore),
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(repository.loginCallCount, 1);
    },
  );

  testWidgets('auto-login failure disables persisted auto-login flag', (
    tester,
  ) async {
    final preferencesStore = _RecordingAuthLoginPreferencesStore(
      initial: const AuthLoginPreferences(
        zoneCode: '0086',
        phone: '13800138000',
        password: '123456',
        rememberPassword: true,
        autoLogin: true,
      ),
    );
    final repository = _PendingLoginAuthRepository(
      Future<AuthCredentialResult>.value(
        const AuthCredentialResult.failure('invalid credentials'),
      ),
    );

    await pumpLoginPage(
      tester,
      overrides: [
        authLoginPreferencesStoreProvider.overrideWithValue(preferencesStore),
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );

    expect(repository.loginCallCount, 1);
    expect(preferencesStore.stored.autoLogin, isFalse);
  });

  testWidgets(
    'auto-login failure keeps auto-login disabled when preference save completes late',
    (tester) async {
      final saveCompleter = Completer<void>();
      final preferencesStore = _RecordingAuthLoginPreferencesStore(
        initial: const AuthLoginPreferences(
          zoneCode: '0086',
          phone: '13800138000',
          password: '123456',
          rememberPassword: true,
          autoLogin: true,
        ),
        beforeSave: () => saveCompleter.future,
      );
      final repository = _PendingLoginAuthRepository(
        Future<AuthCredentialResult>.value(
          const AuthCredentialResult.failure('invalid credentials'),
        ),
      );

      await pumpLoginPage(
        tester,
        settle: false,
        overrides: [
          authLoginPreferencesStoreProvider.overrideWithValue(preferencesStore),
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      saveCompleter.complete();
      await tester.pumpAndSettle();

      expect(repository.loginCallCount, 1);
      expect(preferencesStore.disableAutoLoginCallCount, 1);
      expect(preferencesStore.stored.autoLogin, isFalse);
    },
  );

  testWidgets(
    'auto-login validation failure disables persisted auto-login flag',
    (tester) async {
      final preferencesStore = _RecordingAuthLoginPreferencesStore(
        initial: const AuthLoginPreferences(
          zoneCode: '0086',
          phone: '12345',
          password: '123456',
          rememberPassword: true,
          autoLogin: true,
        ),
      );
      final repository = _PendingLoginAuthRepository(
        Future<AuthCredentialResult>.value(
          const AuthCredentialResult.failure('should not be used'),
        ),
      );

      await pumpLoginPage(
        tester,
        overrides: [
          authLoginPreferencesStoreProvider.overrideWithValue(preferencesStore),
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );

      expect(repository.loginCallCount, 0);
      expect(preferencesStore.stored.autoLogin, isFalse);
      expectStatusBanner(
        tester,
        message: AuthCopy.validationSummary,
        detail: AuthCopy.errorPhoneLengthCn,
      );
    },
  );

  testWidgets('toggles password visibility from hidden to visible', (
    tester,
  ) async {
    await pumpLoginPage(tester);

    final finder = find.byKey(const ValueKey('auth_login_password_field'));
    expect((tester.widget<TextField>(finder)).obscureText, isTrue);

    await tester.tap(
      find.byKey(const ValueKey('auth_login_password_visibility_toggle')),
    );
    await tester.pump();

    expect((tester.widget<TextField>(finder)).obscureText, isFalse);
  });

  testWidgets('uses banner and inline validation instead of modal errors', (
    tester,
  ) async {
    await pumpLoginPage(tester);

    await tapVisible(tester, find.byKey(loginPrimaryActionKey));
    await tester.pumpAndSettle();
    expectStatusBanner(
      tester,
      message: AuthCopy.validationSummary,
      detail: AuthCopy.errorPhoneRequired,
    );
    expect(
      find.byKey(const ValueKey('auth_login_phone_error')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('auth_login_phone_field')),
      '13800138000',
    );
    await tapVisible(tester, find.byKey(loginPrimaryActionKey));
    await tester.pumpAndSettle();
    expectStatusBanner(
      tester,
      message: AuthCopy.validationSummary,
      detail: AuthCopy.errorPasswordRequired,
    );
    expect(
      find.byKey(const ValueKey('auth_login_password_error')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('auth_login_phone_field')),
      '12345',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth_login_password_field')),
      '123456',
    );
    await tapVisible(tester, find.byKey(loginPrimaryActionKey));
    await tester.pumpAndSettle();
    expectStatusBanner(
      tester,
      message: AuthCopy.validationSummary,
      detail: AuthCopy.errorPhoneLengthCn,
    );
    expect(
      find.byKey(const ValueKey('auth_login_phone_error')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('auth_login_phone_field')),
      '13800138000',
    );
    await tapVisible(tester, find.byKey(loginPrimaryActionKey));
    await tester.pumpAndSettle();
    expectStatusBanner(
      tester,
      message: AuthCopy.validationSummary,
      detail: AuthCopy.errorAgreementRequired,
    );
    expect(
      find.byKey(const ValueKey('auth_login_agreement_error')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('auth_login_terms_toggle')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('auth_login_password_field')),
      '12345',
    );
    await tapVisible(tester, find.byKey(loginPrimaryActionKey));
    await tester.pumpAndSettle();
    expectStatusBanner(
      tester,
      message: AuthCopy.validationSummary,
      detail: AuthCopy.errorPasswordLength,
    );
    expect(
      find.byKey(const ValueKey('auth_login_password_error')),
      findsOneWidget,
    );
  });

  testWidgets('non-CN area code skips 11-digit CN length rule', (tester) async {
    await pumpLoginPage(tester);

    await tester.tap(find.byKey(const ValueKey('auth_login_zone_trigger')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('auth_area_code_sheet')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('auth_area_code_option_0001')));
    await tester.pumpAndSettle();

    expect(find.text('+1'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('auth_login_phone_field')),
      '12345',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth_login_password_field')),
      '123456',
    );

    await tapVisible(tester, find.byKey(loginPrimaryActionKey));
    await tester.pumpAndSettle();

    expectStatusBanner(
      tester,
      message: AuthCopy.validationSummary,
      detail: AuthCopy.errorAgreementRequired,
    );
  });

  testWidgets(
    'password submit action does not trigger duplicate login while loading',
    (tester) async {
      final pendingLogin = Completer<AuthCredentialResult>();
      final repository = _PendingLoginAuthRepository(pendingLogin.future);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: AuthLoginPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('auth_login_phone_field')),
        '13800138000',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth_login_password_field')),
        '123456',
      );
      await tester.tap(find.byKey(const ValueKey('auth_login_terms_toggle')));
      await tester.pump();

      await tapVisible(tester, find.byKey(loginPrimaryActionKey));
      await tester.pump();
      expect(repository.loginCallCount, 1);

      await tester.tap(find.byKey(const ValueKey('auth_login_password_field')));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(repository.loginCallCount, 1);
    },
  );

  testWidgets('failed login shows inline status banner', (tester) async {
    final repository = _PendingLoginAuthRepository(
      Future<AuthCredentialResult>.value(
        const AuthCredentialResult.failure('密码不正确！'),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: AuthLoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('auth_login_phone_field')),
      '13800138000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth_login_password_field')),
      '123456',
    );
    await tester.tap(find.byKey(const ValueKey('auth_login_terms_toggle')));
    await tester.pump();

    await tapVisible(tester, find.byKey(loginPrimaryActionKey));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('auth-status-banner')), findsOneWidget);
    expect(find.text('密码不正确！'), findsWidgets);
  });

  testWidgets('gateway failure shows humanized banner summary and detail', (
    tester,
  ) async {
    final repository = _PendingLoginAuthRepository(
      Future<AuthCredentialResult>.value(
        const AuthCredentialResult.failure(
          'Request failed with status code: 502',
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: AuthLoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('auth_login_phone_field')),
      '13800138000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth_login_password_field')),
      '123456',
    );
    await tester.tap(find.byKey(const ValueKey('auth_login_terms_toggle')));
    await tester.pump();

    await tapVisible(tester, find.byKey(loginPrimaryActionKey));
    await tester.pumpAndSettle();

    expectStatusBanner(
      tester,
      message: AuthCopy.gatewayFailureSummary,
      detail: AuthCopy.gatewayFailureDetail(502),
    );
  });

  testWidgets('forgot password entry navigates to reset password page', (
    tester,
  ) async {
    await pumpLoginPage(tester);

    await tapVisible(tester, find.text(AuthCopy.forgotPasswordEntry));
    await tester.pumpAndSettle();

    expect(find.byType(AuthResetPasswordPage), findsOneWidget);
    expect(find.text(AuthCopy.resetPasswordTitle), findsOneWidget);
  });

  testWidgets('forgot password navigation shows reset page core fields', (
    tester,
  ) async {
    await pumpLoginPage(tester);

    await tapVisible(tester, find.text(AuthCopy.forgotPasswordEntry));
    await tester.pumpAndSettle();

    expect(find.byType(AuthResetPasswordPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('auth_login_zone_trigger')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('auth_reset_phone_field')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('auth_reset_code_field')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('auth_reset_password_field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('auth_reset_submit_button')),
      findsOneWidget,
    );
  });
}
