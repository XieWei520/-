import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukong_im_app/service/im/im_notification_bridge.dart';
import 'package:wukong_im_app/service/im/im_service_providers.dart';
import 'package:wukong_im_app/wukong_push/notification/android_message_alert_manager.dart';
import 'package:wukong_im_app/wukong_push/notification/desktop_message_alert_manager.dart';
import 'package:wukong_im_app/wukong_push/notification/desktop_message_alert_policy.dart';
import 'package:wukong_im_app/wukong_push/notification/desktop_message_alert_presenter.dart';
import 'package:wukong_im_app/wukong_push/notification/web_notification_manager.dart';

Override noopImNotificationBridgeOverride() {
  return imNotificationBridgeProvider.overrideWithValue(
    ImNotificationBridge(
      androidAlerts: AndroidMessageAlertManager(
        presenter: _NoopAndroidMessageAlertPresenter(),
        targetPlatform: () => TargetPlatform.android,
      ),
      desktopAlerts: DesktopMessageAlertManager(
        presenter: _NoopDesktopMessageAlertPresenter(),
        targetPlatform: () => TargetPlatform.windows,
      ),
      webNotifications: WebNotificationManager(),
    ),
  );
}

class _NoopAndroidMessageAlertPresenter
    implements AndroidMessageAlertPresenter {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> playForegroundTick() async {}

  @override
  Future<void> showNotification(
    AndroidMessageNotification notification,
  ) async {}

  @override
  Future<void> dispose() async {}
}

class _NoopDesktopMessageAlertPresenter
    implements DesktopMessageAlertPresenter {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> playForegroundTick() async {}

  @override
  Future<void> playMessageSound() async {}

  @override
  Future<void> showNotification(
    DesktopMessageNotification notification,
  ) async {}

  @override
  Future<void> dispose() async {}
}
