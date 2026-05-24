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

  test(
    'indexeddb web chat cache store anchors around page at first newer message',
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
          _message('m4', 4, 'u1', 'c1', 4000),
          _message('m5', 5, 'u1', 'c1', 5000),
        ],
      );

      final around = await store.readMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        aroundOrderSeq: 3000,
        limit: 3,
      );

      expect(around.map((message) => message.messageID), ['m2', 'm4', 'm5']);
    },
  );

  test(
    'indexeddb web chat cache store fills around page near partition boundaries',
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

      final beforeFirst = await store.readMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        aroundOrderSeq: 500,
        limit: 3,
      );
      final nearEnd = await store.readMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        aroundOrderSeq: 4000,
        limit: 3,
      );
      final afterLast = await store.readMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        aroundOrderSeq: 9000,
        limit: 3,
      );

      expect(beforeFirst.map((message) => message.messageID), [
        'm1',
        'm2',
        'm3',
      ]);
      expect(nearEnd.map((message) => message.messageID), ['m2', 'm3', 'm4']);
      expect(afterLast.map((message) => message.messageID), ['m2', 'm3', 'm4']);
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
    'indexeddb web chat cache store does not resurrect clean records deleted externally',
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
        ],
      );
      await store.readMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        limit: 20,
      );
      await adapter.applyChanges(
        upserts: const <Map<String, Object?>>[],
        deleteKeys: const <String>['u1|1|c1|message%3Am1'],
      );
      final persistedRecords = await adapter.readAll();

      final cached = await store.readMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        limit: 20,
      );

      expect(persistedRecords.map((record) => record['message_id']), ['m2']);
      expect(cached.map((message) => message.messageID), ['m2']);
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
    'indexeddb web chat cache store waits for in-flight partition read before writing',
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

      expect(adapter.readMessagesCalls, greaterThanOrEqualTo(1));
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

  test(
    'indexeddb web chat cache store reads partition without full hydration',
    () async {
      final adapter = QueryTrackingIndexedDbChatCacheAdapter();
      await adapter.applyChanges(
        upserts: [
          _record('u1', 'c1', 1, 'm1', 1, 1000),
          _record('u1', 'c1', 1, 'm2', 2, 2000),
          _record('u2', 'c1', 1, 'other', 1, 1000),
        ],
        deleteKeys: const <String>[],
      );
      final store = IndexedDbWebChatCacheStore(adapter: adapter);

      final cached = await store.readMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        limit: 1,
      );

      expect(cached.map((message) => message.messageID), ['m2']);
      expect(adapter.readMessagesCalls, 1);
      expect(adapter.readAllCalls, 0);
    },
  );

  test(
    'indexeddb web chat cache store trims partition without full scan',
    () async {
      final adapter = QueryTrackingIndexedDbChatCacheAdapter();
      final store = IndexedDbWebChatCacheStore(
        adapter: adapter,
        maxMessagesPerChannel: 2,
      );

      await store.upsertMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        messages: [
          _message('m1', 1, 'u1', 'c1', 1000),
          _message('m2', 2, 'u1', 'c1', 2000),
          _message('m3', 3, 'u1', 'c1', 3000),
        ],
      );

      final cached = await store.readMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: 1,
        limit: 20,
      );

      expect(cached.map((message) => message.messageID), ['m2', 'm3']);
      expect(adapter.deleteOldMessagesCalls, 1);
      expect(adapter.readAllCalls, 0);
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
  Future<List<Map<String, Object?>>> readMessages({
    required String uid,
    required String channelId,
    required int channelType,
    required int limit,
    int beforeOrderSeq = 0,
    int aroundOrderSeq = 0,
  }) async {
    var records = _snapshot();
    records =
        records
            .where(
              (record) =>
                  record['uid'] == uid &&
                  record['channel_id'] == channelId &&
                  record['channel_type'] == channelType,
            )
            .toList(growable: false)
          ..sort(_compareRecordOrder);
    final safeLimit = limit <= 0 ? 20 : limit;
    if (beforeOrderSeq > 0) {
      records = records
          .where((record) => (record['order_seq'] as int) < beforeOrderSeq)
          .toList(growable: false);
    } else if (aroundOrderSeq > 0) {
      if (records.length <= safeLimit) {
        return records;
      }
      final anchorIndex = records.indexWhere(
        (record) => (record['order_seq'] as int) >= aroundOrderSeq,
      );
      if (anchorIndex < 0) {
        return records.sublist(records.length - safeLimit);
      }
      final before = safeLimit ~/ 2;
      var start = anchorIndex - before;
      if (start < 0) {
        start = 0;
      }
      var end = start + safeLimit;
      if (end > records.length) {
        end = records.length;
        start = end - safeLimit;
        if (start < 0) {
          start = 0;
        }
      }
      return records.sublist(start, end);
    }
    if (records.length <= safeLimit) {
      return records;
    }
    return records.sublist(records.length - safeLimit);
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

  @override
  Future<void> deleteOldMessages({
    required String uid,
    required String channelId,
    required int channelType,
    required int keepLatest,
  }) async {
    final records =
        _snapshot()
            .where(
              (record) =>
                  record['uid'] == uid &&
                  record['channel_id'] == channelId &&
                  record['channel_type'] == channelType,
            )
            .toList(growable: false)
          ..sort(_compareRecordOrder);
    if (records.length <= keepLatest) {
      return;
    }
    final deleteKeys = records
        .take(records.length - keepLatest)
        .map((record) => record['cache_key']?.toString() ?? '')
        .where((key) => key.isNotEmpty)
        .toList(growable: false);
    await applyChanges(
      upserts: const <Map<String, Object?>>[],
      deleteKeys: deleteKeys,
    );
  }

  List<Map<String, Object?>> _snapshot() {
    return _records.map((record) => Map<String, Object?>.from(record)).toList();
  }

  static int _compareRecordOrder(
    Map<String, Object?> left,
    Map<String, Object?> right,
  ) {
    return (left['order_seq'] as int).compareTo(right['order_seq'] as int);
  }
}

