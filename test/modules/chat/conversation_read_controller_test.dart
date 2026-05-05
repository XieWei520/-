import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/conversation_read_controller.dart';

void main() {
  test('markRead delegates to the provided callback', () async {
    var callCount = 0;
    List<String>? lastMessageIds;
    final controller = ConversationReadController(
      channelId: 'group_1',
      channelType: 2,
      currentUid: 'u_self',
      markConversationRead: (messageIds) async {
        callCount += 1;
        lastMessageIds = messageIds;
      },
    );
    controller.onVisibleMessageIdsChanged(const <String>['msg_1', 'msg_2']);

    await controller.markRead();

    expect(callCount, 1);
    expect(lastMessageIds, const <String>['msg_1', 'msg_2']);
  });

  test(
    'handleIncomingMessages ignores self messages and other channels',
    () async {
      var callCount = 0;
      final controller = ConversationReadController(
        channelId: 'group_1',
        channelType: 2,
        currentUid: 'u_self',
        markConversationRead: (_) async {
          callCount += 1;
        },
      );
      controller.onVisibleMessageIdsChanged(const <String>['msg_1']);

      await controller.handleIncomingMessages(const <ConversationReadEvent>[
        ConversationReadEvent(
          channelId: 'group_2',
          channelType: 2,
          fromUid: 'u_other',
        ),
        ConversationReadEvent(
          channelId: 'group_1',
          channelType: 2,
          fromUid: 'u_self',
        ),
      ]);

      expect(callCount, 0);
    },
  );

  test(
    'handleIncomingMessages marks matching foreign messages as read',
    () async {
      var callCount = 0;
      final controller = ConversationReadController(
        channelId: 'group_1',
        channelType: 2,
        currentUid: 'u_self',
        markConversationRead: (_) async {
          callCount += 1;
        },
      );
      controller.onVisibleMessageIdsChanged(const <String>['msg_1']);

      await controller.handleIncomingMessages(const <ConversationReadEvent>[
        ConversationReadEvent(
          channelId: 'group_1',
          channelType: 2,
          fromUid: 'u_other',
        ),
      ]);

      expect(callCount, 1);
    },
  );

  test('markRead skips the callback when there are no message ids', () async {
    var callCount = 0;
    final controller = ConversationReadController(
      channelId: 'group_1',
      channelType: 2,
      currentUid: 'u_self',
      markConversationRead: (_) async {
        callCount += 1;
      },
    );

    await controller.markRead();

    expect(callCount, 0);
  });

  test('visible signature debounce skips unchanged message ids', () async {
    var callCount = 0;
    List<String>? lastMessageIds;
    final controller = ConversationReadController(
      channelId: 'group_1',
      channelType: 2,
      currentUid: 'u_self',
      debounce: const Duration(milliseconds: 30),
      markConversationRead: (messageIds) async {
        callCount += 1;
        lastMessageIds = messageIds;
      },
    );

    controller.onVisibleMessageIdsChanged(const <String>['msg_1', 'msg_2']);
    controller.onVisibleMessageIdsChanged(const <String>['msg_1', 'msg_2']);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(callCount, 1);
    expect(lastMessageIds, const <String>['msg_1', 'msg_2']);

    controller.onVisibleMessageIdsChanged(const <String>['msg_1', 'msg_2']);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(callCount, 1);
  });

  test('queued visible updates collapse to the latest message ids', () async {
    final started = <List<String>>[];
    final completer = Completer<void>();
    final controller = ConversationReadController(
      channelId: 'group_1',
      channelType: 2,
      currentUid: 'u_self',
      debounce: const Duration(milliseconds: 10),
      markConversationRead: (messageIds) async {
        started.add(List<String>.from(messageIds));
        if (started.length == 1) {
          await completer.future;
        }
      },
    );

    controller.onVisibleMessageIdsChanged(const <String>['msg_1']);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(started, const <List<String>>[
      <String>['msg_1'],
    ]);

    controller.onVisibleMessageIdsChanged(const <String>['msg_1', 'msg_2']);
    controller.onVisibleMessageIdsChanged(const <String>[
      'msg_1',
      'msg_2',
      'msg_3',
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(started.length, 1);

    completer.complete();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(started, const <List<String>>[
      <String>['msg_1'],
      <String>['msg_1', 'msg_2', 'msg_3'],
    ]);
  });
}
