import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_pinned_message_resolver.dart';
import 'package:wukong_im_app/service/api/message_api.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test('resolvePinnedMessages filters deleted and missing messages', () {
    final active = _syncMessage(
      messageId: 'mid-active',
      messageSeq: 7,
      payload: <String, dynamic>{
        'type': WkMessageContentType.text,
        'content': 'Pinned body',
      },
    );

    final resolved = resolvePinnedMessages(
      PinnedMessageSyncSnapshot(
        pinnedMessages: <PinnedMessageEntry>[
          _entry(messageId: 'mid-active', messageSeq: 7, version: 3),
          _entry(
            messageId: 'mid-deleted',
            messageSeq: 8,
            version: 4,
            isDeleted: 1,
          ),
          _entry(messageId: 'mid-missing', messageSeq: 9, version: 5),
        ],
        messages: <WKSyncMsg>[active],
      ),
    );

    expect(resolved, hasLength(1));
    expect(resolved.single.entry.messageId, 'mid-active');
    expect(resolved.single.previewText, 'Pinned body');
  });

  test('resolvePinnedMessages sorts by version then message sequence desc', () {
    final first = _syncMessage(messageId: 'mid-1', messageSeq: 1);
    final second = _syncMessage(messageId: 'mid-2', messageSeq: 2);
    final newestVersion = _syncMessage(messageId: 'mid-3', messageSeq: 3);

    final resolved = resolvePinnedMessages(
      PinnedMessageSyncSnapshot(
        pinnedMessages: <PinnedMessageEntry>[
          _entry(messageId: 'mid-1', messageSeq: 1, version: 5),
          _entry(messageId: 'mid-2', messageSeq: 2, version: 5),
          _entry(messageId: 'mid-3', messageSeq: 3, version: 8),
        ],
        messages: <WKSyncMsg>[first, second, newestVersion],
      ),
    );

    expect(resolved.map((item) => item.entry.messageId), <String>[
      'mid-3',
      'mid-2',
      'mid-1',
    ]);
  });

  test('resolvePinnedMessages preserves structured empty payload preview', () {
    final syncMessage = _syncMessage(
      messageId: 'mid-preview',
      messageSeq: 11,
      payload: const <String, dynamic>{},
    );

    final resolved = resolvePinnedMessages(
      PinnedMessageSyncSnapshot(
        pinnedMessages: <PinnedMessageEntry>[
          _entry(messageId: 'mid-preview', messageSeq: 11),
        ],
        messages: <WKSyncMsg>[syncMessage],
      ),
    );

    expect(resolved.single.previewText, '{}');
  });

  test('canManagePinnedMessages only allows group owner or admin roles', () {
    expect(canManagePinnedMessages(1), isTrue);
    expect(canManagePinnedMessages(2), isTrue);
    expect(canManagePinnedMessages(0), isFalse);
    expect(canManagePinnedMessages(null), isFalse);
  });
}

WKSyncMsg _syncMessage({
  required String messageId,
  required int messageSeq,
  Map<String, dynamic>? payload,
}) {
  return WKSyncMsg()
    ..messageID = messageId
    ..messageSeq = messageSeq
    ..channelID = 'u_target'
    ..channelType = WKChannelType.personal
    ..fromUID = 'u_sender'
    ..payload =
        payload ??
        <String, dynamic>{
          'type': WkMessageContentType.text,
          'content': 'message $messageSeq',
        };
}

PinnedMessageEntry _entry({
  required String messageId,
  required int messageSeq,
  int version = 1,
  int isDeleted = 0,
}) {
  return PinnedMessageEntry(
    messageId: messageId,
    messageSeq: messageSeq,
    channelId: 'u_target',
    channelType: WKChannelType.personal,
    isDeleted: isDeleted,
    version: version,
    createdAt: '2026-04-16T00:00:00Z',
    updatedAt: '2026-04-16T00:00:00Z',
  );
}
