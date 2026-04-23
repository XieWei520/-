class AppConfig {
  AppConfig._();

  static const String appName = '信息平权';
  static const String appVersion = '1.0.0';

  static const bool isDevelopment = bool.fromEnvironment(
    'WK_IS_DEV',
    defaultValue: true,
  );

  static const bool enableLog = bool.fromEnvironment(
    'WK_ENABLE_LOG',
    defaultValue: true,
  );
}
