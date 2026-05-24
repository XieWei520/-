import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'indexed_db_chat_cache_paging.dart';
import 'indexed_db_web_chat_cache_store_adapter_base.dart';

const String _indexedDbName = 'wukong_chat_cache_v1';
const String _messagesStoreName = 'messages';
const int _indexedDbVersion = 2;
const int _maxIndexedDbOrderSeq = 9007199254740991;

IndexedDbChatCacheAdapter createIndexedDbChatCacheAdapter() {
  return WebIndexedDbChatCacheAdapter();
}

class WebIndexedDbChatCacheAdapter implements IndexedDbChatCacheAdapter {
  WebIndexedDbChatCacheAdapter();

  @override
  Future<List<Map<String, Object?>>> readAll() async {
    final database = await _openDatabase();
    try {
      final transaction = database.transaction(
        _toJsStringArray([_messagesStoreName]),
        'readonly',
      );
      final completed = _awaitTransactionComplete(transaction);
      final store = transaction.objectStore(_messagesStoreName);
      final result = await _awaitRequestResult(store.getAll());
      await completed;
      return _decodeRecords(result);
    } finally {
      database.close();
    }
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
    final pageLimit = _safeLimit(limit);
    final database = await _openDatabase();
    try {
      final transaction = database.transaction(
        _toJsStringArray([_messagesStoreName]),
        'readonly',
      );
      final completed = _awaitTransactionComplete(transaction);
      final index = transaction
          .objectStore(_messagesStoreName)
          .index('byUserChannelOrderSeq');
      late final List<Map<String, Object?>> records;
      if (aroundOrderSeq > 0) {
        records = await _readAround(
          index: index,
          uid: uid,
          channelId: channelId,
          channelType: channelType,
          limit: pageLimit,
          aroundOrderSeq: aroundOrderSeq,
        );
      } else {
        final upperOrderSeq = beforeOrderSeq > 0 ? beforeOrderSeq : null;
        records = await _readCursorPage(
          index: index,
          range: _partitionRange(
            uid: uid,
            channelId: channelId,
            channelType: channelType,
            upperOrderSeq: upperOrderSeq,
            upperOpen: beforeOrderSeq > 0,
          ),
          limit: pageLimit,
          direction: 'prev',
        );
        records.sort(_compareRecords);
      }
      await completed;
      return records;
    } finally {
      database.close();
    }
  }

  @override
  Future<void> applyChanges({
    required List<Map<String, Object?>> upserts,
    required Iterable<String> deleteKeys,
  }) async {
    final database = await _openDatabase();
    try {
      final transaction = database.transaction(
        _toJsStringArray([_messagesStoreName]),
        'readwrite',
      );
      final completed = _awaitTransactionComplete(transaction);
      final store = transaction.objectStore(_messagesStoreName);
      for (final key in deleteKeys) {
        final normalizedKey = key.trim();
        if (normalizedKey.isEmpty) {
          continue;
        }
        await _awaitRequest(store.delete(normalizedKey.toJS));
      }
      for (final record in upserts) {
        await _awaitRequest(store.put(_toJsObject(record)));
      }
      await completed;
    } finally {
      database.close();
    }
  }

  @override
  Future<void> deleteOldMessages({
    required String uid,
    required String channelId,
    required int channelType,
    required int keepLatest,
  }) async {
    final safeKeepLatest = keepLatest < 0 ? 0 : keepLatest;
    final database = await _openDatabase();
    try {
      final transaction = database.transaction(
        _toJsStringArray([_messagesStoreName]),
        'readwrite',
      );
      final completed = _awaitTransactionComplete(transaction);
      final index = transaction
          .objectStore(_messagesStoreName)
          .index('byUserChannelOrderSeq');
      final countResult = await _awaitRequestResult(
        index.count(
          _partitionRange(
            uid: uid,
            channelId: channelId,
            channelType: channelType,
          ),
        ),
      );
      final count = _toInt(countResult);
      final deleteCount = count - safeKeepLatest;
      if (deleteCount > 0) {
        await _deleteCursorPage(
          index: index,
          range: _partitionRange(
            uid: uid,
            channelId: channelId,
            channelType: channelType,
          ),
          limit: deleteCount,
        );
      }
      await completed;
    } finally {
      database.close();
    }
  }

  Future<web.IDBDatabase> _openDatabase() async {
    if (!globalContext.has('indexedDB')) {
      throw StateError('IndexedDB is unavailable');
    }

    final request = web.window.indexedDB.open(
      _indexedDbName,
      _indexedDbVersion,
    );
    final completer = Completer<web.IDBDatabase>();

    request.onupgradeneeded = ((web.Event event) {
      try {
        final database = request.result as web.IDBDatabase;
        final store = database.objectStoreNames.contains(_messagesStoreName)
            ? request.transaction!.objectStore(_messagesStoreName)
            : database.createObjectStore(
                _messagesStoreName,
                web.IDBObjectStoreParameters(keyPath: 'cache_key'.toJS),
              );
        _ensureIndexes(store);
      } catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      }
    }).toJS;

