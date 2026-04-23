import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/utils/storage_utils.dart';
import '../wukong_base/net/api_client.dart';
import 'handlers/fcm_handler.dart';
import 'handlers/push_handler.dart';
import 'models/push_models.dart';
import 'notification/foreground_notification_plan.dart';
import 'notification/notification_helper.dart';
import 'notification_permission_prompt_bridge.dart';

/// Push service types
enum PushType {
  fcm('FIREBASE'),
  huawei('HMS'),
  xiaomi('MI'),
  oppo('OPPO'),
  vivo('VIVO');

  final String value;
  const PushType(this.value);
}

typedef PushHandlerSelector = Future<PushHandler?> Function();
typedef NotificationInitializer =
    Future<void> Function({void Function(String payload)? onNotificationTap});
typedef NotificationPermissionDeniedCallback = Future<void> Function();
typedef PushSupportChecker = bool Function();

class PushService {
  PushService({
    ApiClient? client,
    PushHandlerSelector? handlerSelector,
    NotificationInitializer? initializeNotifications,
    NotificationPermissionDeniedCallback? onPermissionDenied,
    PushSupportChecker? isPushSupported,
  }) : _client = client ?? ApiClient.instance,
       _handlerSelector = handlerSelector ?? _defaultSelectHandler,
       _initializeNotifications =
           initializeNotifications ?? NotificationHelper.instance.initialize,
       _onPermissionDenied = onPermissionDenied ?? _defaultOnPermissionDenied,
       _isPushSupported = isPushSupported ?? _defaultIsPushSupported;
  static final PushService _instance = PushService();
  static PushService get instance => _instance;

  final ApiClient _client;
  final PushHandlerSelector _handlerSelector;
  final NotificationInitializer _initializeNotifications;
  final NotificationPermissionDeniedCallback _onPermissionDenied;
  final PushSupportChecker _isPushSupported;
  final StreamController<PushMessageEvent> _messageController =
      StreamController<PushMessageEvent>.broadcast();
  final List<PushMessageEvent> _pendingOpenedEvents = <PushMessageEvent>[];

  PushHandler? _currentHandler;
  PushRegistrationSnapshot? _registrationSnapshot;
  String? _deviceToken;
  String? _syncedToken;
  String? _syncedPushType;
  String? _bundleId;
  String? _lastRegistrationWarningKey;
  int _registrationSnapshotRefreshEpoch = 0;
  Future<void>? _initFuture;

  Stream<PushMessageEvent> get messageEvents => _messageController.stream;
  PushRegistrationSnapshot? get registrationSnapshot => _registrationSnapshot;

  List<PushMessageEvent> consumePendingOpenedEvents() {
    if (_pendingOpenedEvents.isEmpty) {
      return const <PushMessageEvent>[];
    }
    final pending = List<PushMessageEvent>.from(_pendingOpenedEvents);
    _pendingOpenedEvents.clear();
    return pending;
  }

  Future<void> ensureInitialized() {
    _initFuture ??= _initializeInternal();
    return _initFuture!;
  }

  Future<void> _initializeInternal() async {
    if (!_isPushSupported()) {
      return;
    }

    await _initializeNotifications(
      onNotificationTap: _handleLocalNotificationTap,
    );
    await _restoreSyncedState();

    final handler = await _handlerSelector();
    if (handler == null) {
      debugPrint(
        'PushService: no compatible push handler detected; app is currently configured for FCM only, vendor handlers pending: HMS, MI, OPPO, VIVO.',
      );
      return;
    }
    _currentHandler = handler;

    final permissionGranted = await handler.ensurePermission();
    if (!permissionGranted) {
      debugPrint('PushService: notification permission denied.');
      await _onPermissionDenied();
      return;
    }

    try {
      await handler.initialize(
        onTokenRefresh: _onTokenRefresh,
        onMessageReceived: _handleRemoteMessage,
      );
      await _refreshRegistrationSnapshot();
      final initial = await handler.getInitialMessage();
      if (initial != null) {
        _handleRemoteMessage(initial);
      }
    } catch (e, stackTrace) {
      debugPrint('PushService: initialization failed -> $e');
      debugPrint('$stackTrace');
    }
  }

  static Future<PushHandler?> _defaultSelectHandler() async {
    final handler = FcmHandler();
    if (await handler.isAvailable()) {
      return handler;
    }
    return null;
  }

  static Future<void> _defaultOnPermissionDenied() async {
    await NotificationPermissionPromptBridge.instance.showPrompt();
  }

