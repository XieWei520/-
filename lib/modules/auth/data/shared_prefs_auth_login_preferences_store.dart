import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/storage_utils.dart';
import '../domain/auth_login_preferences.dart';
import '../domain/auth_login_preferences_store.dart';

class SharedPrefsAuthLoginPreferencesStore
    implements AuthLoginPreferencesStore {
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<AuthLoginPreferences> load() async {
    final prefs = await _prefs;
    return AuthLoginPreferences(
      zoneCode: prefs.getString(AppConstants.keyAuthLoginZoneCode) ?? '0086',
      phone: prefs.getString(AppConstants.keyAuthLoginPhone) ?? '',
      password: prefs.getString(AppConstants.keyAuthLoginPassword) ?? '',
      rememberPassword:
          prefs.getBool(AppConstants.keyAuthRememberPassword) ?? false,
      autoLogin: prefs.getBool(AppConstants.keyAuthAutoLogin) ?? false,
    ).normalize();
  }

  @override
  Future<void> save(AuthLoginPreferences preferences) async {
    final prefs = await _prefs;
    final normalized = preferences.normalize();

    await prefs.setString(
      AppConstants.keyAuthLoginZoneCode,
      normalized.zoneCode,
    );
    await prefs.setString(AppConstants.keyAuthLoginPhone, normalized.phone);
    await prefs.setBool(
      AppConstants.keyAuthRememberPassword,
      normalized.rememberPassword,
    );
    await prefs.setBool(AppConstants.keyAuthAutoLogin, normalized.autoLogin);

    if (normalized.rememberPassword) {
      await prefs.setString(
        AppConstants.keyAuthLoginPassword,
        normalized.password,
      );
    } else {
      await prefs.remove(AppConstants.keyAuthLoginPassword);
    }
  }

  @override
  Future<void> clearSavedSecret({bool keepPhone = true}) async {
    final prefs = await _prefs;
    if (!keepPhone) {
      await prefs.remove(AppConstants.keyAuthLoginPhone);
    }
    await prefs.remove(AppConstants.keyAuthLoginPassword);
    await prefs.setBool(AppConstants.keyAuthRememberPassword, false);
    await prefs.setBool(AppConstants.keyAuthAutoLogin, false);
  }

  @override
  Future<void> disableAutoLogin() async {
    final prefs = await _prefs;
    await prefs.setBool(AppConstants.keyAuthAutoLogin, false);
  }
}

class AuthApiBaseUrlPreferencesStore {
  static const String key = AppConstants.keyAuthLoginApiBaseUrl;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String> load() async {
    if (StorageUtils.isInitialized) {
      return (StorageUtils.getString(key) ?? '').trim();
    }
    final prefs = await _prefs;
    return (prefs.getString(key) ?? '').trim();
  }

  Future<void> save(String value) async {
    if (StorageUtils.isInitialized) {
      await StorageUtils.setString(key, value.trim());
      return;
    }
    final prefs = await _prefs;
    await prefs.setString(key, value.trim());
  }
}
