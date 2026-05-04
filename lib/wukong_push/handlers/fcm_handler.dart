import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as permission;

import '../models/push_models.dart';
import 'push_handler.dart';

class FcmHandler implements PushHandler {
  FcmHandler();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _tapSubscription;
  StreamSubscription<String>? _tokenSubscription;
  static bool _backgroundHandlerRegistered = false;

  @override
  PushType get pushType => PushType.fcm;

  @override
  Future<void> initialize({
    required void Function(String token) onTokenRefresh,
    required void Function(PushMessageEvent event) onMessageReceived,
  }) async {
    if (!await isAvailable()) {
      throw StateError('FCM is only available on Android/iOS.');
    }

    await _ensureFirebaseInitialized();
    _registerBackgroundHandler();

    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    final currentToken = await _messaging.getToken();
    if (currentToken != null && currentToken.isNotEmpty) {
      onTokenRefresh(currentToken);
    }

    _tokenSubscription = _messaging.onTokenRefresh.listen(onTokenRefresh);

    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      onMessageReceived(_mapToEvent(message, PushMessageTrigger.foreground));
    });

    _tapSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      onMessageReceived(_mapToEvent(message, PushMessageTrigger.tap));
    });
  }

  PushMessageEvent _mapToEvent(
    RemoteMessage message,
    PushMessageTrigger trigger,
  ) {
    final data = Map<String, dynamic>.from(message.data);
    final payload = PushPayload.fromMap(data);
    final notification = message.notification;
    final title =
        notification?.title ?? payload.title ?? data['title']?.toString();
    final body = notification?.body ?? payload.body ?? data['body']?.toString();

    return PushMessageEvent(
      payload: PushPayload(
        raw: payload.raw,
        channelId: payload.channelId,
        channelType: payload.channelType,
        messageId: payload.messageId ?? message.messageId,
        senderUid: payload.senderUid,
        title: title,
        body: body,
      ),
      data: data,
      trigger: trigger,
      title: title,
      body: body,
    );
  }

  Future<void> _ensureFirebaseInitialized() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  }

  static void _registerBackgroundHandler() {
    if (_backgroundHandlerRegistered) {
      return;
    }
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _backgroundHandlerRegistered = true;
  }

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  Future<String?> getToken() {
    return _messaging.getToken();
  }

  @override
  Future<PushRegistrationSnapshot> getRegistrationSnapshot() async {
    final deviceToken = await _messaging.getToken();
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return PushRegistrationSnapshot(
        deviceToken: deviceToken,
        applePushTokenState: ApplePushTokenState.notApplicable,
      );
    }

    final apnsToken = await _messaging.getAPNSToken();
    return PushRegistrationSnapshot(
      deviceToken: deviceToken,
      apnsToken: apnsToken,
      applePushTokenState:
          apnsToken != null && apnsToken.isNotEmpty
              ? ApplePushTokenState.available
              : ApplePushTokenState.missing,
    );
  }

  @override
  Future<bool> ensurePermission() async {
    if (kIsWeb) {
      return false;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await permission.Permission.notification.status;
      if (status.isGranted) {
        return true;
      }
      final result = await permission.Permission.notification.request();
      return result.isGranted;
    }

    return false;
  }

  @override
  Future<PushMessageEvent?> getInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    if (message == null) {
      return null;
    }
    return _mapToEvent(message, PushMessageTrigger.initial);
  }

  @override
  Future<void> subscribe(String topic) {
    return _messaging.subscribeToTopic(topic);
  }

  @override
  Future<void> unsubscribe(String topic) {
    return _messaging.unsubscribeFromTopic(topic);
  }

  @override
  void dispose() {
    unawaited(_foregroundSubscription?.cancel());
    unawaited(_tapSubscription?.cancel());
    unawaited(_tokenSubscription?.cancel());
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}
