import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/cache/indexed_db_web_chat_cache_store.dart';
import 'package:wukong_im_app/data/cache/web_chat_cache_store_factory.dart';
import 'package:wukong_im_app/data/cache/web_chat_cache_store_memory.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

void main() {
  test('web chat cache store factory returns memory off web', () {
    final store = WebChatCacheStoreFactory.create(isWeb: false);

    expect(store, isA<MemoryWebChatCacheStore>());
  });

  test('web chat cache store factory returns indexeddb on web', () {
    final store = WebChatCacheStoreFactory.create(
      isWeb: true,
      indexedDbStoreFactory: () =>
          IndexedDbWebChatCacheStore(adapter: FakeIndexedDbChatCacheAdapter()),
    );

    expect(store, isA<IndexedDbWebChatCacheStore>());
  });

  test(
    'indexeddb web chat cache store reads latest older and around pages',
    () async {
      final adapter = FakeIndexedDbChatCacheAdapter();
      final store = IndexedDbWebChatCacheStore(adapter: adapter);

      await store.upsertMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        messages: [
          _message('m1', 1, 'u1', 'c1', 1000),
          _message('m2', 2, 'u1', 'c1', 2000),
          _message('m3', 3, 'u1', 'c1', 3000),
          _message('m4', 4, 'u1', 'c1', 4000),
        ],
      );

      final latest = await store.readMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        limit: 2,
      );
      final older = await store.readMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        beforeOrderSeq: 4000,
        limit: 2,
      );
      final around = await store.readMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        aroundOrderSeq: 3000,
        limit: 3,
      );

      expect(latest.map((message) => message.messageID), ['m3', 'm4']);
      expect(older.map((message) => message.messageID), ['m2', 'm3']);
      expect(around.map((message) => message.messageID), ['m2', 'm3', 'm4']);
    },
  );

  test('indexeddb web chat cache store isolates channels and users', () async {
    final adapter = FakeIndexedDbChatCacheAdapter();
    final store = IndexedDbWebChatCacheStore(adapter: adapter);

    await store.upsertMessages(
      uid: 'u1',
      channelId: 'c1',
      channelType: 1,
      messages: [_message('m1', 1, 'u1', 'c1', 1000)],
    );
    await store.upsertMessages(
      uid: 'u2',
      channelId: 'c1',
      channelType: 1,
      messages: [_message('m2', 2, 'u2', 'c1', 2000)],
    );
    await store.upsertMessages(
      uid: 'u1',
      channelId: 'c2',
      channelType: 1,
      messages: [_message('m3', 3, 'u1', 'c2', 3000)],
    );

    final u1c1 = await store.readMessages(
      uid: 'u1',
      channelId: 'c1',
      channelType: 1,
      limit: 20,
    );
    final u2c1 = await store.readMessages(
      uid: 'u2',
      channelId: 'c1',
      channelType: 1,
      limit: 20,
    );
    final u1c2 = await store.readMessages(
      uid: 'u1',
      channelId: 'c2',
      channelType: 1,
      limit: 20,
    );

    expect(u1c1.single.messageID, 'm1');
    expect(u2c1.single.messageID, 'm2');
    expect(u1c2.single.messageID, 'm3');
  });

  test(
    'indexeddb web chat cache store clears only default uid partitions',
    () async {
      final adapter = FakeIndexedDbChatCacheAdapter();
      final store = IndexedDbWebChatCacheStore(adapter: adapter);

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
      final records = await adapter.readAll();

      expect(defaultCached, isEmpty);
      expect(u1Cached.single.messageID, 'u1-message');
      expect(records.map((record) => record['message_id']), ['u1-message']);
    },
  );

  test(
    'indexeddb web chat cache store falls back when adapter fails',
    () async {
      final store = IndexedDbWebChatCacheStore(
        adapter: ThrowingIndexedDbChatCacheAdapter(),
        errorReporter: _ignoreCacheError,
      );

      await store.upsertMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        messages: [_message('m1', 1, 'u1', 'c1', 1000)],
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

  test(
    'indexeddb web chat cache store preserves external adapter records',
    () async {
      final adapter = FakeIndexedDbChatCacheAdapter();
      final store = IndexedDbWebChatCacheStore(adapter: adapter);

      await store.upsertMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        messages: [_message('m1', 1, 'u1', 'c1', 1000)],
      );
      await adapter.applyChanges(
        upserts: [_record('u2', 'c9', 1, 'external', 9, 9000)],
        deleteKeys: const <String>[],
      );
      await store.upsertMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        messages: [_message('m2', 2, 'u1', 'c1', 2000)],
      );

      final records = await adapter.readAll();

      expect(
        records.map((record) => record['message_id']),
        contains('external'),
      );
      expect(records.map((record) => record['message_id']), contains('m2'));
    },
  );

  test(
    'indexeddb web chat cache store retries persist after a transient failure',
    () async {
      final adapter = FailsFirstApplyIndexedDbChatCacheAdapter();
      final store = IndexedDbWebChatCacheStore(
        adapter: adapter,
        errorReporter: _ignoreCacheError,
      );

      await store.upsertMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        messages: [_message('m1', 1, 'u1', 'c1', 1000)],
      );
      await store.upsertMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        messages: [_message('m2', 2, 'u1', 'c1', 2000)],
      );

      final records = await adapter.readAll();

      expect(adapter.applyAttempts, 2);
      expect(
        records.map((record) => record['message_id']),
        containsAll(['m1', 'm2']),
      );
    },
  );

  test(
    'indexeddb web chat cache store waits for in-flight hydration before writing',
    () async {
      final adapter = BlockingReadIndexedDbChatCacheAdapter();
      await adapter.applyChanges(
        upserts: [_record('u1', 'c1', 1, 'hydrated', 1, 1000)],
        deleteKeys: const <String>[],
      );
      final store = IndexedDbWebChatCacheStore(adapter: adapter);

      final readFuture = store.readMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        limit: 20,
      );
      await adapter.readStarted.future;

      final upsertFuture = store.upsertMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        messages: [_message('new', 2, 'u1', 'c1', 2000)],
      );
      await Future<void>.delayed(Duration.zero);
      adapter.completeRead();

      await Future.wait<Object?>([readFuture, upsertFuture]);
      final cached = await store.readMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        limit: 20,
      );

      expect(adapter.readAllCalls, 1);
      expect(cached.map((message) => message.messageID), ['hydrated', 'new']);
    },
  );

  test(
    'indexeddb web chat cache store hydrates messages written with default uid',
    () async {
      final adapter = FakeIndexedDbChatCacheAdapter();
      final writer = IndexedDbWebChatCacheStore(adapter: adapter);

      await writer.upsertMessages(
        channelId: 'c1',
        channelType: 1,
        messages: [_message('m1', 1, '', 'c1', 1000)],
      );

      final reloaded = IndexedDbWebChatCacheStore(adapter: adapter);
      final cached = await reloaded.readMessages(
        channelId: 'c1',
        channelType: 1,
        limit: 20,
      );

      expect(cached.single.messageID, 'm1');
    },
  );

  test(
    'indexeddb web chat cache store persists hydrated retention trimming',
    () async {
      final adapter = FakeIndexedDbChatCacheAdapter();
      await adapter.applyChanges(
        upserts: [
          _record('u1', 'c1', 1, 'old-1', 1, 1000),
          _record('u1', 'c1', 1, 'old-2', 2, 2000),
          _record('u1', 'c1', 1, 'new-1', 3, 3000),
          _record('u1', 'c1', 1, 'new-2', 4, 4000),
        ],
        deleteKeys: const <String>[],
      );
      final store = IndexedDbWebChatCacheStore(
        adapter: adapter,
        maxMessagesPerChannel: 2,
      );

      final cached = await store.readMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        limit: 20,
      );
      final records = await adapter.readAll();

      expect(cached.map((message) => message.messageID), ['new-1', 'new-2']);
      expect(records.map((record) => record['message_id']), ['new-1', 'new-2']);
    },
  );

  test(
    'indexeddb web chat cache store replaces client temporary message when server id arrives',
    () async {
      final adapter = FakeIndexedDbChatCacheAdapter();
      final store = IndexedDbWebChatCacheStore(adapter: adapter);

      await store.upsertMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        messages: [
          _message('', 0, 'u1', 'c1', 1000, clientMsgNo: 'client-temp-1'),
        ],
      );
      await store.upsertMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        messages: [
          _message(
            'server-1',
            10,
            'u1',
            'c1',
            1000,
            clientMsgNo: 'client-temp-1',
          ),
        ],
      );

      final cached = await store.readMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        limit: 20,
      );
      final records = await adapter.readAll();

      expect(cached, hasLength(1));
      expect(cached.single.messageID, 'server-1');
      expect(cached.single.clientMsgNO, 'client-temp-1');
      expect(records, hasLength(1));
      expect(records.single['message_id'], 'server-1');
    },
  );

  test(
    'indexeddb web chat cache store ignores server msg id for identity and cache key',
    () async {
      final adapter = FakeIndexedDbChatCacheAdapter();
      final store = IndexedDbWebChatCacheStore(adapter: adapter);

      await store.upsertMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        messages: [
          _message(
            '',
            0,
            'u1',
            'c1',
            1000,
            clientMsgNo: 'client-same',
            serverMsgId: 'server-a',
          ),
        ],
      );
      await store.upsertMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        messages: [
          _message('', 0, 'u1', 'c1', 2000, clientMsgNo: 'client-same'),
        ],
      );

      final cached = await store.readMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        limit: 20,
      );
      final records = await adapter.readAll();

      expect(cached, hasLength(1));
      expect(cached.single.clientMsgNO, 'client-same');
      expect(cached.single.serverMsgID, isEmpty);
      expect(records, hasLength(1));
      expect(records.single['cache_key'], 'u1|1|c1|client%3Aclient-same');
      expect(records.single['cache_key'], isNot(contains('server-a')));
      expect(records.single['server_msg_id'], isEmpty);
    },
  );
}

