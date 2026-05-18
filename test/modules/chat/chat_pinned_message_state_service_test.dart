import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/modules/chat/chat_pinned_message_resolver.dart';
import 'package:wukong_im_app/modules/chat/chat_pinned_message_state_service.dart';
import 'package:wukong_im_app/service/api/message_api.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test('fixed personal chats do not support pinned messages', () async {
    var syncCallCount = 0;
    final service = ChatPinnedMessageStateService(
      groupInfoLoader: (_) async => throw StateError('unused'),
    );

    final snapshot = await service.loadSnapshot(
      channelId: 'fileHelper',
      channelType: WKChannelType.personal,
      syncPinnedMessages:
          ({required channelId, required channelType, version = 0}) async {
            syncCallCount++;
            return _emptyPinnedSnapshot();
          },
      previousMessages: const <ResolvedPinnedMessage>[],
    );

    expect(snapshot.canPin, isFalse);
    expect(snapshot.canClearAll, isFalse);
    expect(snapshot.messages, isEmpty);
    expect(syncCallCount, 0);
  });

  test(
    'group owner can clear all and receives resolved pinned messages',
    () async {
      final service = ChatPinnedMessageStateService(
        groupInfoLoader: (_) async =>
            GroupInfo(groupNo: 'g_demo', role: 1, allowMemberPinnedMessage: 0),
      );

      final snapshot = await service.loadSnapshot(
        channelId: 'g_demo',
        channelType: WKChannelType.group,
        syncPinnedMessages:
            ({required channelId, required channelType, version = 0}) async {
              return PinnedMessageSyncSnapshot(
                pinnedMessages: <PinnedMessageEntry>[
                  _entry(messageId: 'mid-1', messageSeq: 8),
                ],
                messages: <WKSyncMsg>[
                  _syncMessage(
                    messageId: 'mid-1',
                    messageSeq: 8,
                    content: 'Pinned group message',
                  ),
                ],
              );
            },
        previousMessages: const <ResolvedPinnedMessage>[],
      );

      expect(snapshot.canPin, isTrue);
      expect(snapshot.canClearAll, isTrue);
      expect(snapshot.messages.single.previewText, 'Pinned group message');
    },
  );

  test('sync failure preserves previous pinned messages', () async {
    final previous = ResolvedPinnedMessage(
      entry: _entry(messageId: 'mid-prev', messageSeq: 5),
      message: WKMsg()..messageSeq = 5,
      previewText: 'Previous',
    );
    final channel = WKChannel('g_demo', WKChannelType.group)
      ..remoteExtraMap = <String, dynamic>{'allow_member_pinned_message': 1};
    final service = ChatPinnedMessageStateService(
      groupInfoLoader: (_) async => throw StateError('offline'),
    );

    final snapshot = await service.loadSnapshot(
      channelId: 'g_demo',
      channelType: WKChannelType.group,
      channel: channel,
      syncPinnedMessages:
          ({required channelId, required channelType, version = 0}) async {
            throw StateError('sync failed');
          },
      previousMessages: <ResolvedPinnedMessage>[previous],
    );

    expect(snapshot.canPin, isTrue);
    expect(snapshot.canClearAll, isFalse);
    expect(snapshot.messages, hasLength(1));
    expect(snapshot.messages.single, same(previous));
  });
}

PinnedMessageSyncSnapshot _emptyPinnedSnapshot() {
  return const PinnedMessageSyncSnapshot(
    pinnedMessages: <PinnedMessageEntry>[],
    messages: <WKSyncMsg>[],
  );
}

WKSyncMsg _syncMessage({
  required String messageId,
  required int messageSeq,
  required String content,
}) {
  return WKSyncMsg()
    ..messageID = messageId
    ..messageSeq = messageSeq
    ..channelID = 'g_demo'
    ..channelType = WKChannelType.group
    ..payload = <String, dynamic>{
      'type': WkMessageContentType.text,
      'content': content,
    };
}

PinnedMessageEntry _entry({
  required String messageId,
  required int messageSeq,
}) {
  return PinnedMessageEntry(
    messageId: messageId,
    messageSeq: messageSeq,
    channelId: 'g_demo',
    channelType: WKChannelType.group,
    isDeleted: 0,
    version: 1,
    createdAt: '2026-04-16T00:00:00Z',
    updatedAt: '2026-04-16T00:00:00Z',
  );
}
