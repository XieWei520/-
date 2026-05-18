import 'package:shared_preferences/shared_preferences.dart';

class FeishuRobotCredentials {
  static const FeishuRobotCredentials empty = FeishuRobotCredentials(
    appId: '',
    appSecret: '',
  );

  final String appId;
  final String appSecret;

  const FeishuRobotCredentials({required this.appId, required this.appSecret});

  bool get isConfigured =>
      appId.trim().isNotEmpty && appSecret.trim().isNotEmpty;

  FeishuRobotCredentials normalize() {
    return FeishuRobotCredentials(
      appId: appId.trim(),
      appSecret: appSecret.trim(),
    );
  }
}

abstract class FeishuRobotCredentialsStore {
  Future<FeishuRobotCredentials> load();

  Future<void> save(FeishuRobotCredentials credentials);
}

class SharedPreferencesFeishuRobotCredentialsStore
    implements FeishuRobotCredentialsStore {
  static const String appIdKey = 'feishu_robot_global_app_id';
  static const String appSecretKey = 'feishu_robot_global_app_secret';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<FeishuRobotCredentials> load() async {
    final prefs = await _prefs;
    return FeishuRobotCredentials(
      appId: prefs.getString(appIdKey) ?? '',
      appSecret: prefs.getString(appSecretKey) ?? '',
    ).normalize();
  }

  @override
  Future<void> save(FeishuRobotCredentials credentials) async {
    final prefs = await _prefs;
    final normalized = credentials.normalize();
    await prefs.setString(appIdKey, normalized.appId);
    await prefs.setString(appSecretKey, normalized.appSecret);
  }
}