void _ignoreCacheError(String message, Object error, StackTrace stackTrace) {}

WKMsg _message(
  String messageId,
  int messageSeq,
  String uid,
  String channelId,
  int orderSeq, {
  String? clientMsgNo,
  String? serverMsgId,
}) {
  return WKMsg()
    ..messageID = messageId
    ..clientMsgNO = clientMsgNo ?? 'client-$messageId'
    ..serverMsgID = serverMsgId ?? ''
    ..messageSeq = messageSeq
    ..timestamp = 1700000000 + messageSeq
    ..fromUID = uid
    ..channelID = channelId
    ..channelType = 1
    ..orderSeq = orderSeq
    ..contentType = 1;
}

Map<String, Object?> _record(
  String uid,
  String channelId,
  int channelType,
  String messageId,
  int messageSeq,
  int orderSeq,
) {
  return <String, Object?>{
    'cache_key': '$uid|$channelType|$channelId|message:$messageId',
    'uid': uid,
    'channel_id': channelId,
    'channel_type': channelType,
    'message_id': messageId,
    'client_msg_no': 'client-$messageId',
    'message_seq': messageSeq,
    'order_seq': orderSeq,
    'timestamp': 1700000000 + messageSeq,
    'content_type': 1,
    'content': '',
    'is_deleted': 0,
    'status': 1,
  };
}

