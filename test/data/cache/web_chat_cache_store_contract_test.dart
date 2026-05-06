import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/cache/web_chat_cache_store_memory.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

void main() {
  test('memory cache keeps users isolated', () async {
    final store = MemoryWebChatCacheStore();

    await store.upsertMessages(
      uid: 'u1',
      channelId: 'c1',
      channelType: 1,
      messages: [_message('m1', 1000, channelId: 'c1')],
    );
    await store.upsertMessages(
      uid: 'u2',
      channelId: 'c1',
      channelType: 1,
      messages: [_message('m2', 2000, channelId: 'c1')],
    );

    final userOne = await store.readMessages(
      uid: 'u1',
      channelId: 'c1',
      channelType: 1,
      limit: 20,
    );
    final userTwo = await store.readMessages(
      uid: 'u2',
      channelId: 'c1',
      channelType: 1,
      limit: 20,
    );

    expect(userOne.map((message) => message.messageID), ['m1']);
    expect(userTwo.map((message) => message.messageID), ['m2']);
  });

  test('memory cache paginates latest, older, and around views', () async {
    final store = MemoryWebChatCacheStore(maxMessagesPerChannel: 10);

    await store.upsertMessages(
      uid: 'u1',
      channelId: 'c1',
      channelType: 1,
      messages: [
        _message('m1', 1000, channelId: 'c1'),
        _message('m2', 2000, channelId: 'c1'),
        _message('m3', 3000, channelId: 'c1'),
        _message('m4', 4000, channelId: 'c1'),
        _message('m5', 5000, channelId: 'c1'),
      ],
    );

    final latest = await store.readMessages(
      uid: 'u1',
      channelId: 'c1',
      channelType: 1,
      limit: 3,
    );
    final older = await store.readMessages(
      uid: 'u1',
      channelId: 'c1',
      channelType: 1,
      beforeOrderSeq: 5000,
      limit: 2,
    );
    final around = await store.readMessages(
      uid: 'u1',
      channelId: 'c1',
      channelType: 1,
      aroundOrderSeq: 3000,
      limit: 3,
    );

    expect(latest.map((message) => message.messageID), ['m3', 'm4', 'm5']);
    expect(older.map((message) => message.messageID), ['m3', 'm4']);
    expect(around.map((message) => message.messageID), ['m2', 'm3', 'm4']);
  });

  test('memory cache deduplicates by message identity priority', () async {
    final store = MemoryWebChatCacheStore();

    await store.upsertMessages(
      uid: 'u1',
      channelId: 'c1',
      channelType: 1,
      messages: [
        _message('m1', 1000, channelId: 'c1'),
        _message('m1', 2000, channelId: 'c1'),
      ],
    );

    final cached = await store.readMessages(
      uid: 'u1',
      channelId: 'c1',
      channelType: 1,
      limit: 20,
    );

    expect(cached, hasLength(1));
    expect(cached.single.orderSeq, 2000);
  });

  test('memory clearUser also removes legacy empty uid partitions', () async {
    final store = MemoryWebChatCacheStore();

    await store.upsertMessages(
      channelId: 'c1',
      channelType: 1,
      messages: [_message('legacy', 1000, channelId: 'c1')],
    );
    await store.upsertMessages(
      uid: 'u1',
      channelId: 'c1',
      channelType: 1,
      messages: [_message('current', 2000, channelId: 'c1')],
    );
    await store.upsertMessages(
      uid: 'u2',
      channelId: 'c1',
      channelType: 1,
      messages: [_message('other', 3000, channelId: 'c1')],
    );

    await store.clearUser(uid: 'u1');

    final legacy = await store.readMessages(
      channelId: 'c1',
      channelType: 1,
      limit: 20,
    );
    final current = await store.readMessages(
      uid: 'u1',
      channelId: 'c1',
      channelType: 1,
      limit: 20,
    );
    final other = await store.readMessages(
      uid: 'u2',
      channelId: 'c1',
      channelType: 1,
      limit: 20,
    );

    expect(legacy, isEmpty);
    expect(current, isEmpty);
    expect(other.map((message) => message.messageID), ['other']);
  });
}

WKMsg _message(String messageId, int orderSeq, {required String channelId}) {
  return WKMsg()
    ..messageID = messageId
    ..channelID = channelId
    ..channelType = 1
    ..orderSeq = orderSeq
    ..contentType = 1;
}