class QueryTrackingIndexedDbChatCacheAdapter
    extends FakeIndexedDbChatCacheAdapter {
  int readAllCalls = 0;
  int readMessagesCalls = 0;
  int deleteOldMessagesCalls = 0;

  @override
  Future<List<Map<String, Object?>>> readAll() async {
    readAllCalls += 1;
    return super.readAll();
  }

  @override
  Future<List<Map<String, Object?>>> readMessages({
    required String uid,
    required String channelId,
    required int channelType,
    required int limit,
    int beforeOrderSeq = 0,
    int aroundOrderSeq = 0,
  }) async {
    readMessagesCalls += 1;
    return super.readMessages(
      uid: uid,
      channelId: channelId,
      channelType: channelType,
      limit: limit,
      beforeOrderSeq: beforeOrderSeq,
      aroundOrderSeq: aroundOrderSeq,
    );
  }

  @override
  Future<void> deleteOldMessages({
    required String uid,
    required String channelId,
    required int channelType,
    required int keepLatest,
  }) async {
    deleteOldMessagesCalls += 1;
    await super.deleteOldMessages(
      uid: uid,
      channelId: channelId,
      channelType: channelType,
      keepLatest: keepLatest,
    );
  }
}

class ThrowingIndexedDbChatCacheAdapter implements IndexedDbChatCacheAdapter {
  @override
  Future<List<Map<String, Object?>>> readAll() async {
    throw StateError('indexeddb unavailable');
  }

  @override
  Future<List<Map<String, Object?>>> readMessages({
    required String uid,
    required String channelId,
    required int channelType,
    required int limit,
    int beforeOrderSeq = 0,
    int aroundOrderSeq = 0,
  }) async {
    throw StateError('indexeddb unavailable');
  }

  @override
  Future<void> applyChanges({
    required List<Map<String, Object?>> upserts,
    required Iterable<String> deleteKeys,
  }) async {
    throw StateError('indexeddb unavailable');
  }

  @override
  Future<void> deleteOldMessages({
    required String uid,
    required String channelId,
    required int channelType,
    required int keepLatest,
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
  int readMessagesCalls = 0;

  @override
  Future<List<Map<String, Object?>>> readMessages({
    required String uid,
    required String channelId,
    required int channelType,
    required int limit,
    int beforeOrderSeq = 0,
    int aroundOrderSeq = 0,
  }) async {
    readMessagesCalls += 1;
    final snapshot = await super.readMessages(
      uid: uid,
      channelId: channelId,
      channelType: channelType,
      limit: limit,
      beforeOrderSeq: beforeOrderSeq,
      aroundOrderSeq: aroundOrderSeq,
    );
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
