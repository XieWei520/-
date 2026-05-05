import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/cache/indexed_db_web_chat_cache_store_adapter.dart';
import 'package:wukong_im_app/data/cache/indexed_db_web_chat_cache_store.dart';
import 'package:wukong_im_app/data/cache/web_chat_cache_store_factory.dart';
import 'package:wukong_im_app/data/cache/web_chat_cache_store_memory.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

void main() {
  test('indexed db store persists raw maps and keeps latest records', () async {
    final adapter = FakeIndexedDbAdapter();
    final store = IndexedDbWebChatCacheStore(adapter: adapter);

    await store.upsertMessages(
      uid: 'u1',
      channelId: 'c1',
      channelType: 1,
      messages: [
        _message('m1', 1000, channelId: 'c1'),
        _message('m2', 2000, channelId: 'c1'),
      ],
    );

    final cached = await store.readMessages(
      uid: 'u1',
      channelId: 'c1',
      channelType: 1,
      limit: 20,
    );

    expect(adapter.lastWritten.first['messageID'], 'm1');
    expect(cached.map((message) => message.messageID), ['m1', 'm2']);
  });

  test(
    'indexed db store deduplicates and trims to 2000 records per partition',
    () async {
      final adapter = FakeIndexedDbAdapter();
      final store = IndexedDbWebChatCacheStore(adapter: adapter);

      await store.upsertMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        messages: List.generate(
          2100,
          (index) => _message('m$index', index + 1, channelId: 'c1'),
        ),
      );

      final cached = await store.readMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        limit: 3000,
      );

      expect(cached, hasLength(2000));
      expect(cached.first.messageID, 'm100');
      expect(cached.last.messageID, 'm2099');
    },
  );

  test('indexed db store falls back to memory when adapter throws', () async {
    final store = IndexedDbWebChatCacheStore(
      adapter: ThrowingIndexedDbAdapter(),
    );

    await store.upsertMessages(
      uid: 'u1',
      channelId: 'c1',
      channelType: 1,
      messages: [_message('m1', 1000, channelId: 'c1')],
    );

    final cached = await store.readMessages(
      uid: 'u1',
      channelId: 'c1',
      channelType: 1,
      limit: 20,
    );

    expect(cached.single.messageID, 'm1');
  });

  test(
    'fallback preserves loaded indexed db records after write failure',
    () async {
      final adapter = FakeIndexedDbAdapter(
        initialRecords: [_record('existing', 1000, uid: 'u1', channelId: 'c1')],
      );
      final store = IndexedDbWebChatCacheStore(adapter: adapter);

      final existing = await store.readMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        limit: 20,
      );
      expect(existing.map((message) => message.messageID), ['existing']);

      adapter.throwOnWrite = true;
      await store.upsertMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        messages: [_message('new', 2000, channelId: 'c1')],
      );

      final cached = await store.readMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        limit: 20,
      );

      expect(cached.map((message) => message.messageID), ['existing', 'new']);
    },
  );

  test(
    'indexed db clearUser also removes legacy empty uid partitions',
    () async {
      final adapter = FakeIndexedDbAdapter(
        initialRecords: [
          _record('legacy', 1000, uid: '', channelId: 'c1'),
          _record('current', 2000, uid: 'u1', channelId: 'c1'),
          _record('other', 3000, uid: 'u2', channelId: 'c1'),
        ],
      );
      final store = IndexedDbWebChatCacheStore(adapter: adapter);

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
    },
  );

  test('factory returns memory off web and indexed db on web', () {
    final offWeb = WebChatCacheStoreFactory.create(isWeb: false);
    expect(offWeb, isA<MemoryWebChatCacheStore>());

    final onWeb = WebChatCacheStoreFactory.create(
      isWeb: true,
      indexedDbStoreFactory: () =>
          IndexedDbWebChatCacheStore(adapter: FakeIndexedDbAdapter()),
    );
    expect(onWeb, isA<IndexedDbWebChatCacheStore>());
  });
}

class FakeIndexedDbAdapter implements IndexedDbWebChatCacheAdapter {
  FakeIndexedDbAdapter({List<Map<String, Object?>> initialRecords = const []})
    : _records = initialRecords
          .map((record) => Map<String, Object?>.from(record))
          .toList(growable: false);

  List<Map<String, Object?>> _records;
  bool throwOnWrite = false;

  @override
  Future<List<Map<String, Object?>>> readAll() async {
    return _records
        .map((record) => Map<String, Object?>.from(record))
        .toList(growable: false);
  }

  @override
  Future<void> writeAll(List<Map<String, Object?>> records) async {
    if (throwOnWrite) {
      throw StateError('boom');
    }
    _records = records
        .map((record) => Map<String, Object?>.from(record))
        .toList(growable: false);
  }

  List<Map<String, Object?>> get lastWritten => _records;
}

class ThrowingIndexedDbAdapter implements IndexedDbWebChatCacheAdapter {
  @override
  Future<List<Map<String, Object?>>> readAll() {
    throw StateError('boom');
  }

  @override
  Future<void> writeAll(List<Map<String, Object?>> records) {
    throw StateError('boom');
  }
}

WKMsg _message(String messageId, int orderSeq, {required String channelId}) {
  return WKMsg()
    ..messageID = messageId
    ..channelID = channelId
    ..channelType = 1
    ..orderSeq = orderSeq
    ..contentType = 1;
}

Map<String, Object?> _record(
  String messageId,
  int orderSeq, {
  required String uid,
  required String channelId,
}) {
  return <String, Object?>{
    'uid': uid,
    'channelId': channelId,
    'channelType': 1,
    'messageID': messageId,
    'clientMsgNO': '',
    'messageSeq': 0,
    'orderSeq': orderSeq,
    'contentType': 1,
    'content': '',
    'status': 0,
    'voiceStatus': 0,
    'isDeleted': 0,
    'searchableWord': '',
    'expireTime': 0,
    'expireTimestamp': 0,
    'viewed': 0,
    'viewedAt': 0,
    'topicID': '',
    'fromUID': '',
    'timestamp': 0,
  };
}
