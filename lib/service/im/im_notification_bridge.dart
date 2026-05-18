import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

import '../../wukong_push/notification/android_message_alert_manager.dart';
import '../../wukong_push/notification/desktop_message_alert_manager.dart';
import '../../wukong_push/notification/message_alert_plan.dart';
import '../../wukong_push/notification/web_notification_manager.dart';

typedef ImNotificationSchedulingErrorReporter =
    void Function(Object error, StackTrace stackTrace);

class ImNotificationBridge {
  ImNotificationBridge({
    required this.androidAlerts,
    required this.desktopAlerts,
    required this.webNotifications,
    ImNotificationSchedulingErrorReporter? onSchedulingError,
  }) : _onSchedulingError =
           onSchedulingError ?? _defaultSchedulingErrorReporter;

  factory ImNotificationBridge.platformDefaults() {
    return ImNotificationBridge(
      androidAlerts: AndroidMessageAlertManager.instance,
      desktopAlerts: DesktopMessageAlertManager.instance,
      webNotifications: WebNotificationManager.instance,
    );
  }

  final AndroidMessageAlertManager androidAlerts;
  final DesktopMessageAlertManager desktopAlerts;
  final WebNotificationManager webNotifications;
  final ImNotificationSchedulingErrorReporter _onSchedulingError;

  Future<void> initialize() async {
    // Web notification permission/audio unlock must still be triggered from a
    // user gesture, so the bridge only keeps a single platform-facing entry
    // point instead of forcing initialization here.
  }

  Future<void> handleIncomingMessages(
    List<WKMsg> messages, {
    required String currentUid,
    required AppLifecycleState lifecycleState,
  }) async {
    for (final message in messages) {
      await showMessageAlert(
        message,
        currentUid: currentUid,
        lifecycleState: lifecycleState,
      );
    }
  }

  void scheduleMessageAlert(
    WKMsg message, {
    required String currentUid,
    required AppLifecycleState lifecycleState,
    bool requireRedDot = true,
  }) {
    unawaited(
      _guardedMessageAlert(
        message,
        currentUid: currentUid,
        lifecycleState: lifecycleState,
        requireRedDot: requireRedDot,
      ),
    );
  }

  Future<void> showMessageAlert(
    WKMsg message, {
    required String currentUid,
    required AppLifecycleState lifecycleState,
    bool requireRedDot = true,
  }) async {
    final standardPlan = buildMessageAlertPlan(
      message,
      currentUid: currentUid,
      requireRedDot: requireRedDot,
    );
    final androidPlan = buildMessageAlertPlan(
      message,
      currentUid: currentUid,
      requireRedDot: _shouldRequireRedDotForAndroid(
        lifecycleState: lifecycleState,
        requested: requireRedDot,
      ),
    );
    if (standardPlan == null && androidPlan == null) {
      return;
    }
    await _dispatchPlatformPlans(
      androidPlan: androidPlan,
      standardPlan: standardPlan,
      lifecycleState: lifecycleState,
    );
  }

  Future<void> dispatchPlan(
    MessageAlertPlan plan, {
    required AppLifecycleState lifecycleState,
  }) async {
    await Future.wait(<Future<void>>[
      androidAlerts.showNewMessageAlert(
        plan: plan,
        lifecycleState: lifecycleState,
      ),
      desktopAlerts.showNewMessageAlert(
        plan: plan,
        lifecycleState: lifecycleState,
      ),
      webNotifications.showNewMessageAlert(
        plan: plan,
        lifecycleState: lifecycleState,
      ),
    ]);
  }

  Future<void> dispose() async {
    await Future.wait(<Future<void>>[
      androidAlerts.dispose(),
      desktopAlerts.dispose(),
      webNotifications.dispose(),
    ]);
  }

  Future<void> _dispatchPlatformPlans({
    required MessageAlertPlan? androidPlan,
    required MessageAlertPlan? standardPlan,
    required AppLifecycleState lifecycleState,
  }) async {
    await Future.wait(<Future<void>>[
      if (androidPlan != null)
        androidAlerts.showNewMessageAlert(
          plan: androidPlan,
          lifecycleState: lifecycleState,
        ),
      if (standardPlan != null) ...<Future<void>>[
        desktopAlerts.showNewMessageAlert(
          plan: standardPlan,
          lifecycleState: lifecycleState,
        ),
        webNotifications.showNewMessageAlert(
          plan: standardPlan,
          lifecycleState: lifecycleState,
        ),
      ],
    ]);
  }

  bool _shouldRequireRedDotForAndroid({
    required AppLifecycleState lifecycleState,
    required bool requested,
  }) {
    if (!requested) {
      return false;
    }
    return lifecycleState == AppLifecycleState.resumed;
  }

  Future<void> _guardedMessageAlert(
    WKMsg message, {
    required String currentUid,
    required AppLifecycleState lifecycleState,
    required bool requireRedDot,
  }) async {
    try {
      await showMessageAlert(
        message,
        currentUid: currentUid,
        lifecycleState: lifecycleState,
        requireRedDot: requireRedDot,
      );
    } catch (error, stackTrace) {
      _onSchedulingError(error, stackTrace);
    }
  }
}

void _defaultSchedulingErrorReporter(Object error, StackTrace stackTrace) {
  debugPrint('Message alert scheduling failed: $error');
  debugPrint('$stackTrace');
}
