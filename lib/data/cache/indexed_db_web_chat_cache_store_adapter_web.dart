import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'indexed_db_web_chat_cache_store_adapter_base.dart';

const String _indexedDbName = 'wukong_chat_cache_v1';
const String _messagesStoreName = 'messages';

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
      final store = transaction.objectStore(_messagesStoreName);
      final result = await _awaitRequestResult(store.getAll());
      await _awaitTransactionComplete(transaction);
      return _decodeRecords(result);
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
      await _awaitTransactionComplete(transaction);
    } finally {
      database.close();
    }
  }

  Future<web.IDBDatabase> _openDatabase() async {
    if (!globalContext.has('indexedDB')) {
      throw StateError('IndexedDB is unavailable');
    }

    final request = web.window.indexedDB.open(_indexedDbName, 1);
    final completer = Completer<web.IDBDatabase>();

    request.onupgradeneeded = ((web.Event event) {
      try {
        final database = request.result as web.IDBDatabase;
        if (!database.objectStoreNames.contains(_messagesStoreName)) {
          final store = database.createObjectStore(
            _messagesStoreName,
            web.IDBObjectStoreParameters(keyPath: 'cache_key'.toJS),
          );
          _ensureIndexes(store);
        }
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
      debugPrint('IndexedDB open blocked for $_indexedDbName');
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

  JSAny? _toJsObject(Map<String, Object?> record) {
    return record.jsify();
  }

  JSArray<JSString> _toJsStringArray(List<String> values) {
    return values.map((value) => value.toJS).toList(growable: false).toJS;
  }
}
