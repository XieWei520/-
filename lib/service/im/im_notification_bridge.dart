import 'package:flutter/widgets.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

import '../../wukong_push/notification/android_message_alert_manager.dart';
import '../../wukong_push/notification/desktop_message_alert_manager.dart';
import '../../wukong_push/notification/message_alert_plan.dart';
import '../../wukong_push/notification/web_notification_manager.dart';

class ImNotificationBridge {
  ImNotificationBridge({
    required this.androidAlerts,
    required this.desktopAlerts,
    required this.webNotifications,
  });

  final AndroidMessageAlertManager androidAlerts;
  final DesktopMessageAlertManager desktopAlerts;
  final WebNotificationManager webNotifications;

  Future<void> initialize() {
    throw UnimplementedError(
      'Skeleton only: initialize platform notification channels here.',
    );
  }

  Future<void> handleIncomingMessages(
    List<WKMsg> messages, {
    required String currentUid,
    required AppLifecycleState lifecycleState,
  }) {
    throw UnimplementedError(
      'Skeleton only: move new-message notification dispatch here.',
    );
  }

  Future<void> showMessageAlert(
    WKMsg message, {
    required String currentUid,
    required AppLifecycleState lifecycleState,
    bool requireRedDot = true,
  }) {
    throw UnimplementedError(
      'Skeleton only: build MessageAlertPlan and fan out by platform here.',
    );
  }

  Future<void> dispatchPlan(
    MessageAlertPlan plan, {
    required AppLifecycleState lifecycleState,
  }) {
    throw UnimplementedError(
      'Skeleton only: call Android, desktop, and web alert managers here.',
    );
  }

  Future<void> dispose() {
    throw UnimplementedError(
      'Skeleton only: dispose owned notification resources here.',
    );
  }
}