  static bool _defaultIsPushSupported() {
    if (kIsWeb) {
      return false;
    }
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> _restoreSyncedState() async {
    _syncedToken = StorageUtils.getPushDeviceToken();
    _syncedPushType = StorageUtils.getPushDeviceType();
  }

  /// Should be called after successful login to ensure token registration.
  Future<void> handleLogin() async {
    await ensureInitialized();
    await _syncTokenWithServer(force: true);
  }

  /// Should be called before logout to clean up server state.
  Future<void> handleLogout() async {
    await unregisterToken();
  }

  String? get deviceToken => _deviceToken;

  void _onTokenRefresh(String token) {
    _deviceToken = token;
    unawaited(_refreshRegistrationSnapshot(fallbackDeviceToken: token));
    if (StorageUtils.isLoggedIn()) {
      unawaited(_registerToken(token));
    }
  }

  Future<void> _refreshRegistrationSnapshot({
    String? fallbackDeviceToken,
  }) async {
    final handler = _currentHandler;
    if (handler == null) {
      return;
    }
    final refreshEpoch = ++_registrationSnapshotRefreshEpoch;
    try {
      final snapshot = await handler.getRegistrationSnapshot();
      if (refreshEpoch != _registrationSnapshotRefreshEpoch) {
        return;
      }
      final resolvedSnapshot =
          fallbackDeviceToken != null &&
                  (snapshot.deviceToken == null || snapshot.deviceToken!.isEmpty)
              ? snapshot.copyWith(deviceToken: fallbackDeviceToken)
              : snapshot;
      _registrationSnapshot = resolvedSnapshot;
      if (_shouldWarnForMissingApnsToken(resolvedSnapshot)) {
        debugPrint(
          'PushService: iOS APNs token is not available yet despite having an FCM token. Verify Apple push capability/profile on a real device.',
        );
      }
    } catch (e) {
      debugPrint('PushService: failed to refresh registration snapshot -> $e');
    }
  }

  bool _shouldWarnForMissingApnsToken(PushRegistrationSnapshot snapshot) {
    if (snapshot.applePushTokenState != ApplePushTokenState.missing ||
        !snapshot.hasDeviceToken) {
      _lastRegistrationWarningKey = null;
      return false;
    }

    final warningKey =
        '${snapshot.applePushTokenState.name}:${snapshot.deviceToken}:${snapshot.apnsToken ?? ''}';
    if (_lastRegistrationWarningKey == warningKey) {
      return false;
    }
    _lastRegistrationWarningKey = warningKey;
    return true;
  }

  void _handleRemoteMessage(PushMessageEvent event) {
    if (event.trigger == PushMessageTrigger.foreground) {
      unawaited(_showForegroundNotification(event));
    }
    _dispatchMessageEvent(event);
  }

  void _dispatchMessageEvent(PushMessageEvent event) {
    if (event.openedFromNotification && !_messageController.hasListener) {
      _pendingOpenedEvents.add(event);
    }
    _messageController.add(event);
  }

  Future<void> _showForegroundNotification(PushMessageEvent event) async {
    final plan = buildForegroundNotificationPlan(event);
    if (plan == null) {
      return;
    }
    final identifier =
        event.payload.messageId?.hashCode ??
        DateTime.now().millisecondsSinceEpoch.remainder(0x7fffffff);
    await NotificationHelper.instance.show(
      id: identifier,
      title: plan.title,
      body: plan.body,
      payload: plan.payload,
      channelId: plan.channelId,
      channelName: plan.channelName,
      importance: plan.importance,
    );
  }

  void _handleLocalNotificationTap(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        return;
      }
      final map = Map<String, dynamic>.from(decoded);
      final rawPayload = map['payload'];
      if (rawPayload is! Map) {
        return;
      }
      final pushPayload = PushPayload.fromMap(
        Map<String, dynamic>.from(rawPayload),
      );
      final event = PushMessageEvent(
        payload: pushPayload,
        data: pushPayload.raw,
        trigger: PushMessageTrigger.tap,
        title: map['title']?.toString(),
        body: map['body']?.toString(),
      );
      _dispatchMessageEvent(event);
    } catch (e) {
      debugPrint('PushService: failed to parse notification payload -> $e');
    }
  }

  Future<void> _syncTokenWithServer({bool force = false}) async {
    final handler = _currentHandler;
    if (handler == null) {
      return;
    }
    final activeToken = _deviceToken ?? await handler.getToken();
    if (activeToken == null || activeToken.isEmpty) {
      return;
    }
    await _registerToken(activeToken, force: force);
  }

  Future<void> _registerToken(String token, {bool force = false}) async {
    final handler = _currentHandler;
    if (handler == null || !StorageUtils.isLoggedIn()) {
      return;
    }
    final pushType = handler.pushType.value;
    if (!force && token == _syncedToken && pushType == _syncedPushType) {
      return;
    }

    try {
      final bundleId = await _resolveBundleId();
      final payload = {
        'device_token': token,
        'deviceToken': token,
        'token': token,
        'device_type': pushType,
        'deviceType': pushType,
        'type': pushType,
        'bundle_id': bundleId,
        'bundleId': bundleId,
      };
      await _client.post('/user/device_token', data: payload);
      _syncedToken = token;
      _syncedPushType = pushType;
      await StorageUtils.setPushDeviceToken(token);
      await StorageUtils.setPushDeviceType(pushType);
    } catch (e) {
      debugPrint('PushService: register token failed -> $e');
    }
  }

  Future<void> unregisterToken() async {
    final token = _syncedToken ?? StorageUtils.getPushDeviceToken();
    if (token == null || token.isEmpty) {
      return;
    }
    try {
      await _client.delete(
        '/user/device_token',
        data: {'device_token': token, 'token': token},
      );
    } catch (e) {
      debugPrint('PushService: unregister token failed -> $e');
    } finally {
      _syncedToken = null;
      _syncedPushType = null;
      await StorageUtils.clearPushToken();
    }
  }

  Future<String> _resolveBundleId() async {
    if (_bundleId != null && _bundleId!.isNotEmpty) {
      return _bundleId!;
    }
    final packageInfo = await PackageInfo.fromPlatform();
    final identifier = packageInfo.packageName.trim();
    _bundleId = identifier.isEmpty ? 'com.im.wukong' : identifier;
    return _bundleId!;
  }
}
