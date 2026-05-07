import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/cache/web_chat_cache_store_memory.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

void main() {
  test(
    'memory web chat cache stores latest messages per user and channel',
    () async {
      final store = MemoryWebChatCacheStore();
      final messages = [_message('m1', 1, 'u1', 'c1', 1000)];

      await store.upsertMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        messages: messages,
      );

      final cached = await store.readMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        limit: 20,
      );

      expect(cached.single.messageID, 'm1');
    },
  );

  test('memory web chat cache isolates cached messages by user', () async {
    final store = MemoryWebChatCacheStore();

    await store.upsertMessages(
      uid: 'u1',
      channelId: 'c1',
      channelType: 1,
      messages: [_message('m1', 1, 'u1', 'c1', 1000)],
    );

    final otherUserCached = await store.readMessages(
      uid: 'u2',
      channelId: 'c1',
      channelType: 1,
      limit: 20,
    );

    expect(otherUserCached, isEmpty);
  });

  test('memory web chat cache clears only default uid partitions', () async {
    final store = MemoryWebChatCacheStore();

    await store.upsertMessages(
      channelId: 'c1',
      channelType: 1,
      messages: [_message('default', 1, '', 'c1', 1000)],
    );
    await store.upsertMessages(
      uid: 'u1',
      channelId: 'c1',
      channelType: 1,
      messages: [_message('u1-message', 2, 'u1', 'c1', 2000)],
    );

    await store.clearUser(uid: '');

    final defaultCached = await store.readMessages(
      channelId: 'c1',
      channelType: 1,
      limit: 20,
    );
    final u1Cached = await store.readMessages(
      uid: 'u1',
      channelId: 'c1',
      channelType: 1,
      limit: 20,
    );

    expect(defaultCached, isEmpty);
    expect(u1Cached.single.messageID, 'u1-message');
  });

  test(
    'memory web chat cache deduplicates and returns old-to-new pages per user',
    () async {
      final store = MemoryWebChatCacheStore(maxMessagesPerChannel: 3);

      await store.upsertMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        messages: [
          _message('m1', 1, 'u1', 'c1', 1000),
          _message('m2', 2, 'u1', 'c1', 2000),
          _message('m2', 2, 'u1', 'c1', 2200),
          _message('m3', 3, 'u1', 'c1', 3000),
          _message('m4', 4, 'u1', 'c1', 4000),
        ],
      );

      final latest = await store.readMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        limit: 20,
      );
      final older = await store.readMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        beforeOrderSeq: 4000,
        limit: 20,
      );
      final around = await store.readMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        aroundOrderSeq: 3000,
        limit: 3,
      );

      expect(latest.map((message) => message.messageID), ['m2', 'm3', 'm4']);
      expect(latest.first.orderSeq, 2200);
      expect(older.map((message) => message.messageID), ['m2', 'm3']);
      expect(around.map((message) => message.messageID), ['m2', 'm3', 'm4']);
    },
  );
}

WKMsg _message(
  String messageId,
  int messageSeq,
  String uid,
  String channelId,
  int orderSeq,
) {
  return WKMsg()
    ..messageID = messageId
    ..clientMsgNO = 'client-$messageId'
    ..messageSeq = messageSeq
    ..timestamp = 1700000000 + messageSeq
    ..fromUID = uid
    ..channelID = channelId
    ..channelType = 1
    ..orderSeq = orderSeq
    ..contentType = 1;
}
