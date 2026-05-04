import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/app/navigation/app_push_route_bridge.dart';
import 'package:wukong_im_app/app/navigation/app_route_location.dart';
import 'package:wukong_im_app/wukong_push/models/push_models.dart';

void main() {
  group('AppChatRouteIntent', () {
    test('builds chat location from route fields', () {
      const intent = AppChatRouteIntent(
        channelId: 'team/alpha one',
        channelType: 2,
        channelName: 'Alice & Bob',
      );

      expect(
        intent.location,
        AppRouteLocation.chat(
          channelId: 'team/alpha one',
          channelType: 2,
          channelName: 'Alice & Bob',
        ),
      );
    });
  });

  group('AppPushRouteBridge', () {
    test('actionable opened push opens chat once', () async {
      final controller = StreamController<PushMessageEvent>();
      final intents = <AppChatRouteIntent>[];
      final bridge = AppPushRouteBridge(
        messageEvents: controller.stream,
        isLoggedIn: () => true,
        isRestoringSession: () => false,
        onOpenChat: intents.add,
      );
      bridge.start();

      controller.add(
        PushMessageEvent(
          payload: PushPayload.fromMap({
            'channel_id': 'c-100',
            'channel_type': 2,
          }),
          data: const <String, dynamic>{},
          trigger: PushMessageTrigger.tap,
          body: 'Body fallback name',
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(intents, hasLength(1));
      expect(intents.single.channelId, 'c-100');
      expect(intents.single.channelType, 2);
      expect(intents.single.channelName, 'Body fallback name');

      await bridge.dispose();
      await controller.close();
    });

    test('non-opened events are ignored', () async {
      final controller = StreamController<PushMessageEvent>();
      final intents = <AppChatRouteIntent>[];
      final bridge = AppPushRouteBridge(
        messageEvents: controller.stream,
        isLoggedIn: () => true,
        isRestoringSession: () => false,
        onOpenChat: intents.add,
      );
      bridge.start();

      controller.add(
        PushMessageEvent(
          payload: PushPayload.fromMap({
            'channel_id': 'c-200',
            'channel_type': 1,
          }),
          data: const <String, dynamic>{},
          trigger: PushMessageTrigger.foreground,
          title: 'Foreground title',
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(intents, isEmpty);

      await bridge.dispose();
      await controller.close();
    });

    test('missing conversation target is ignored', () async {
      final controller = StreamController<PushMessageEvent>();
      final intents = <AppChatRouteIntent>[];
      final bridge = AppPushRouteBridge(
        messageEvents: controller.stream,
        isLoggedIn: () => true,
        isRestoringSession: () => false,
        onOpenChat: intents.add,
      );
      bridge.start();

      controller.add(
        PushMessageEvent(
          payload: PushPayload.fromMap({'message_id': 'm-1'}),
          data: const <String, dynamic>{},
          trigger: PushMessageTrigger.initial,
          title: 'No target',
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(intents, isEmpty);

      await bridge.dispose();
      await controller.close();
    });

    test('disposed bridge stops future delivery', () async {
      final controller = StreamController<PushMessageEvent>();
      final intents = <AppChatRouteIntent>[];
      final bridge = AppPushRouteBridge(
        messageEvents: controller.stream,
        isLoggedIn: () => true,
        isRestoringSession: () => false,
        onOpenChat: intents.add,
      );
      bridge.start();

      await bridge.dispose();
      controller.add(
        PushMessageEvent(
          payload: PushPayload.fromMap({
            'channel_id': 'c-300',
            'channel_type': 1,
          }),
          data: const <String, dynamic>{},
          trigger: PushMessageTrigger.tap,
          title: 'Should not deliver',
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(intents, isEmpty);
      await controller.close();
    });

    test(
      'replays opened events that existed before start subscription',
      () async {
        final controller = StreamController<PushMessageEvent>();
        final intents = <AppChatRouteIntent>[];
        var replayCalls = 0;
        final bridge = AppPushRouteBridge(
          messageEvents: controller.stream,
          isLoggedIn: () => true,
          isRestoringSession: () => false,
          onOpenChat: intents.add,
        );

        bridge.start(
          consumePendingOpenedEvents: () {
            replayCalls += 1;
            return <PushMessageEvent>[
              PushMessageEvent(
                payload: PushPayload.fromMap({
                  'channel_id': 'c-replay',
                  'channel_type': 1,
                }),
                data: const <String, dynamic>{},
                trigger: PushMessageTrigger.initial,
                title: 'Replay',
              ),
            ];
          },
        );

        await Future<void>.delayed(Duration.zero);

        expect(replayCalls, 1);
        expect(intents, hasLength(1));
        expect(intents.single.channelId, 'c-replay');

        await bridge.dispose();
        await controller.close();
      },
    );

    test('deduplicates replayed and streamed opened push events', () async {
      final controller = StreamController<PushMessageEvent>();
      final intents = <AppChatRouteIntent>[];
      final duplicateEvent = PushMessageEvent(
        payload: PushPayload.fromMap({
          'channel_id': 'c-duplicate',
          'channel_type': 1,
          'message_id': 'm-duplicate',
        }),
        data: const <String, dynamic>{},
        trigger: PushMessageTrigger.tap,
        title: 'Duplicate',
      );
      final bridge = AppPushRouteBridge(
        messageEvents: controller.stream,
        isLoggedIn: () => true,
        isRestoringSession: () => false,
        onOpenChat: intents.add,
      );

      bridge.start(
        consumePendingOpenedEvents: () => <PushMessageEvent>[duplicateEvent],
      );
      controller.add(duplicateEvent);

      await Future<void>.delayed(Duration.zero);

      expect(intents, hasLength(1));
      expect(intents.single.channelId, 'c-duplicate');

      await bridge.dispose();
      await controller.close();
    });

    test(
      'evicts old opened event keys after the recent window is full',
      () async {
        final controller = StreamController<PushMessageEvent>();
        final intents = <AppChatRouteIntent>[];
        final bridge = AppPushRouteBridge(
          messageEvents: controller.stream,
          isLoggedIn: () => true,
          isRestoringSession: () => false,
          onOpenChat: intents.add,
          maxOpenedEventKeys: 3,
        );
        bridge.start();

        for (final messageId in <String>['m-0', 'm-1', 'm-2', 'm-3']) {
          controller.add(_openedEvent(messageId: messageId));
        }
        await Future<void>.delayed(Duration.zero);

        controller.add(_openedEvent(messageId: 'm-0'));
        controller.add(_openedEvent(messageId: 'm-3'));
        await Future<void>.delayed(Duration.zero);

        expect(intents.map((intent) => intent.channelId), <String>[
          'c-m-0',
          'c-m-1',
          'c-m-2',
          'c-m-3',
          'c-m-0',
        ]);

        await bridge.dispose();
        await controller.close();
      },
    );

    test('caps pending opened intents during session restore', () async {
      final controller = StreamController<PushMessageEvent>();
      final intents = <AppChatRouteIntent>[];
      var isLoggedIn = false;
      var isRestoring = true;
      final bridge = AppPushRouteBridge(
        messageEvents: controller.stream,
        isLoggedIn: () => isLoggedIn,
        isRestoringSession: () => isRestoring,
        onOpenChat: intents.add,
        maxPendingOpenedIntents: 3,
      );
      bridge.start();

      for (final messageId in <String>['m-0', 'm-1', 'm-2', 'm-3']) {
        controller.add(_openedEvent(messageId: messageId));
      }
      await Future<void>.delayed(Duration.zero);

      isLoggedIn = true;
      isRestoring = false;
      bridge.flushPending();

      expect(intents.map((intent) => intent.channelId), <String>[
        'c-m-1',
        'c-m-2',
        'c-m-3',
      ]);

      await bridge.dispose();
      await controller.close();
    });

    test(
      'buffers actionable intents during restore and flushes after login',
      () async {
        final controller = StreamController<PushMessageEvent>();
        final intents = <AppChatRouteIntent>[];
        var isLoggedIn = false;
        var isRestoring = true;
        final bridge = AppPushRouteBridge(
          messageEvents: controller.stream,
          isLoggedIn: () => isLoggedIn,
          isRestoringSession: () => isRestoring,
          onOpenChat: intents.add,
        );
        bridge.start();

        controller.add(
          PushMessageEvent(
            payload: PushPayload.fromMap({
              'channel_id': 'c-buffered',
              'channel_type': 2,
            }),
            data: const <String, dynamic>{},
            trigger: PushMessageTrigger.tap,
            title: 'Buffered',
          ),
        );

        await Future<void>.delayed(Duration.zero);
        bridge.flushPending();

        expect(intents, isEmpty);

        isLoggedIn = true;
        isRestoring = false;
        bridge.flushPending();
        bridge.flushPending();

        expect(intents, hasLength(1));
        expect(intents.single.channelId, 'c-buffered');

        await bridge.dispose();
        await controller.close();
      },
    );

    test('start does not replay twice and avoids duplicate delivery', () async {
      final controller = StreamController<PushMessageEvent>();
      final intents = <AppChatRouteIntent>[];
      var replayCalls = 0;
      final bridge = AppPushRouteBridge(
        messageEvents: controller.stream,
        isLoggedIn: () => true,
        isRestoringSession: () => false,
        onOpenChat: intents.add,
      );

      List<PushMessageEvent> replay() {
        replayCalls += 1;
        return <PushMessageEvent>[
          PushMessageEvent(
            payload: PushPayload.fromMap({
              'channel_id': 'c-once',
              'channel_type': 1,
            }),
            data: const <String, dynamic>{},
            trigger: PushMessageTrigger.initial,
            title: 'Only once',
          ),
        ];
      }

      bridge.start(consumePendingOpenedEvents: replay);
      bridge.start(consumePendingOpenedEvents: replay);

      await Future<void>.delayed(Duration.zero);

      expect(replayCalls, 1);
      expect(intents, hasLength(1));
      expect(intents.single.channelId, 'c-once');

      await bridge.dispose();
      await controller.close();
    });
  });
}

PushMessageEvent _openedEvent({required String messageId}) {
  return PushMessageEvent(
    payload: PushPayload.fromMap({
      'channel_id': 'c-$messageId',
      'channel_type': 1,
      'message_id': messageId,
    }),
    data: const <String, dynamic>{},
    trigger: PushMessageTrigger.tap,
    title: 'Title $messageId',
  );
}
