import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_push/notification/desktop_message_alert_policy.dart';
import 'package:wukong_im_app/wukong_push/notification/message_alert_plan.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('DesktopMessageAlertPolicy', () {
    late DateTime now;

    setUp(() {
      now = DateTime(2026, 5, 1, 12);
    });

    test('focused resumed app plays foreground sound without a card', () {
      final policy = DesktopMessageAlertPolicy(now: () => now);

      final decision = policy.resolve(
        plan: _plan('alice', 'Alice', 'hello'),
        lifecycleState: AppLifecycleState.resumed,
      );

      expect(decision.playForegroundSound, isTrue);
      expect(decision.playMessageSound, isFalse);
      expect(decision.notification, isNull);
    });

    test('hidden app shows a silent notification card and message sound', () {
      final policy = DesktopMessageAlertPolicy(now: () => now);

      final decision = policy.resolve(
        plan: _plan('alice', 'Alice', 'hello'),
        lifecycleState: AppLifecycleState.hidden,
      );

      expect(decision.playForegroundSound, isFalse);
      expect(decision.playMessageSound, isTrue);
      expect(decision.notification, isNotNull);
      expect(decision.notification!.identifier, 'wk-message-1-alice');
      expect(decision.notification!.title, 'Alice');
      expect(decision.notification!.body, 'hello');
    });

    test('coalesces rapid messages from the same conversation', () {
      final policy = DesktopMessageAlertPolicy(now: () => now);

      final first = policy.resolve(
        plan: _plan('alice', 'Alice', 'first'),
        lifecycleState: AppLifecycleState.hidden,
      );
      now = now.add(const Duration(milliseconds: 800));
      final second = policy.resolve(
        plan: _plan('alice', 'Alice', 'second'),
        lifecycleState: AppLifecycleState.hidden,
      );

      expect(first.notification!.body, 'first');
      expect(second.notification!.identifier, 'wk-message-1-alice');
      expect(second.notification!.body, '2 new messages');
    });

    test('does not coalesce different conversations', () {
      final policy = DesktopMessageAlertPolicy(now: () => now);

      final first = policy.resolve(
        plan: _plan('alice', 'Alice', 'hello'),
        lifecycleState: AppLifecycleState.hidden,
      );
      final second = policy.resolve(
        plan: _plan('bob', 'Bob', 'hello'),
        lifecycleState: AppLifecycleState.hidden,
      );

      expect(first.notification!.identifier, 'wk-message-1-alice');
      expect(second.notification!.identifier, 'wk-message-1-bob');
      expect(second.notification!.body, 'hello');
    });
  });
}

MessageAlertPlan _plan(String channelId, String title, String body) {
  return MessageAlertPlan(
    title: title,
    body: body,
    channelId: channelId,
    channelType: WKChannelType.personal,
  );
}
