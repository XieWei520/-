import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_push/notification/desktop_message_alert_manager.dart';
import 'package:wukong_im_app/wukong_push/notification/desktop_message_alert_policy.dart';
import 'package:wukong_im_app/wukong_push/notification/desktop_message_alert_presenter.dart';
import 'package:wukong_im_app/wukong_push/notification/message_alert_plan.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('DesktopMessageAlertManager', () {
    test('ignores non-Windows platforms', () async {
      final presenter = _FakePresenter();
      final manager = DesktopMessageAlertManager(
        presenter: presenter,
        policy: DesktopMessageAlertPolicy(),
        isWeb: () => false,
        targetPlatform: () => TargetPlatform.macOS,
      );

      await manager.showNewMessageAlert(
        plan: _plan(),
        lifecycleState: AppLifecycleState.hidden,
      );

      expect(presenter.notifications, isEmpty);
      expect(presenter.messageSoundCount, 0);
      expect(presenter.foregroundSoundCount, 0);
    });

    test('focused Windows message only plays foreground sound', () async {
      final presenter = _FakePresenter();
      final manager = DesktopMessageAlertManager(
        presenter: presenter,
        policy: DesktopMessageAlertPolicy(),
        isWeb: () => false,
        targetPlatform: () => TargetPlatform.windows,
      );

      await manager.showNewMessageAlert(
        plan: _plan(),
        lifecycleState: AppLifecycleState.resumed,
      );

      expect(presenter.foregroundSoundCount, 1);
      expect(presenter.messageSoundCount, 0);
      expect(presenter.notifications, isEmpty);
    });

    test(
      'background Windows message plays message sound and shows card',
      () async {
        final presenter = _FakePresenter();
        final manager = DesktopMessageAlertManager(
          presenter: presenter,
          policy: DesktopMessageAlertPolicy(),
          isWeb: () => false,
          targetPlatform: () => TargetPlatform.windows,
        );

        await manager.showNewMessageAlert(
          plan: _plan(),
          lifecycleState: AppLifecycleState.hidden,
        );

        expect(presenter.foregroundSoundCount, 0);
        expect(presenter.messageSoundCount, 1);
        expect(presenter.notifications.single.title, 'Alice');
      },
    );
  });
}

MessageAlertPlan _plan() {
  return const MessageAlertPlan(
    title: 'Alice',
    body: 'hello',
    channelId: 'alice',
    channelType: WKChannelType.personal,
  );
}

class _FakePresenter implements DesktopMessageAlertPresenter {
  int foregroundSoundCount = 0;
  int messageSoundCount = 0;
  final List<DesktopMessageNotification> notifications =
      <DesktopMessageNotification>[];

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

  @override
  Future<void> dispose() async {}
}