class FakeIndexedDbChatCacheAdapter implements IndexedDbChatCacheAdapter {
  final List<Map<String, Object?>> _records = <Map<String, Object?>>[];

  @override
  Future<List<Map<String, Object?>>> readAll() async {
    return _records.map((record) => Map<String, Object?>.from(record)).toList();
  }

  @override
  Future<void> applyChanges({
    required List<Map<String, Object?>> upserts,
    required Iterable<String> deleteKeys,
  }) async {
    final deleteKeySet = deleteKeys.toSet();
    _records.removeWhere(
      (record) => deleteKeySet.contains(record['cache_key']),
    );
    for (final upsert in upserts) {
      final cacheKey = upsert['cache_key']?.toString() ?? '';
      if (cacheKey.isEmpty) {
        continue;
      }
      _records.removeWhere((record) => record['cache_key'] == cacheKey);
      _records.add(Map<String, Object?>.from(upsert));
    }
  }
}

class ThrowingIndexedDbChatCacheAdapter implements IndexedDbChatCacheAdapter {
  @override
  Future<List<Map<String, Object?>>> readAll() async {
    throw StateError('indexeddb unavailable');
  }

  @override
  Future<void> applyChanges({
    required List<Map<String, Object?>> upserts,
    required Iterable<String> deleteKeys,
  }) async {
    throw StateError('indexeddb unavailable');
  }
}

class FailsFirstApplyIndexedDbChatCacheAdapter
    extends FakeIndexedDbChatCacheAdapter {
  int applyAttempts = 0;

  @override
  Future<void> applyChanges({
    required List<Map<String, Object?>> upserts,
    required Iterable<String> deleteKeys,
  }) {
    applyAttempts += 1;
    if (applyAttempts == 1) {
      throw StateError('transient indexeddb failure');
    }
    return super.applyChanges(upserts: upserts, deleteKeys: deleteKeys);
  }
}

class BlockingReadIndexedDbChatCacheAdapter
    extends FakeIndexedDbChatCacheAdapter {
  final Completer<void> readStarted = Completer<void>();
  final Completer<void> _completeRead = Completer<void>();
  int readAllCalls = 0;

  @override
  Future<List<Map<String, Object?>>> readAll() async {
    readAllCalls += 1;
    final snapshot = await super.readAll();
    if (!readStarted.isCompleted) {
      readStarted.complete();
    }
    await _completeRead.future;
    return snapshot;
  }

  void completeRead() {
    if (!_completeRead.isCompleted) {
      _completeRead.complete();
    }
  }
}
