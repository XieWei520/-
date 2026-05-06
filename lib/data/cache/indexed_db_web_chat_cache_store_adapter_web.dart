import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'indexed_db_web_chat_cache_store_adapter.dart';

IndexedDbWebChatCacheAdapter createIndexedDbWebChatCacheAdapter() {
  return const _WebIndexedDbWebChatCacheAdapter();
}

class _WebIndexedDbWebChatCacheAdapter implements IndexedDbWebChatCacheAdapter {
  const _WebIndexedDbWebChatCacheAdapter();

  static const String _databaseName = 'wukong_im_app_web_chat_cache';
  static const String _storeName = 'chat_cache';
  static const String _recordKey = 'records';

  @override
  Future<List<Map<String, Object?>>> readAll() async {
    final db = await _openDatabase();
    final transaction = db.transaction(_storeName.toJS, 'readonly');
    final store = transaction.objectStore(_storeName);
    final request = store.get(_recordKey.toJS);
    final record = await _requestValue(request);
    final dartValue = record?.dartify();
    if (dartValue is! Map) {
      return const <Map<String, Object?>>[];
    }
    final rawRecords = dartValue['records'];
    if (rawRecords is! List) {
      return const <Map<String, Object?>>[];
    }
    return rawRecords
        .whereType<Map>()
        .map((record) => Map<String, Object?>.from(record))
        .toList(growable: false);
  }

  @override
  Future<void> writeAll(List<Map<String, Object?>> records) async {
    final db = await _openDatabase();
    final transaction = db.transaction(_storeName.toJS, 'readwrite');
    final store = transaction.objectStore(_storeName);
    final payload = <String, Object?>{
      'id': _recordKey,
      'records': records
          .map((record) => Map<String, Object?>.from(record))
          .toList(growable: false),
    };
    await _requestValue(store.put(payload.jsify(), _recordKey.toJS));
  }

  Future<web.IDBDatabase> _openDatabase() async {
    final request = web.window.indexedDB.open(_databaseName, 1);
    request.onupgradeneeded = ((web.Event event) {
      final database = request.result as web.IDBDatabase;
      if (!database.objectStoreNames.contains(_storeName)) {
        database.createObjectStore(_storeName);
      }
    }).toJS;
    return (await _requestValue(request)) as web.IDBDatabase;
  }

  Future<JSAny?> _requestValue(web.IDBRequest request) {
    final completer = Completer<JSAny?>();
    request.onsuccess = ((web.Event event) {
      completer.complete(request.result);
    }).toJS;
    request.onerror = ((web.Event event) {
      completer.completeError(
        request.error ?? StateError('IndexedDB request failed'),
      );
    }).toJS;
    return completer.future;
  }
}
