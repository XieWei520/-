import 'dart:async';

import '../models/push_models.dart';

/// Push handler interface
abstract class PushHandler {
  /// Initialize the push handler
  Future<void> initialize({
    required void Function(String token) onTokenRefresh,
    required void Function(PushMessageEvent event) onMessageReceived,
  });

  /// Get push type
  PushType get pushType;

  /// Check if this handler is available on the device
  Future<bool> isAvailable();

  /// Get the device token
  Future<String?> getToken();

  /// Return the normalized registration snapshot for diagnostics.
  Future<PushRegistrationSnapshot> getRegistrationSnapshot();

  /// Ensure notification permission is granted
  Future<bool> ensurePermission();

  /// Fetch the initial notification if the app was launched from it
  Future<PushMessageEvent?> getInitialMessage();

  /// Subscribe to a topic
  Future<void> subscribe(String topic);

  /// Unsubscribe from a topic
  Future<void> unsubscribe(String topic);

  /// Dispose resources
  void dispose();
}

/// Push type enum (shared)
enum PushType {
  fcm('FIREBASE'),
  huawei('HMS'),
  xiaomi('MI'),
  oppo('OPPO'),
  vivo('VIVO');

  final String value;
  const PushType(this.value);
}
