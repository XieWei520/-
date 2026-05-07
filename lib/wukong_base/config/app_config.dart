/// App configuration
class AppConfig {
  /// App name
  static const String appName = '信息平权';

  /// App version
  static const String appVersion = '1.0.0';

  /// Build number
  static const int buildNumber = 1;

  /// API base URL
  static const String apiBaseUrl = 'https://infoequity.cn';

  /// WebSocket URL
  static const String wsUrl = 'wss://infoequity.cn/ws';

  /// Production API base URL
  static const String apiBaseUrlProd = 'https://infoequity.cn';

  /// Production WebSocket URL
  static const String wsUrlProd = 'wss://infoequity.cn/ws';

  /// Get current API URL based on environment
  static String get apiUrl => apiBaseUrl;

  /// Get current WebSocket URL based on environment
  static String get websocketUrl => wsUrl;

  /// Is production environment
  static bool get isProduction => false;

  /// Debug mode
  static bool get isDebug => !isProduction;

  /// Enable logging
  static bool get enableLogging => isDebug;

  /// Connection timeout in seconds
  static const int connectionTimeout = 30;

  /// Receive timeout in seconds
  static const int receiveTimeout = 30;

  /// Max retry attempts
  static const int maxRetryAttempts = 3;

  /// Image max width
  static const int imageMaxWidth = 1920;

  /// Image max height
  static const int imageMaxHeight = 1920;

  /// Image quality (0-100)
  static const int imageQuality = 85;

  /// Voice recording max duration in seconds
  static const int voiceMaxDuration = 60;

  /// Video recording max duration in seconds
  static const int videoMaxDuration = 120;

  /// File upload max size in bytes (100MB)
  static const int fileUploadMaxSize = 100 * 1024 * 1024;

  /// Message page size
  static const int messagePageSize = 20;

  /// Conversation page size
  static const int conversationPageSize = 30;

  /// Friend page size
  static const int friendPageSize = 50;

  /// Group member page size
  static const int groupMemberPageSize = 100;

  /// Cache expiration time in hours
  static const int cacheExpirationHours = 24;

  /// Enable message encryption
  static bool get enableEncryption => true;

  /// Enable typing indicators
  static bool get enableTypingIndicator => true;

  /// Enable read receipts
  static bool get enableReadReceipt => true;

  /// Enable push notifications
  static bool get enablePushNotification => true;

  /// Enable location services
  static bool get enableLocation => true;

  /// Enable audio/video calls
  static bool get enableCalls => true;
}
