import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

class StorageUtils {
  StorageUtils._();

  static SharedPreferences? _prefs;
  static const String _legacyUidKey = 'wk_uid';
  static const String _legacyTokenKey = 'wk_token';
  static const String _legacyImTokenKey = 'wk_im_token';
  static const String _snapshotFieldDeviceId = 'device_id';
  static const String _snapshotFieldDeviceInstallId = 'device_install_id';
  static const String _snapshotFieldDeviceSessionId = 'device_session_id';
  static const String _snapshotFieldDeviceBindVersion = 'device_bind_version';
  static const String _snapshotFieldDeviceBoundUserId = 'device_bound_user_id';

  static bool get isInitialized => _prefs != null;

  static Future<void> init() async {
    if (_prefs != null) {
      return;
    }
    _prefs = await SharedPreferences.getInstance();
    await _migrateLegacyAuthKeys();
  }

  static SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('StorageUtils not initialized. Call init() first.');
    }
    return _prefs!;
  }

  static Future<bool> setString(String key, String value) {
    return prefs.setString(key, value);
  }

  static String? getString(String key) {
    return _prefs?.getString(key);
  }

  static Future<bool> setInt(String key, int value) {
    return prefs.setInt(key, value);
  }

  static int? getInt(String key) {
    return _prefs?.getInt(key);
  }

  static Future<bool> setBool(String key, bool value) {
    return prefs.setBool(key, value);
  }

  static bool? getBool(String key) {
    return _prefs?.getBool(key);
  }

  static Future<bool> setDouble(String key, double value) {
    return prefs.setDouble(key, value);
  }

  static double? getDouble(String key) {
    return _prefs?.getDouble(key);
  }

  static Future<bool> setStringList(String key, List<String> value) {
    return prefs.setStringList(key, value);
  }

  static List<String>? getStringList(String key) {
    return _prefs?.getStringList(key);
  }

  static Future<bool> remove(String key) {
    if (_prefs == null) {
      return Future.value(false);
    }
    return prefs.remove(key);
  }

  static Future<bool> clear() {
    if (_prefs == null) {
      return Future.value(false);
    }
    return prefs.clear();
  }

  static bool containsKey(String key) {
    return _prefs?.containsKey(key) ?? false;
  }

  static Future<bool> setUid(String uid) {
    return setString(AppConstants.keyUid, uid);
  }

  static String? getUid() {
    return getString(AppConstants.keyUid);
  }

  static Future<bool> setToken(String token) {
    return setString(AppConstants.keyToken, token);
  }

  static String? getToken() {
    return getString(AppConstants.keyToken);
  }

  static Future<bool> clearToken() {
    return remove(AppConstants.keyToken);
  }

  static Future<bool> setImToken(String token) {
    return setString(AppConstants.keyImToken, token);
  }

  static String? getImToken() {
    return getString(AppConstants.keyImToken);
  }

  static Future<bool> clearImToken() {
    return remove(AppConstants.keyImToken);
  }

  static Future<bool> setPushDeviceToken(String token) {
    return setString(AppConstants.keyPushToken, token);
  }

  static String? getPushDeviceToken() {
    return getString(AppConstants.keyPushToken);
  }

  static Future<bool> setPushDeviceType(String type) {
    return setString(AppConstants.keyPushType, type);
  }

  static String? getPushDeviceType() {
    return getString(AppConstants.keyPushType);
  }

  static Future<void> clearPushToken() async {
    await remove(AppConstants.keyPushToken);
    await remove(AppConstants.keyPushType);
  }

  static Future<bool> setDeviceId(String deviceId) {
    return setString(AppConstants.keyDeviceId, deviceId);
  }

  static String? getDeviceId() {
    return _getSnapshotString(_snapshotFieldDeviceId) ??
        getString(AppConstants.keyDeviceId);
  }

  static Future<bool> setDeviceInstallId(String value) {
    return setString(AppConstants.keyDeviceInstallId, value);
  }

  static String? getDeviceInstallId() {
    return _getSnapshotString(_snapshotFieldDeviceInstallId) ??
        getString(AppConstants.keyDeviceInstallId);
  }

  static Future<bool> setDeviceSessionId(String value) {
    return setString(AppConstants.keyDeviceSessionId, value);
  }

  static String? getDeviceSessionId() {
    return _getSnapshotString(_snapshotFieldDeviceSessionId) ??
        getString(AppConstants.keyDeviceSessionId);
  }

  static Future<bool> setDeviceBindVersion(int value) {
    return setInt(AppConstants.keyDeviceBindVersion, value);
  }

  static int getDeviceBindVersion() {
    return _getSnapshotInt(_snapshotFieldDeviceBindVersion) ??
        getInt(AppConstants.keyDeviceBindVersion) ??
        0;
  }

  static Future<bool> setDeviceBoundUserId(String value) {
    return setString(AppConstants.keyDeviceBoundUserId, value);
  }

  static String? getDeviceBoundUserId() {
    return _getSnapshotString(_snapshotFieldDeviceBoundUserId) ??
        getString(AppConstants.keyDeviceBoundUserId);
  }

  static Future<bool> setDeviceIdentitySnapshot(String value) {
    return setString(AppConstants.keyDeviceIdentitySnapshot, value);
  }

  static String? getDeviceIdentitySnapshot() {
    return getString(AppConstants.keyDeviceIdentitySnapshot);
  }

  static bool isLoggedIn() {
    if (_prefs == null) {
      return false;
    }
    final uid = getUid();
    final token = getToken();
    return uid != null && uid.isNotEmpty && token != null && token.isNotEmpty;
  }

  static Future<void> logout() async {
    if (_prefs == null) {
      return;
    }
    await remove(AppConstants.keyUid);
    await remove(AppConstants.keyToken);
    await remove(AppConstants.keyImToken);
    await remove(AppConstants.keyUserInfo);
    await clearPushToken();
  }

  static Future<void> _migrateLegacyAuthKeys() async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }

    final currentUid = prefs.getString(AppConstants.keyUid)?.trim() ?? '';
    final currentToken = prefs.getString(AppConstants.keyToken)?.trim() ?? '';
    final currentImToken =
        prefs.getString(AppConstants.keyImToken)?.trim() ?? '';
    final legacyUid = prefs.getString(_legacyUidKey)?.trim() ?? '';
    final legacyToken = prefs.getString(_legacyTokenKey)?.trim() ?? '';
    final legacyImToken = prefs.getString(_legacyImTokenKey)?.trim() ?? '';

    if (currentUid.isEmpty && legacyUid.isNotEmpty) {
      await prefs.setString(AppConstants.keyUid, legacyUid);
    }
    if (currentToken.isEmpty && legacyToken.isNotEmpty) {
      await prefs.setString(AppConstants.keyToken, legacyToken);
    }
    if (currentImToken.isEmpty && legacyImToken.isNotEmpty) {
      await prefs.setString(AppConstants.keyImToken, legacyImToken);
    }
  }

  static String? _getSnapshotString(String field) {
    final value = _getDeviceIdentitySnapshotMap()?[field];
    return value is String ? value : null;
  }

  static int? _getSnapshotInt(String field) {
    final value = _getDeviceIdentitySnapshotMap()?[field];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  static Map<String, Object?>? _getDeviceIdentitySnapshotMap() {
    final raw = getDeviceIdentitySnapshot();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return decoded.map<String, Object?>(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );
    } catch (_) {
      return null;
    }
  }
}
