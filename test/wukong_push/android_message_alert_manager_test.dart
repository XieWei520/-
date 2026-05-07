import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_push/notification/android_message_alert_manager.dart';
import 'package:wukong_im_app/wukong_push/notification/desktop_message_alert_policy.dart';
import 'package:wukong_im_app/wukong_push/notification/message_alert_plan.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('AndroidMessageAlertManager', () {
    test('ignores non-Android platforms', () async {
      final presenter = _FakePresenter();
      final manager = AndroidMessageAlertManager(
        presenter: presenter,
        policy: DesktopMessageAlertPolicy(),
        isWeb: () => false,
        targetPlatform: () => TargetPlatform.windows,
      );

      await manager.showNewMessageAlert(
        plan: _plan(),
        lifecycleState: AppLifecycleState.hidden,
      );

      expect(presenter.notifications, isEmpty);
      expect(presenter.foregroundSoundCount, 0);
    });

    test(
      'focused Android message only plays a short foreground sound',
      () async {
        final presenter = _FakePresenter();
        final manager = AndroidMessageAlertManager(
          presenter: presenter,
          policy: DesktopMessageAlertPolicy(),
          isWeb: () => false,
          targetPlatform: () => TargetPlatform.android,
        );

        await manager.showNewMessageAlert(
          plan: _plan(),
          lifecycleState: AppLifecycleState.resumed,
        );

        expect(presenter.foregroundSoundCount, 1);
        expect(presenter.notifications, isEmpty);
      },
    );

    test('background Android message shows a notification card', () async {
      final presenter = _FakePresenter();
      final manager = AndroidMessageAlertManager(
        presenter: presenter,
        policy: DesktopMessageAlertPolicy(),
        isWeb: () => false,
        targetPlatform: () => TargetPlatform.android,
      );

      await manager.showNewMessageAlert(
        plan: _plan(payload: '{"payload":{"channel_id":"alice"}}'),
        lifecycleState: AppLifecycleState.hidden,
      );

      final notification = presenter.notifications.single;
      expect(presenter.foregroundSoundCount, 0);
      expect(notification.title, 'Alice');
      expect(notification.body, 'hello');
      expect(notification.payload, '{"payload":{"channel_id":"alice"}}');
      expect(notification.groupKey, 'wk-message-1-alice');
      expect(notification.onlyAlertOnce, isFalse);
    });

    test(
      'rapid same-conversation cards coalesce without repeated sound',
      () async {
        var now = DateTime(2026, 5, 2, 10);
        final presenter = _FakePresenter();
        final manager = AndroidMessageAlertManager(
          presenter: presenter,
          policy: DesktopMessageAlertPolicy(now: () => now),
          isWeb: () => false,
          targetPlatform: () => TargetPlatform.android,
        );

        await manager.showNewMessageAlert(
          plan: _plan(body: 'first'),
          lifecycleState: AppLifecycleState.hidden,
        );
        now = now.add(const Duration(milliseconds: 800));
        await manager.showNewMessageAlert(
          plan: _plan(body: 'second'),
          lifecycleState: AppLifecycleState.hidden,
        );

        expect(presenter.notifications, hasLength(2));
        expect(
          presenter.notifications.first.id,
          presenter.notifications.last.id,
        );
        expect(presenter.notifications.last.body, '2 new messages');
        expect(presenter.notifications.last.onlyAlertOnce, isTrue);
      },
    );

    test('respects disabled new message notice setting', () async {
      final presenter = _FakePresenter();
      final manager = AndroidMessageAlertManager(
        presenter: presenter,
        policy: DesktopMessageAlertPolicy(),
        alertSettings: const MessageAlertSettings(newMsgNotice: false),
        isWeb: () => false,
        targetPlatform: () => TargetPlatform.android,
      );

      await manager.showNewMessageAlert(
        plan: _plan(),
        lifecycleState: AppLifecycleState.hidden,
      );

      expect(presenter.foregroundSoundCount, 0);
      expect(presenter.notifications, isEmpty);
    });

    test(
      'can hide message detail and disable background sound/vibration',
      () async {
        final presenter = _FakePresenter();
        final manager = AndroidMessageAlertManager(
          presenter: presenter,
          policy: DesktopMessageAlertPolicy(),
          alertSettings: const MessageAlertSettings(
            showMessageDetail: false,
            voiceOn: false,
            shockOn: false,
          ),
          isWeb: () => false,
          targetPlatform: () => TargetPlatform.android,
        );

        await manager.showNewMessageAlert(
          plan: _plan(body: 'private details'),
          lifecycleState: AppLifecycleState.hidden,
        );

        final notification = presenter.notifications.single;
        expect(notification.body, 'New message');
        expect(notification.playSound, isFalse);
        expect(notification.enableVibration, isFalse);
      },
    );

    test('disabled voice setting suppresses focused foreground tick', () async {
      final presenter = _FakePresenter();
      final manager = AndroidMessageAlertManager(
        presenter: presenter,
        policy: DesktopMessageAlertPolicy(),
        alertSettings: const MessageAlertSettings(voiceOn: false),
        isWeb: () => false,
        targetPlatform: () => TargetPlatform.android,
      );

      await manager.showNewMessageAlert(
        plan: _plan(),
        lifecycleState: AppLifecycleState.resumed,
      );

      expect(presenter.foregroundSoundCount, 0);
      expect(presenter.notifications, isEmpty);
    });
  });
}

MessageAlertPlan _plan({String body = 'hello', String payload = ''}) {
  return MessageAlertPlan(
    title: 'Alice',
    body: body,
    channelId: 'alice',
    channelType: WKChannelType.personal,
    payload: payload,
  );
}

class _FakePresenter implements AndroidMessageAlertPresenter {
  int foregroundSoundCount = 0;
  final List<AndroidMessageNotification> notifications =
      <AndroidMessageNotification>[];

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

  @override
  Future<void> dispose() async {}
}
