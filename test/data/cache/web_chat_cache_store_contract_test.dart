import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/cache/web_chat_cache_store_memory.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

void main() {
  test('memory web chat cache stores latest messages per channel', () async {
    final store = MemoryWebChatCacheStore();
    final messages = [
      WKMsg()
        ..messageID = 'm1'
        ..channelID = 'c1'
        ..channelType = 1
        ..orderSeq = 1000
        ..contentType = 1,
    ];

    await store.upsertMessages(
      channelId: 'c1',
      channelType: 1,
      messages: messages,
    );

    final cached = await store.readMessages(
      channelId: 'c1',
      channelType: 1,
      limit: 20,
    );

    expect(cached.single.messageID, 'm1');
  });

  test(
    'memory web chat cache deduplicates and returns old-to-new pages',
    () async {
      final store = MemoryWebChatCacheStore(maxMessagesPerChannel: 3);

      await store.upsertMessages(
        channelId: 'c1',
        channelType: 1,
        messages: [
          _message('m1', 1000),
          _message('m2', 2000),
          _message('m2', 2200),
          _message('m3', 3000),
          _message('m4', 4000),
        ],
      );

      final latest = await store.readMessages(
        channelId: 'c1',
        channelType: 1,
        limit: 20,
      );
      final older = await store.readMessages(
        channelId: 'c1',
        channelType: 1,
        beforeOrderSeq: 4000,
        limit: 20,
      );

      expect(latest.map((message) => message.messageID), ['m2', 'm3', 'm4']);
      expect(latest.first.orderSeq, 2200);
      expect(older.map((message) => message.messageID), ['m2', 'm3']);
    },
  );
}

WKMsg _message(String messageId, int orderSeq) {
  return WKMsg()
    ..messageID = messageId
    ..channelID = 'c1'
    ..channelType = 1
    ..orderSeq = orderSeq
    ..contentType = 1;
}
