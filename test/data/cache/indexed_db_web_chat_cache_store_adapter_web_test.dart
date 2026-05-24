@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:web/web.dart' as web;
import 'package:wukong_im_app/data/cache/indexed_db_web_chat_cache_store_adapter_web.dart';

const String _databaseName = 'wukong_chat_cache_v1';
const String _messagesStoreName = 'messages';

void main() {
  tearDown(() async {
    await _deleteDatabase(_databaseName);
  });

  test(
    'upgrades legacy v1 message store with partition paging index',
    () async {
      await _deleteDatabase(_databaseName);
      await _createLegacyV1Database();

      final adapter = WebIndexedDbChatCacheAdapter();

      final records = await adapter.readMessages(
        uid: 'legacy-user',
        channelId: 'legacy-channel',
        channelType: 1,
        limit: 20,
      );

      expect(records.map((record) => record['message_id']), ['legacy-message']);
    },
  );
}

Future<void> _createLegacyV1Database() async {
  final request = web.window.indexedDB.open(_databaseName, 1);
  final completer = Completer<web.IDBDatabase>();

  request.onupgradeneeded = ((web.Event event) {
    final database = request.result as web.IDBDatabase;
    database.createObjectStore(
      _messagesStoreName,
      web.IDBObjectStoreParameters(keyPath: 'cache_key'.toJS),
    );
  }).toJS;
  request.onsuccess = ((web.Event event) {
    if (!completer.isCompleted) {
      completer.complete(request.result as web.IDBDatabase);
    }
  }).toJS;
  request.onerror = ((web.Event event) {
    if (!completer.isCompleted) {
      completer.completeError(
        request.error ?? StateError('legacy IndexedDB open failed'),
      );
    }
  }).toJS;

  final database = await completer.future;
  try {
    final transaction = database.transaction(
      _toJsStringArray([_messagesStoreName]),
      'readwrite',
    );
    final completed = _awaitTransactionComplete(transaction);
    await _awaitRequest(
      transaction
          .objectStore(_messagesStoreName)
          .put(
            <String, Object?>{
              'cache_key':
                  'legacy-user|1|legacy-channel|message:legacy-message',
              'uid': 'legacy-user',
              'channel_id': 'legacy-channel',
              'channel_type': 1,
              'message_id': 'legacy-message',
              'client_msg_no': 'legacy-client',
              'message_seq': 1,
              'order_seq': 1000,
              'timestamp': 1700000001,
              'from_uid': 'legacy-user',
              'content_type': 1,
            }.jsify(),
          ),
    );
    await completed;
  } finally {
    database.close();
  }
}

Future<void> _deleteDatabase(String name) {
  final request = web.window.indexedDB.deleteDatabase(name);
  final completer = Completer<void>();
  request.onsuccess = ((web.Event event) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  }).toJS;
  request.onerror = ((web.Event event) {
    if (!completer.isCompleted) {
      completer.completeError(
        request.error ?? StateError('IndexedDB delete failed'),
      );
    }
  }).toJS;
  request.onblocked = ((web.Event event) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('IndexedDB delete blocked'));
    }
  }).toJS;
  return completer.future;
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

JSArray<JSString> _toJsStringArray(List<String> values) {
  return values.map((value) => value.toJS).toList(growable: false).toJS;
}
