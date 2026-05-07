import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/constants/app_constants.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/modules/auth/data/shared_prefs_auth_login_preferences_store.dart';
import 'package:wukong_im_app/modules/auth/domain/auth_login_preferences.dart';
import 'package:wukong_im_app/modules/auth/domain/auth_login_preferences_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('load returns defaults when nothing is stored', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = SharedPrefsAuthLoginPreferencesStore();

    final restored = await store.load();
    expect(restored.zoneCode, '0086');
    expect(restored.phone, isEmpty);
    expect(restored.password, isEmpty);
    expect(restored.rememberPassword, isFalse);
    expect(restored.autoLogin, isFalse);
    expect(restored.hasUsableCredentials, isFalse);
  });

  test(
    'normalize trims whitespace, applies default zone code, and computes usable credentials',
    () {
      const whitespace = AuthLoginPreferences(
        zoneCode: '   ',
        phone: ' 13800138000 ',
        password: '',
        rememberPassword: false,
        autoLogin: true,
      );

      expect(whitespace.hasUsableCredentials, isFalse);
      final normalizedWhitespace = whitespace.normalize();
      expect(normalizedWhitespace.zoneCode, '0086');
      expect(normalizedWhitespace.phone, '13800138000');
      expect(normalizedWhitespace.rememberPassword, isTrue);
      expect(normalizedWhitespace.autoLogin, isFalse);
      expect(normalizedWhitespace.hasUsableCredentials, isFalse);

      const usable = AuthLoginPreferences(
        zoneCode: ' 0086 ',
        phone: ' 13800138000 ',
        password: 'secret123',
      );
      expect(usable.hasUsableCredentials, isTrue);
      final normalizedUsable = usable.normalize();
      expect(normalizedUsable.zoneCode, '0086');
      expect(normalizedUsable.phone, '13800138000');
      expect(normalizedUsable.hasUsableCredentials, isTrue);
    },
  );

  test(
    'save normalizes auto login dependency and clear removes saved secret',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = SharedPrefsAuthLoginPreferencesStore();

      await store.save(
        const AuthLoginPreferences(
          zoneCode: '0086',
          phone: '13800138000',
          password: 'secret123',
          rememberPassword: false,
          autoLogin: true,
        ),
      );

      final restored = await store.load();
      expect(restored.zoneCode, '0086');
      expect(restored.phone, '13800138000');
      expect(restored.password, 'secret123');
      expect(restored.rememberPassword, isTrue);
      expect(restored.autoLogin, isTrue);

      await store.clearSavedSecret(keepPhone: true);
      final cleared = await store.load();
      expect(cleared.phone, '13800138000');
      expect(cleared.password, isEmpty);
      expect(cleared.rememberPassword, isFalse);
      expect(cleared.autoLogin, isFalse);
    },
  );

  test('save removes stored password when rememberPassword is false', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = SharedPrefsAuthLoginPreferencesStore();

    await store.save(
      const AuthLoginPreferences(
        zoneCode: '0086',
        phone: '13800138000',
        password: 'secret123',
        rememberPassword: true,
        autoLogin: false,
      ),
    );

    await store.save(
      const AuthLoginPreferences(
        zoneCode: '0086',
        phone: '13800138000',
        password: 'secret123',
        rememberPassword: false,
        autoLogin: false,
      ),
    );

    final restored = await store.load();
    expect(restored.password, isEmpty);
    expect(restored.rememberPassword, isFalse);
    expect(restored.autoLogin, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(AppConstants.keyAuthLoginPassword), isFalse);
  });

  test('clearSavedSecret removes phone when keepPhone is false', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = SharedPrefsAuthLoginPreferencesStore();

    await store.save(
      const AuthLoginPreferences(
        zoneCode: '0086',
        phone: '13800138000',
        password: 'secret123',
        rememberPassword: true,
        autoLogin: true,
      ),
    );

    await store.clearSavedSecret(keepPhone: false);
    final cleared = await store.load();
    expect(cleared.phone, isEmpty);
    expect(cleared.password, isEmpty);
    expect(cleared.rememberPassword, isFalse);
    expect(cleared.autoLogin, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(AppConstants.keyAuthLoginPhone), isFalse);
  });

  test('disableAutoLogin only turns off auto-login', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.keyAuthLoginZoneCode: '0086',
      AppConstants.keyAuthLoginPhone: '13800138000',
      AppConstants.keyAuthLoginPassword: 'secret123',
      AppConstants.keyAuthRememberPassword: true,
      AppConstants.keyAuthAutoLogin: true,
    });
    final store = SharedPrefsAuthLoginPreferencesStore();

    await store.disableAutoLogin();

    final restored = await store.load();
    expect(restored.zoneCode, '0086');
    expect(restored.phone, '13800138000');
    expect(restored.password, 'secret123');
    expect(restored.rememberPassword, isTrue);
    expect(restored.autoLogin, isFalse);
  });

  test('API base URL store clears disallowed public host overrides', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.keyAuthLoginApiBaseUrl: 'https://legacy-public.example.com',
    });
    final store = AuthApiBaseUrlPreferencesStore();

    expect(await store.load(), isEmpty);
    expect(
      (await SharedPreferences.getInstance()).getString(
        AppConstants.keyAuthLoginApiBaseUrl,
      ),
      isEmpty,
    );
  });

  test('API base URL store preserves local and official overrides', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = AuthApiBaseUrlPreferencesStore();

    await store.save(' http://127.0.0.1:15001/ ');
    expect(await store.load(), 'http://127.0.0.1:15001');

    await store.save(' https://infoequity.cn/ ');
    expect(await store.load(), 'https://infoequity.cn');
  });

  test(
    'reconcileAuthenticatedLoginPreferences updates the stored account identity while preserving saved password settings',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppConstants.keyAuthLoginZoneCode: '0086',
        AppConstants.keyAuthLoginPhone: '19212455072',
        AppConstants.keyAuthLoginPassword: 'secret123',
        AppConstants.keyAuthRememberPassword: true,
        AppConstants.keyAuthAutoLogin: true,
      });
      final store = SharedPrefsAuthLoginPreferencesStore();

      await reconcileAuthenticatedLoginPreferences(
        store,
        UserInfo(uid: 'u-1', phone: '19212455074', zone: '0086', token: 't-1'),
      );

      final restored = await store.load();
      expect(restored.zoneCode, '0086');
      expect(restored.phone, '19212455074');
      expect(restored.password, 'secret123');
      expect(restored.rememberPassword, isTrue);
      expect(restored.autoLogin, isTrue);
    },
  );
}
