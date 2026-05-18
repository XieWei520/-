import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification helper
class NotificationHelper {
  NotificationHelper._();
  static final NotificationHelper _instance = NotificationHelper._();
  static NotificationHelper get instance => _instance;

  static const String messageChannelId = 'wk_new_msg_notification';
  static const String messageChannelName = 'New message notifications';
  static const String legacyMessageAlertChannelId =
      'wk_new_msg_alert_notification';
  static const String messageAlertChannelId =
      'wk_new_msg_alert_notification_v2';
  static const String messageAlertChannelName = 'New message alerts';
  static const String messageAlertChannelDescription =
      'Message alerts with sound and heads-up notification cards.';
  static const String messageSoundResource = 'im_message';
  static const String rtcChannelId = 'wk_new_rtc_notification';
  static const String rtcChannelName = 'Call invitation notifications';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  void Function(String payload)? _payloadHandler;

  static const RawResourceAndroidNotificationSound _messageSound =
      RawResourceAndroidNotificationSound(messageSoundResource);

  static AndroidNotificationChannel buildAndroidMessageAlertChannel() {
    return const AndroidNotificationChannel(
      messageAlertChannelId,
      messageAlertChannelName,
      description: messageAlertChannelDescription,
      importance: Importance.high,
      playSound: true,
      sound: _messageSound,
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.notification,
    );
  }

  static AndroidNotificationDetails buildAndroidMessageAlertDetails({
    String? groupKey,
    bool onlyAlertOnce = false,
    bool playSound = true,
    bool enableVibration = true,
  }) {
    return AndroidNotificationDetails(
      messageAlertChannelId,
      messageAlertChannelName,
      channelDescription: messageAlertChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: playSound,
      sound: playSound ? _messageSound : null,
      enableVibration: enableVibration,
      audioAttributesUsage: AudioAttributesUsage.notification,
      category: AndroidNotificationCategory.message,
      groupKey: groupKey,
      onlyAlertOnce: onlyAlertOnce,
      showWhen: true,
    );
  }

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
    await _ensureAndroidChannels();

    _isInitialized = true;
  }

  Future<void> _ensureAndroidChannels() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      buildAndroidMessageAlertChannel(),
    );
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
    final androidResult =
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        true;
    return iosResult && macResult && androidResult;
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
    String? channelDescription,
    Importance importance = Importance.defaultImportance,
    Priority priority = Priority.defaultPriority,
    bool playSound = true,
    AndroidNotificationSound? sound,
    bool onlyAlertOnce = false,
    String? groupKey,
    AndroidNotificationCategory? category,
    bool enableVibration = true,
    AudioAttributesUsage audioAttributesUsage =
        AudioAttributesUsage.notification,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId ?? 'default_channel',
      channelName ?? 'Default Channel',
      channelDescription: channelDescription,
      importance: importance,
      priority: priority,
      playSound: playSound,
      sound: sound,
      enableVibration: enableVibration,
      onlyAlertOnce: onlyAlertOnce,
      groupKey: groupKey,
      category: category,
      audioAttributesUsage: audioAttributesUsage,
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

    try {
      await _plugin.show(id, title, body, details, payload: payload);
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationHelper.show failed for channel '
        '${androidDetails.channelId}: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
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
    try {
      await _plugin.cancel(id);
    } catch (error, stackTrace) {
      debugPrint('NotificationHelper.cancel failed for id $id: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (error, stackTrace) {
      debugPrint('NotificationHelper.cancelAll failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return _plugin.pendingNotificationRequests();
  }
}
