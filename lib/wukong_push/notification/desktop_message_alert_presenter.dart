import 'desktop_message_alert_policy.dart';

abstract class DesktopMessageAlertPresenter {
  Future<void> initialize();

  Future<void> playForegroundTick();

  Future<void> playMessageSound();

  Future<void> showNotification(DesktopMessageNotification notification);

  Future<void> dispose();
}
