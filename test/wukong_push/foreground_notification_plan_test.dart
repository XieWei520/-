import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_push/models/push_models.dart';
import 'package:wukong_im_app/wukong_push/notification/foreground_notification_plan.dart';
import 'package:wukong_im_app/wukong_push/notification/notification_helper.dart';

void main() {
  test(
    'buildForegroundNotificationPlan uses Android message channel defaults for foreground chat pushes',
    () {
      final plan = buildForegroundNotificationPlan(
        PushMessageEvent(
          payload: PushPayload(
            raw: <String, dynamic>{
              'channel_id': 'u_alice',
              'channel_type': 1,
              'message_id': 'msg-01',
            },
            channelId: 'u_alice',
            channelType: 1,
            messageId: 'msg-01',
            title: 'Alice',
            body: 'Hello from foreground',
          ),
          data: const <String, dynamic>{'channel_id': 'u_alice'},
          trigger: PushMessageTrigger.foreground,
          title: 'Alice',
          body: 'Hello from foreground',
        ),
      );

      expect(plan, isNotNull);
      expect(plan!.channelId, NotificationHelper.messageChannelId);
      expect(plan.channelName, NotificationHelper.messageChannelName);
      expect(plan.importance, Importance.defaultImportance);
      expect(plan.title, 'Alice');
      expect(plan.body, 'Hello from foreground');

      final payload = jsonDecode(plan.payload) as Map<String, dynamic>;
      expect(payload['title'], 'Alice');
      expect(payload['body'], 'Hello from foreground');
      expect(payload['payload'], isA<Map<String, dynamic>>());
    },
  );

  test(
    'buildForegroundNotificationPlan falls back to app name when only body is present',
    () {
      final plan = buildForegroundNotificationPlan(
        PushMessageEvent(
          payload: PushPayload(
            raw: const <String, dynamic>{'channel_id': 'u_body_only'},
            channelId: 'u_body_only',
            channelType: 1,
            body: 'Body only',
          ),
          data: const <String, dynamic>{'channel_id': 'u_body_only'},
          trigger: PushMessageTrigger.foreground,
          body: 'Body only',
        ),
      );

      expect(plan, isNotNull);
      expect(plan!.title, 'WuKongIM');
      expect(plan.body, 'Body only');
    },
  );

  test(
    'buildForegroundNotificationPlan returns null when both title and body are empty',
    () {
      final plan = buildForegroundNotificationPlan(
        PushMessageEvent(
          payload: PushPayload(raw: const <String, dynamic>{}),
          data: const <String, dynamic>{},
          trigger: PushMessageTrigger.foreground,
        ),
      );

      expect(plan, isNull);
    },
  );

  test('buildForegroundNotificationPlan compacts very long display text', () {
    final longTitle = 'T' * 120;
    final longBody = 'B' * 320;

    final plan = buildForegroundNotificationPlan(
      PushMessageEvent(
        payload: PushPayload(
          raw: const <String, dynamic>{'channel_id': 'u_long'},
          channelId: 'u_long',
          channelType: 1,
          title: longTitle,
          body: longBody,
        ),
        data: const <String, dynamic>{'channel_id': 'u_long'},
        trigger: PushMessageTrigger.foreground,
      ),
    );

    expect(plan, isNotNull);
    expect(plan!.title, hasLength(80));
    expect(plan.body, hasLength(240));
    expect(plan.title.endsWith('...'), isTrue);
    expect(plan.body.endsWith('...'), isTrue);

    final payload = jsonDecode(plan.payload) as Map<String, dynamic>;
    expect(payload['title'], plan.title);
    expect(payload['body'], plan.body);
  });
}
