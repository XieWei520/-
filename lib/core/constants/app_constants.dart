// 应用常量
class AppConstants {
  AppConstants._();

  // SharedPreferences Keys
  static const String keyUid = 'uid';
  static const String keyToken = 'token';
  static const String keyImToken = 'im_token';
  static const String keyUserInfo = 'user_info';
  static const String keyDeviceId = 'device_id';
  static const String keyDeviceInstallId = 'device_install_id';
  static const String keyDeviceSessionId = 'device_session_id';
  static const String keyDeviceBindVersion = 'device_bind_version';
  static const String keyDeviceBoundUserId = 'device_bound_user_id';
  static const String keyDeviceIdentitySnapshot = 'device_identity_snapshot';
  static const String keyLoginExpire = 'login_expire';
  static const String keyPushToken = 'push_token';
  static const String keyPushType = 'push_type';
  static const String keyDeviceCenterLastSyncAt = 'device_center_last_sync_at';
  static const String keyAuthLoginZoneCode = 'auth_login_zone_code';
  static const String keyAuthLoginPhone = 'auth_login_phone';
  static const String keyAuthLoginPassword = 'auth_login_password';
  static const String keyAuthRememberPassword = 'auth_remember_password';
  static const String keyAuthAutoLogin = 'auth_auto_login';
  static const String keyAuthLoginApiBaseUrl = 'auth_login_api_base_url';
  static const String keyChatPwdCount = 'wk_chat_pwd_count';

  // 存储Key
  static const String spName = 'wukong_im_sp';
  static const String dbName = 'wukong_im.db';
  static const String hiveBoxName = 'wukong_im_hive';

  // 最大输入长度
  static const int maxTextLength = 5000;
  static const int maxSingleMessageLength = 1000;

  // 图片压缩质量
  static const int imageCompressQuality = 80;
  static const int imageMaxWidth = 1920;
  static const int imageMaxHeight = 1920;

  // 语音最大时长（秒）
  static const int maxVoiceDuration = 60;
  static const int minVoiceDuration = 1;

  // 视频最大时长（秒）
  static const int maxVideoDuration = 120;

  // 文件大小限制（字节）
  static const int maxFileSize = 100 * 1024 * 1024; // 100MB

  // 分页大小
  static const int pageSize = 20;
  static const int messagePageSize = 50;
}
