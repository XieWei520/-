import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/api_config.dart';
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
      return _sanitizeStoredValue(
        StorageUtils.getString(key),
        saveSanitized: (value) => StorageUtils.setString(key, value),
      );
    }
    final prefs = await _prefs;
    return _sanitizeStoredValue(
      prefs.getString(key),
      saveSanitized: (value) => prefs.setString(key, value),
    );
  }

  Future<void> save(String value) async {
    final normalized = ApiConfig.normalizeRuntimeBaseUrlOverride(value);
    if (StorageUtils.isInitialized) {
      await StorageUtils.setString(key, normalized);
      return;
    }
    final prefs = await _prefs;
    await prefs.setString(key, normalized);
  }

  Future<String> _sanitizeStoredValue(
    String? rawValue, {
    required Future<bool> Function(String value) saveSanitized,
  }) async {
    final raw = rawValue ?? '';
    final normalized = ApiConfig.normalizeRuntimeBaseUrlOverride(raw);
    if (normalized != raw) {
      await saveSanitized(normalized);
    }
    return normalized;
  }
}
