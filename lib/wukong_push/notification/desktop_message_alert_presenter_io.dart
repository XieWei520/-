import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_notifier/local_notifier.dart';

import '../../core/config/app_config.dart';
import 'desktop_message_alert_policy.dart';
import 'desktop_message_alert_presenter.dart';

DesktopMessageAlertPresenter createDesktopMessageAlertPresenter() {
  return DesktopMessageAlertPresenterIo();
}

class DesktopMessageAlertPresenterIo implements DesktopMessageAlertPresenter {
  DesktopMessageAlertPresenterIo();

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    try {
      await localNotifier.setup(
        appName: AppConfig.appName,
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      _initialized = true;
    } catch (error, stackTrace) {
      _logError(
        'Desktop notification presenter initialization failed',
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<void> playForegroundTick() async {
    await _play(SystemSoundType.click);
  }

  @override
  Future<void> playMessageSound() async {
    await _play(SystemSoundType.alert);
  }

  @override
  Future<void> showNotification(DesktopMessageNotification notification) async {
    await initialize();
    try {
      final localNotification = LocalNotification(
        identifier: notification.identifier,
        title: notification.title,
        body: notification.body,
        silent: true,
      );
      await localNotification.show();
    } catch (error, stackTrace) {
      _logError(
        'Showing desktop message notification failed',
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<void> dispose() async {}

  Future<void> _play(SystemSoundType soundType) async {
    await initialize();
    try {
      await SystemSound.play(soundType);
    } catch (error, stackTrace) {
      _logError(
        'Playing desktop message alert sound failed',
        error,
        stackTrace,
      );
    }
  }

  void _logError(String message, Object error, StackTrace stackTrace) {
    debugPrint('$message: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
