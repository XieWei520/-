import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/im/im_notification_bridge.dart';
import 'package:wukong_im_app/wukong_push/notification/android_message_alert_manager.dart';
import 'package:wukong_im_app/wukong_push/notification/desktop_message_alert_manager.dart';
import 'package:wukong_im_app/wukong_push/notification/desktop_message_alert_policy.dart';
import 'package:wukong_im_app/wukong_push/notification/desktop_message_alert_presenter.dart';
import 'package:wukong_im_app/wukong_push/notification/web_notification_manager.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dispatches eligible desktop message alerts through desktop manager', () async {
    final desktopPresenter = _FakeDesktopPresenter();
    final bridge = ImNotificationBridge(
      androidAlerts: AndroidMessageAlertManager(
        presenter: const _NoopAndroidPresenter(),
        policy: DesktopMessageAlertPolicy(),
        isWeb: () => false,
        targetPlatform: () => TargetPlatform.android,
      ),
      desktopAlerts: DesktopMessageAlertManager(
        presenter: desktopPresenter,
        policy: DesktopMessageAlertPolicy(),
        isWeb: () => false,
        targetPlatform: () => TargetPlatform.windows,
      ),
      webNotifications: WebNotificationManager.instance,
    );

    await bridge.showMessageAlert(
      _textMessage(redDot: true),
      currentUid: 'u_self',
      lifecycleState: AppLifecycleState.hidden,
    );

    expect(desktopPresenter.notifications.single.title, 'u_alice');
    expect(desktopPresenter.notifications.single.body, 'hello');
    expect(desktopPresenter.messageSoundCount, 1);
  });

  test('android background alert does not require red dot', () async {
    final androidPresenter = _FakeAndroidPresenter();
    final bridge = ImNotificationBridge(
      androidAlerts: AndroidMessageAlertManager(
        presenter: androidPresenter,
        policy: DesktopMessageAlertPolicy(),
        isWeb: () => false,
        targetPlatform: () => TargetPlatform.android,
      ),
      desktopAlerts: DesktopMessageAlertManager(
        presenter: const _NoopDesktopPresenter(),
        policy: DesktopMessageAlertPolicy(),
        isWeb: () => false,
        targetPlatform: () => TargetPlatform.windows,
      ),
      webNotifications: WebNotificationManager.instance,
    );

    await bridge.showMessageAlert(
      _textMessage(redDot: false),
      currentUid: 'u_self',
      lifecycleState: AppLifecycleState.hidden,
    );

    expect(androidPresenter.notifications.single.title, 'u_alice');
    expect(androidPresenter.notifications.single.body, 'hello');
  });

  test('focused android alert still requires red dot', () async {
    final androidPresenter = _FakeAndroidPresenter();
    final bridge = ImNotificationBridge(
      androidAlerts: AndroidMessageAlertManager(
        presenter: androidPresenter,
        policy: DesktopMessageAlertPolicy(),
        isWeb: () => false,
        targetPlatform: () => TargetPlatform.android,
      ),
      desktopAlerts: DesktopMessageAlertManager(
        presenter: const _NoopDesktopPresenter(),
        policy: DesktopMessageAlertPolicy(),
        isWeb: () => false,
        targetPlatform: () => TargetPlatform.windows,
      ),
      webNotifications: WebNotificationManager.instance,
    );

    await bridge.showMessageAlert(
      _textMessage(redDot: false),
      currentUid: 'u_self',
      lifecycleState: AppLifecycleState.resumed,
    );

    expect(androidPresenter.notifications, isEmpty);
    expect(androidPresenter.foregroundSoundCount, 0);
  });

  test('desktop background alert still requires red dot', () async {
    final desktopPresenter = _FakeDesktopPresenter();
    final bridge = ImNotificationBridge(
      androidAlerts: AndroidMessageAlertManager(
        presenter: const _NoopAndroidPresenter(),
        policy: DesktopMessageAlertPolicy(),
        isWeb: () => false,
        targetPlatform: () => TargetPlatform.android,
      ),
      desktopAlerts: DesktopMessageAlertManager(
        presenter: desktopPresenter,
        policy: DesktopMessageAlertPolicy(),
        isWeb: () => false,
        targetPlatform: () => TargetPlatform.windows,
      ),
      webNotifications: WebNotificationManager.instance,
    );

    await bridge.showMessageAlert(
      _textMessage(redDot: false),
      currentUid: 'u_self',
      lifecycleState: AppLifecycleState.hidden,
    );

    expect(desktopPresenter.notifications, isEmpty);
    expect(desktopPresenter.messageSoundCount, 0);
  });
}

WKMsg _textMessage({required bool redDot}) {
  return WKMsg()
    ..channelID = 'u_alice'
    ..channelType = WKChannelType.personal
    ..fromUID = 'u_alice'
    ..contentType = WkMessageContentType.text
    ..messageContent = (WKTextContent('hello')
      ..contentType = WkMessageContentType.text)
    ..header.redDot = redDot;
}

class _FakeAndroidPresenter implements AndroidMessageAlertPresenter {
  int foregroundSoundCount = 0;
  final List<AndroidMessageNotification> notifications =
      <AndroidMessageNotification>[];

  @override
  Future<void> dispose() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> playForegroundTick() async {
    foregroundSoundCount += 1;
  }

  @override
  Future<void> showNotification(AndroidMessageNotification notification) async {
    notifications.add(notification);
  }
}

class _NoopAndroidPresenter implements AndroidMessageAlertPresenter {
  const _NoopAndroidPresenter();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> playForegroundTick() async {}

  @override
  Future<void> showNotification(AndroidMessageNotification notification) async {}
}

class _FakeDesktopPresenter implements DesktopMessageAlertPresenter {
  int foregroundSoundCount = 0;
  int messageSoundCount = 0;
  final List<DesktopMessageNotification> notifications =
      <DesktopMessageNotification>[];

  @override
  Future<void> dispose() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> playForegroundTick() async {
    foregroundSoundCount += 1;
  }

  @override
  Future<void> playMessageSound() async {
    messageSoundCount += 1;
  }

  @override
  Future<void> showNotification(DesktopMessageNotification notification) async {
    notifications.add(notification);
  }
}

class _NoopDesktopPresenter implements DesktopMessageAlertPresenter {
  const _NoopDesktopPresenter();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> playForegroundTick() async {}

  @override
  Future<void> playMessageSound() async {}

  @override
  Future<void> showNotification(DesktopMessageNotification notification) async {}
}