    request.onsuccess = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.complete(request.result as web.IDBDatabase);
      }
    }).toJS;

    request.onerror = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
          request.error ?? StateError('IndexedDB open failed'),
        );
      }
    }).toJS;

    request.onblocked = ((web.Event event) {
      web.console.warn('IndexedDB open blocked for $_indexedDbName'.toJS);
    }).toJS;

    return completer.future;
  }

  void _ensureIndexes(web.IDBObjectStore store) {
    if (!store.indexNames.contains('byUserChannelOrderSeq')) {
      store.createIndex(
        'byUserChannelOrderSeq',
        _toJsStringArray(['uid', 'channel_type', 'channel_id', 'order_seq']),
      );
    }
    if (!store.indexNames.contains('byUserChannelMessageSeq')) {
      store.createIndex(
        'byUserChannelMessageSeq',
        _toJsStringArray(['uid', 'channel_type', 'channel_id', 'message_seq']),
      );
    }
    if (!store.indexNames.contains('byUserClientMsgNo')) {
      store.createIndex(
        'byUserClientMsgNo',
        _toJsStringArray(['uid', 'client_msg_no']),
      );
    }
    if (!store.indexNames.contains('byUserMessageId')) {
      store.createIndex(
        'byUserMessageId',
        _toJsStringArray(['uid', 'message_id']),
      );
    }
  }

  Future<void> _awaitRequest(web.IDBRequest request) {
    final completer = Completer<void>();
    request.onsuccess = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }).toJS;
    request.onerror = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
          request.error ?? StateError('IndexedDB request failed'),
        );
      }
    }).toJS;
    return completer.future;
  }

  Future<Object?> _awaitRequestResult(web.IDBRequest request) {
    final completer = Completer<Object?>();
    request.onsuccess = ((web.Event event) {
      if (!completer.isCompleted) {
        final result = request.result;
        completer.complete(result?.dartify());
      }
    }).toJS;
    request.onerror = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
          request.error ?? StateError('IndexedDB request failed'),
        );
      }
    }).toJS;
    return completer.future;
  }

  Future<List<Map<String, Object?>>> _readAround({
    required web.IDBIndex index,
    required String uid,
    required String channelId,
    required int channelType,
    required int limit,
    required int aroundOrderSeq,
  }) async {
    final plan = planIndexedDbAroundPage(limit: limit);
    final initialAfter = await _readCursorPage(
      index: index,
      range: _partitionRange(
        uid: uid,
        channelId: channelId,
        channelType: channelType,
        lowerOrderSeq: aroundOrderSeq,
        lowerOpen: !plan.includeAnchorInAfter,
      ),
      limit: 1,
      direction: 'next',
    );
    final anchorOrderSeq = initialAfter.isEmpty
        ? aroundOrderSeq
        : _toInt(initialAfter.first['order_seq']);
    var before = await _readCursorPage(
      index: index,
      range: _partitionRange(
        uid: uid,
        channelId: channelId,
        channelType: channelType,
        upperOrderSeq: anchorOrderSeq,
        upperOpen: true,
      ),
      limit: initialAfter.isEmpty ? plan.limit : plan.beforeLimit,
      direction: 'prev',
    );
    var after = initialAfter;
    if (initialAfter.isNotEmpty) {
      after = await _readCursorPage(
        index: index,
        range: _partitionRange(
          uid: uid,
          channelId: channelId,
          channelType: channelType,
          lowerOrderSeq: aroundOrderSeq,
          lowerOpen: !plan.includeAnchorInAfter,
        ),
        limit: plan.afterLimitForBeforeCount(before.length),
        direction: 'next',
      );
      final backfillBeforeLimit = plan.backfillBeforeLimitForAfterCount(
        after.length,
      );
      if (backfillBeforeLimit > before.length) {
        before = await _readCursorPage(
          index: index,
          range: _partitionRange(
            uid: uid,
            channelId: channelId,
            channelType: channelType,
            upperOrderSeq: anchorOrderSeq,
            upperOpen: true,
          ),
          limit: backfillBeforeLimit,
          direction: 'prev',
        );
      }
    }
    final records = _mergeRecords(before, after);
    if (records.length <= limit) {
      return records;
    }
    return records.sublist(records.length - limit);
  }

  Future<List<Map<String, Object?>>> _readCursorPage({
    required web.IDBIndex index,
    required web.IDBKeyRange range,
    required int limit,
    required web.IDBCursorDirection direction,
  }) {
    if (limit <= 0) {
      return Future<List<Map<String, Object?>>>.value(
        const <Map<String, Object?>>[],
      );
    }
    final completer = Completer<List<Map<String, Object?>>>();
    final records = <Map<String, Object?>>[];
    final request = index.openCursor(range, direction);
    request.onsuccess = ((web.Event event) {
      if (completer.isCompleted) {
        return;
      }
      final rawCursor = request.result;
      if (rawCursor == null) {
        completer.complete(records);
        return;
      }
      final cursor = rawCursor as web.IDBCursorWithValue;
      final record = _decodeRecord(cursor.value.dartify());
      if (record != null) {
        records.add(record);
      }
      if (records.length >= limit) {
        completer.complete(records);
        return;
      }
      cursor.continue_();
    }).toJS;
    request.onerror = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
          request.error ?? StateError('IndexedDB cursor failed'),
        );
      }
    }).toJS;
    return completer.future;
  }

  Future<void> _deleteCursorPage({
    required web.IDBIndex index,
    required web.IDBKeyRange range,
    required int limit,
  }) {
    if (limit <= 0) {
      return Future<void>.value();
    }
    final completer = Completer<void>();
    var deleted = 0;
    final request = index.openCursor(range, 'next');
    request.onsuccess = ((web.Event event) {
      if (completer.isCompleted) {
        return;
      }
      final rawCursor = request.result;
      if (rawCursor == null || deleted >= limit) {
        completer.complete();
        return;
      }
      final cursor = rawCursor as web.IDBCursorWithValue;
      deleted += 1;
      cursor.delete();
      if (deleted >= limit) {
        completer.complete();
        return;
      }
      cursor.continue_();
    }).toJS;
    request.onerror = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
          request.error ?? StateError('IndexedDB cursor delete failed'),
        );
      }
    }).toJS;
    return completer.future;
  }

  Future<void> _awaitTransactionComplete(web.IDBTransaction transaction) {
    final completer = Completer<void>();
    transaction.oncomplete = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }).toJS;
    transaction.onerror = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
          transaction.error ?? StateError('IndexedDB transaction failed'),
        );
      }
    }).toJS;
    transaction.onabort = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
          transaction.error ?? StateError('IndexedDB transaction aborted'),
        );
      }
    }).toJS;
    return completer.future;
  }

  List<Map<String, Object?>> _decodeRecords(Object? raw) {
    if (raw is! List) {
      return const <Map<String, Object?>>[];
    }
    return raw
        .whereType<Object?>()
        .map(_decodeRecord)
        .whereType<Map<String, Object?>>()
        .toList(growable: false);
  }

  Map<String, Object?>? _decodeRecord(Object? raw) {
    if (raw is Map) {
      return Map<String, Object?>.from(raw.cast<dynamic, dynamic>());
    }
    return null;
  }

  web.IDBKeyRange _partitionRange({
    required String uid,
    required String channelId,
    required int channelType,
    int? lowerOrderSeq,
    int? upperOrderSeq,
    bool lowerOpen = false,
    bool upperOpen = false,
  }) {
    final lower = _toJsAnyArray([
      uid.trim(),
      channelType,
      channelId.trim(),
      lowerOrderSeq ?? 0,
    ]);
    final upper = _toJsAnyArray([
      uid.trim(),
      channelType,
      channelId.trim(),
      upperOrderSeq ?? _maxIndexedDbOrderSeq,
    ]);
    return web.IDBKeyRange.bound(lower, upper, lowerOpen, upperOpen);
  }

  List<Map<String, Object?>> _mergeRecords(
    List<Map<String, Object?>> left,
    List<Map<String, Object?>> right,
  ) {
    final records = <String, Map<String, Object?>>{};
    for (final record in left.followedBy(right)) {
      records[_recordIdentity(record)] = record;
    }
    return records.values.toList(growable: false)..sort(_compareRecords);
  }

  int _safeLimit(int limit) {
    return limit <= 0 ? 20 : limit;
  }

  int _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _recordIdentity(Map<String, Object?> record) {
    final messageId = record['message_id']?.toString().trim() ?? '';
    if (messageId.isNotEmpty) {
      return 'message:$messageId';
    }
    final clientMsgNo = record['client_msg_no']?.toString().trim() ?? '';
    if (clientMsgNo.isNotEmpty) {
      return 'client:$clientMsgNo';
    }
    final messageSeq = _toInt(record['message_seq']);
    if (messageSeq > 0) {
      return 'seq:$messageSeq';
    }
    return 'order:${_toInt(record['order_seq'])}';
  }

  int _compareRecords(Map<String, Object?> left, Map<String, Object?> right) {
    final orderCompare = _toInt(
      left['order_seq'],
    ).compareTo(_toInt(right['order_seq']));
    if (orderCompare != 0) {
      return orderCompare;
    }
    final sequenceCompare = _toInt(
      left['message_seq'],
    ).compareTo(_toInt(right['message_seq']));
    if (sequenceCompare != 0) {
      return sequenceCompare;
    }
    return _recordIdentity(left).compareTo(_recordIdentity(right));
  }

  JSAny? _toJsObject(Map<String, Object?> record) {
    return record.jsify();
  }

  JSArray<JSString> _toJsStringArray(List<String> values) {
    return values.map((value) => value.toJS).toList(growable: false).toJS;
  }

  JSArray<JSAny?> _toJsAnyArray(List<Object?> values) {
    return values.map((value) => value.jsify()).toList(growable: false).toJS;
  }
}
