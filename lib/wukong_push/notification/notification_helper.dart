import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification helper
class NotificationHelper {
  NotificationHelper._();
  static final NotificationHelper _instance = NotificationHelper._();
  static NotificationHelper get instance => _instance;

  static const String messageChannelId = 'wk_new_msg_notification';
  static const String messageChannelName = 'New message notifications';
  static const String rtcChannelId = 'wk_new_rtc_notification';
  static const String rtcChannelName = 'Call invitation notifications';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  void Function(String payload)? _payloadHandler;

  /// Initialize notification plugin
  Future<void> initialize({
    void Function(String payload)? onNotificationTap,
  }) async {
    if (onNotificationTap != null) {
      _payloadHandler = onNotificationTap;
    }
    if (_isInitialized) return;

    // Android settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
  }

  /// Register handler for notification taps
  void registerOnNotificationTap(void Function(String payload) handler) {
    _payloadHandler = handler;
  }

  /// Request notification permissions (mainly for iOS/macOS)
  Future<bool> requestPermissions({
    bool alert = true,
    bool badge = true,
    bool sound = true,
  }) async {
    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final macPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();

    final iosResult =
        await iosPlugin?.requestPermissions(
          alert: alert,
          badge: badge,
          sound: sound,
        ) ??
        true;
    final macResult =
        await macPlugin?.requestPermissions(
          alert: alert,
          badge: badge,
          sound: sound,
        ) ??
        true;
    return iosResult && macResult;
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    final payload = response.payload;
    if (payload != null) {
      _handleNotificationPayload(payload);
    }
  }

  void _handleNotificationPayload(String payload) {
    final handler = _payloadHandler;
    if (handler != null && payload.isNotEmpty) {
      handler(payload);
    }
  }

  /// Show a notification
  Future<void> show({
    required int id,
    String? title,
    String? body,
    String? payload,
    String? channelId,
    String? channelName,
    Importance importance = Importance.defaultImportance,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId ?? 'default_channel',
      channelName ?? 'Default Channel',
      importance: importance,
      priority: Priority.defaultPriority,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details, payload: payload);
  }

  /// Show group notification
  Future<void> showGroup({
    required int id,
    required String title,
    required String body,
    required String groupKey,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      messageChannelId,
      messageChannelName,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      groupKey: groupKey,
      setAsGroupSummary: false,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details, payload: payload);
  }

  /// Cancel a notification
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return _plugin.pendingNotificationRequests();
  }
}
