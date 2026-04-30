import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_push/push_service.dart';

void main() {
  test('push service dispatches browser notification click payloads', () async {
    final service = PushService(
      isPushSupported: () => false,
      initializeNotifications:
          ({void Function(String payload)? onNotificationTap}) async {},
    );

    final events = <Object>[];
    final subscription = service.messageEvents.listen(events.add);
    addTearDown(subscription.cancel);

    service.handleNotificationTapPayload(
      jsonEncode(<String, dynamic>{
        'payload': <String, dynamic>{
          'channel_id': 'team-1',
          'channel_type': 2,
          'message_id': 'm-1',
        },
        'title': 'Team',
        'body': 'New message',
      }),
    );

    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(1));
    final event = events.single as dynamic;
    expect(event.openedFromNotification, isTrue);
    expect(event.payload.channelId, 'team-1');
    expect(event.payload.channelType, 2);
    expect(event.title, 'Team');
    expect(event.body, 'New message');
  });

  test(
    'push service buffers browser notification clicks before listeners attach',
    () {
      final service = PushService(
        isPushSupported: () => false,
        initializeNotifications:
            ({void Function(String payload)? onNotificationTap}) async {},
      );

      service.handleNotificationTapPayload(
        jsonEncode(<String, dynamic>{
          'payload': <String, dynamic>{
            'channel_id': 'team-2',
            'channel_type': 2,
          },
        }),
      );

      final pending = service.consumePendingOpenedEvents();

      expect(pending, hasLength(1));
      expect(pending.single.payload.channelId, 'team-2');
    },
  );

  test('push service deduplicates pending notification click payloads', () {
    final service = PushService(
      isPushSupported: () => false,
      initializeNotifications:
          ({void Function(String payload)? onNotificationTap}) async {},
    );

    final payload = jsonEncode(<String, dynamic>{
      'payload': <String, dynamic>{
        'channel_id': 'team-duplicate',
        'channel_type': 2,
        'message_id': 'm-duplicate',
      },
      'title': 'Team duplicate',
    });

    service.handleNotificationTapPayload(payload);
    service.handleNotificationTapPayload(payload);

    final pending = service.consumePendingOpenedEvents();

    expect(pending, hasLength(1));
    expect(pending.single.payload.messageId, 'm-duplicate');
  });

  test('push service caps pending notification click buffer', () {
    final service = PushService(
      isPushSupported: () => false,
      initializeNotifications:
          ({void Function(String payload)? onNotificationTap}) async {},
    );

    for (var index = 0; index < 20; index += 1) {
      service.handleNotificationTapPayload(
        jsonEncode(<String, dynamic>{
          'payload': <String, dynamic>{
            'channel_id': 'team-$index',
            'channel_type': 2,
            'message_id': 'm-$index',
          },
          'title': 'Team $index',
        }),
      );
    }

    final pending = service.consumePendingOpenedEvents();

    expect(pending, hasLength(16));
    expect(pending.first.payload.messageId, 'm-4');
    expect(pending.last.payload.messageId, 'm-19');
  });
}
