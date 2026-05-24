import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_unknown_content.dart';
import 'package:wukongimfluttersdk/proto/proto.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import 'indexed_db_web_chat_cache_store_adapter.dart';
import 'web_chat_cache_store.dart';

export 'indexed_db_web_chat_cache_store_adapter_base.dart';

typedef IndexedDbCacheErrorReporter =
    void Function(String message, Object error, StackTrace stackTrace);

class IndexedDbWebChatCacheStore implements WebChatCacheStore {
  IndexedDbWebChatCacheStore({
    IndexedDbChatCacheAdapter? adapter,
    this.maxMessagesPerChannel = 2000,
    IndexedDbCacheErrorReporter? errorReporter,
  }) : _adapter = adapter ?? createIndexedDbChatCacheAdapter(),
       _errorReporter = errorReporter ?? _debugPrintCacheError;

  final IndexedDbChatCacheAdapter _adapter;
  final IndexedDbCacheErrorReporter _errorReporter;
  final int maxMessagesPerChannel;
  final Map<String, List<Map<String, Object?>>> _recordsByPartition =
      <String, List<Map<String, Object?>>>{};
  final Set<String> _dirtyPartitions = <String>{};
  Future<void>? _loadFuture;
  bool _loaded = false;

  @override
  Future<List<WKMsg>> readMessages({
    String uid = '',
    required String channelId,
    required int channelType,
    required int limit,
    int beforeOrderSeq = 0,
    int aroundOrderSeq = 0,
  }) async {
    final pageLimit = _safeLimit(limit);
    final records = await _readPartitionRecords(
      uid: uid,
      channelId: channelId,
      channelType: channelType,
      limit: pageLimit,
      beforeOrderSeq: beforeOrderSeq,
      aroundOrderSeq: aroundOrderSeq,
    );
    var messages = records.map(_messageFromRecord).toList(growable: false)
      ..sort(_compareMessages);
    if (beforeOrderSeq > 0) {
      messages = messages
          .where((message) => message.orderSeq < beforeOrderSeq)
          .toList(growable: false);
    } else if (aroundOrderSeq > 0) {
      messages = _windowAround(messages, aroundOrderSeq, pageLimit);
      return messages;
    }
    if (messages.length <= pageLimit) {
      return messages;
    }
    return messages.sublist(messages.length - pageLimit);
  }

  @override
  Future<void> upsertMessages({
    String uid = '',
    required String channelId,
    required int channelType,
    required List<WKMsg> messages,
  }) async {
    if (messages.isEmpty) {
      return;
    }

    final partitionKey = _partitionKey(uid, channelId, channelType);
    final previousRecords = await _readPartitionRecords(
      uid: uid,
      channelId: channelId,
      channelType: channelType,
      limit: maxMessagesPerChannel,
    );
    final byIdentity = <String, Map<String, Object?>>{
      for (final record in previousRecords)
        _recordIdentity(record): Map<String, Object?>.from(record),
    };

    for (final message in messages) {
      if (message.channelID.isEmpty) {
        message.channelID = channelId;
      }
      if (message.channelType == 0) {
        message.channelType = channelType;
      }
      final record = _recordFromMessage(
        uid: uid,
        channelId: channelId,
        channelType: channelType,
        message: message,
      );
      if (_hasServerIdentity(record)) {
        _removeLegacyIdentities(byIdentity, record);
      }
      byIdentity[_recordIdentity(record)] = record;
    }

    final next = byIdentity.values.toList(growable: false)
      ..sort(_compareRecords);
    final trimmed = next.length > maxMessagesPerChannel
        ? next.sublist(next.length - maxMessagesPerChannel)
        : next;
    _recordsByPartition[partitionKey] = trimmed;
    await _persistPartition(
      previousRecords: previousRecords,
      nextRecords: trimmed,
    );
    await _deleteOldPartitionRecords(
      uid: uid,
      channelId: channelId,
      channelType: channelType,
    );
  }

  @override
  Future<void> clearUser({required String uid}) async {
    await _ensureLoaded();
    final normalizedUid = uid.trim();
    final deleteKeys = <String>[];
    final prefix = _partitionPrefix(normalizedUid);
    final partitions = _recordsByPartition.keys
        .where((key) => key.startsWith(prefix))
        .toList(growable: false);
    for (final partitionKey in partitions) {
      final records = _recordsByPartition.remove(partitionKey);
      if (records == null) {
        continue;
      }
      deleteKeys.addAll(records.map(_cacheKey).where((key) => key.isNotEmpty));
    }
    await _applyChanges(
      upserts: const <Map<String, Object?>>[],
      deleteKeys: deleteKeys,
    );
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) {
      return;
    }
    final pendingLoad = _loadFuture;
    if (pendingLoad != null) {
      await pendingLoad;
      return;
    }
    final loadFuture = _loadFromAdapter();
    _loadFuture = loadFuture;
    try {
      await loadFuture;
    } finally {
      if (identical(_loadFuture, loadFuture)) {
        _loadFuture = null;
      }
    }
  }

  Future<void> _loadFromAdapter() async {
    try {
      final records = await _adapter.readAll();
      final deletedKeys = _hydrate(records);
      _loaded = true;
      if (deletedKeys.isNotEmpty) {
        await _applyChanges(
          upserts: const <Map<String, Object?>>[],
          deleteKeys: deletedKeys,
        );
      }
    } catch (error, stackTrace) {
      _errorReporter('IndexedDB chat cache load failed', error, stackTrace);
    }
  }

  Future<void> _persistPartition({
    required List<Map<String, Object?>> previousRecords,
    required List<Map<String, Object?>> nextRecords,
  }) async {
    final partitionKey = nextRecords.isNotEmpty
        ? _partitionKeyFromRecord(nextRecords.first)
        : previousRecords.isNotEmpty
        ? _partitionKeyFromRecord(previousRecords.first)
        : null;
    final previousKeys = previousRecords.map(_cacheKey).toSet();
    final nextKeys = nextRecords.map(_cacheKey).toSet();
    final deleteKeys = previousKeys
        .difference(nextKeys)
        .where((key) => key.isNotEmpty)
        .toList(growable: false);
    final persisted = await _applyChanges(
      upserts: nextRecords,
      deleteKeys: deleteKeys,
    );
    if (partitionKey != null) {
      if (persisted) {
        _dirtyPartitions.remove(partitionKey);
      } else {
        _dirtyPartitions.add(partitionKey);
      }
    }
  }

  Future<List<Map<String, Object?>>> _readPartitionRecords({
    required String uid,
    required String channelId,
    required int channelType,
    required int limit,
    int beforeOrderSeq = 0,
    int aroundOrderSeq = 0,
  }) async {
    try {
      final records = await _adapter.readMessages(
        uid: _normalizeUid(uid),
        channelId: channelId.trim(),
        channelType: channelType,
        limit: limit,
        beforeOrderSeq: beforeOrderSeq,
        aroundOrderSeq: aroundOrderSeq,
      );
      final normalized =
          records
              .map((record) => Map<String, Object?>.from(record))
              .where(
                (record) =>
                    _partitionKeyFromRecord(record) ==
                    _partitionKey(uid, channelId, channelType),
              )
              .toList(growable: false)
            ..sort(_compareRecords);
      final partitionKey = _partitionKey(uid, channelId, channelType);
      final merged = _dirtyPartitions.contains(partitionKey)
          ? _mergePartitionRecords(
              _recordsByPartition[partitionKey] ??
                  const <Map<String, Object?>>[],
              normalized,
            )
          : normalized;
      if (merged.length > maxMessagesPerChannel) {
        final trimmed = merged.sublist(merged.length - maxMessagesPerChannel);
        _recordsByPartition[partitionKey] = trimmed;
        await _deleteOldPartitionRecords(
          uid: uid,
          channelId: channelId,
          channelType: channelType,
        );
        return trimmed;
      }
      _recordsByPartition[partitionKey] = merged;
      return merged;
    } catch (error, stackTrace) {
      _errorReporter(
        'IndexedDB chat cache partition read failed',
        error,
        stackTrace,
      );
      return _recordsForPartition(uid, channelId, channelType);
    }
  }

  static List<Map<String, Object?>> _mergePartitionRecords(
    List<Map<String, Object?>> existing,
    List<Map<String, Object?>> incoming,
  ) {
    final byIdentity = <String, Map<String, Object?>>{
      for (final record in existing)
        _recordIdentity(record): Map<String, Object?>.from(record),
    };
    for (final record in incoming) {
      byIdentity[_recordIdentity(record)] = Map<String, Object?>.from(record);
    }
    return byIdentity.values.toList(growable: false)..sort(_compareRecords);
  }

  Future<void> _deleteOldPartitionRecords({
    required String uid,
    required String channelId,
    required int channelType,
  }) async {
    try {
      await _adapter.deleteOldMessages(
        uid: _normalizeUid(uid),
        channelId: channelId.trim(),
        channelType: channelType,
        keepLatest: maxMessagesPerChannel,
      );
    } catch (error, stackTrace) {
      _errorReporter(
        'IndexedDB chat cache retention trim failed',
        error,
        stackTrace,
      );
    }
  }

  Future<bool> _applyChanges({
    required List<Map<String, Object?>> upserts,
    required List<String> deleteKeys,
  }) async {
    try {
      await _adapter.applyChanges(upserts: upserts, deleteKeys: deleteKeys);
      return true;
    } catch (error, stackTrace) {
      _errorReporter('IndexedDB chat cache persist failed', error, stackTrace);
      return false;
    }
  }

  static void _debugPrintCacheError(
    String message,
    Object error,
    StackTrace stackTrace,
  ) {
    debugPrint('$message: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  List<String> _hydrate(List<Map<String, Object?>> records) {
    _recordsByPartition.clear();
    for (final record in records) {
      final partitionKey = _partitionKeyFromRecord(record);
      if (partitionKey == null) {
        continue;
      }
      _recordsByPartition
          .putIfAbsent(partitionKey, () => <Map<String, Object?>>[])
          .add(Map<String, Object?>.from(record));
    }
    final deleteKeys = <String>[];
    for (final entry in _recordsByPartition.entries) {
      final sorted = entry.value.toList(growable: false)..sort(_compareRecords);
      if (sorted.length > maxMessagesPerChannel) {
        deleteKeys.addAll(
          sorted
              .take(sorted.length - maxMessagesPerChannel)
              .map(_cacheKey)
              .where((key) => key.isNotEmpty),
        );
        _recordsByPartition[entry.key] = sorted.sublist(
          sorted.length - maxMessagesPerChannel,
        );
      } else {
        _recordsByPartition[entry.key] = sorted;
      }
    }
    return deleteKeys;
  }

  List<Map<String, Object?>> _recordsForPartition(
    String uid,
    String channelId,
    int channelType,
  ) {
    return List<Map<String, Object?>>.from(
      _recordsByPartition[_partitionKey(uid, channelId, channelType)] ??
          const <Map<String, Object?>>[],
    );
  }

  static String _partitionKey(String uid, String channelId, int channelType) {
    return '${_encodeKeyPart(_normalizeUid(uid))}|$channelType|${_encodeKeyPart(channelId)}';
  }

  static String _partitionPrefix(String uid) {
    return '${_encodeKeyPart(_normalizeUid(uid))}|';
  }

  static String _encodeKeyPart(String value) {
    return Uri.encodeComponent(value.trim());
  }

  static String _normalizeUid(String uid) {
    return uid.trim();
  }

  static String? _partitionKeyFromRecord(Map<String, Object?> record) {
    final uid = _normalizeUid(_readString(record, 'uid'));
    final channelId = _readString(record, 'channel_id').trim();
    final channelType = _readInt(record, 'channel_type');
    if (channelId.isEmpty || channelType <= 0) {
      return null;
    }
    return _partitionKey(uid, channelId, channelType);
  }

  static String _recordIdentity(Map<String, Object?> record) {
    final messageId = _readString(record, 'message_id').trim();
    if (messageId.isNotEmpty) {
      return 'message:$messageId';
    }
    final clientMsgNo = _readString(record, 'client_msg_no').trim();
    if (clientMsgNo.isNotEmpty) {
      return 'client:$clientMsgNo';
    }
    final messageSeq = _readInt(record, 'message_seq');
    if (messageSeq > 0) {
      return 'seq:$messageSeq';
    }
    return 'order:${_readInt(record, 'order_seq')}';
  }

  static bool _hasServerIdentity(Map<String, Object?> record) {
    return _readString(record, 'message_id').trim().isNotEmpty;
  }

  static void _removeLegacyIdentities(
    Map<String, Map<String, Object?>> byIdentity,
    Map<String, Object?> record,
  ) {
    final clientMsgNo = _readString(record, 'client_msg_no').trim();
    final messageSeq = _readInt(record, 'message_seq');
    if (clientMsgNo.isEmpty && messageSeq <= 0) {
      return;
    }

    final replaceKeys = byIdentity.entries
        .where((entry) {
          final existing = entry.value;
          if (clientMsgNo.isNotEmpty &&
              _readString(existing, 'client_msg_no').trim() == clientMsgNo) {
            return true;
          }
          return messageSeq > 0 &&
              _readInt(existing, 'message_seq') == messageSeq;
        })
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final key in replaceKeys) {
      byIdentity.remove(key);
    }
  }

  static String _cacheKey(Map<String, Object?> record) {
    return _readString(record, 'cache_key').trim();
  }

  static Map<String, Object?> _recordFromMessage({
    required String uid,
    required String channelId,
    required int channelType,
    required WKMsg message,
  }) {
    final normalizedUid = _normalizeUid(uid);
    final normalizedChannelId = channelId.trim();
    final identity = _messageIdentity(message);
    return <String, Object?>{
      'cache_key':
          '${_encodeKeyPart(normalizedUid)}|$channelType|${_encodeKeyPart(normalizedChannelId)}|${_encodeKeyPart(identity)}',
      'uid': normalizedUid,
      'channel_id': normalizedChannelId,
      'channel_type': channelType,
      'message_id': message.messageID.trim(),
      'client_msg_no': message.clientMsgNO.trim(),
      'message_seq': message.messageSeq,
      'order_seq': message.orderSeq,
      'timestamp': message.timestamp,
      'content_type': message.contentType,
      'content': message.content,
      'is_deleted': message.isDeleted,
      'status': message.status,
      'voice_status': message.voiceStatus,
      'from_uid': message.fromUID.trim(),
      'server_msg_id': message.serverMsgID.trim(),
      'topic_id': message.topicID.trim(),
      'setting': message.setting.encode(),
      'extra': message.localExtraMap,
      'flame': message.flame,
      'flame_second': message.flameSecond,
      'viewed': message.viewed,
      'viewed_at': message.viewedAt,
      'expire_time': message.expireTime,
      'expire_timestamp': message.expireTimestamp,
    };
  }

  static String _messageIdentity(WKMsg message) {
    final messageId = message.messageID.trim();
    if (messageId.isNotEmpty) {
      return 'message:$messageId';
    }
    final clientMsgNo = message.clientMsgNO.trim();
    if (clientMsgNo.isNotEmpty) {
      return 'client:$clientMsgNo';
    }
    if (message.messageSeq > 0) {
      return 'seq:${message.messageSeq}';
    }
    return 'order:${message.orderSeq}';
  }

  static WKMsg _messageFromRecord(Map<String, Object?> record) {
    final message = WKMsg();
    message.messageID = _readString(record, 'message_id');
    message.clientMsgNO = _readString(record, 'client_msg_no');
    message.messageSeq = _readInt(record, 'message_seq');
    message.orderSeq = _readInt(record, 'order_seq');
    message.timestamp = _readInt(record, 'timestamp');
    message.contentType = _readInt(record, 'content_type');
    message.content = _readString(record, 'content');
    message.isDeleted = _readInt(record, 'is_deleted');
    message.status = _readInt(record, 'status');
    message.voiceStatus = _readInt(record, 'voice_status');
    message.channelID = _readString(record, 'channel_id');
    message.channelType = _readInt(record, 'channel_type');
    message.fromUID = _readString(record, 'from_uid');
    message.serverMsgID = _readString(record, 'server_msg_id');
    message.topicID = _readString(record, 'topic_id');
    message.flame = _readInt(record, 'flame');
    message.flameSecond = _readInt(record, 'flame_second');
    message.viewed = _readInt(record, 'viewed');
    message.viewedAt = _readInt(record, 'viewed_at');
    message.expireTime = _readInt(record, 'expire_time');
    message.expireTimestamp = _readInt(record, 'expire_timestamp');
    message.setting = Setting().decode(_readInt(record, 'setting'));
    final extra = record['extra'];
    if (extra is Map) {
      message.localExtraMap = Map<String, dynamic>.from(extra.cast());
    } else {
      message.localExtraMap = extra;
    }
    if (message.content.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(message.content);
        if (decoded != null && decoded != '') {
          final model = WKIM.shared.messageManager.getMessageModel(
            message.contentType,
            decoded,
          );
          if (model != null) {
            message.messageContent = model;
          } else {
            message.messageContent = WKUnknownContent();
          }
        }
      } catch (_) {}
    }
    return message;
  }

  static int _safeLimit(int limit) {
    return limit <= 0 ? 20 : limit;
  }

  static int _readInt(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _readString(Map<String, Object?> record, String key) {
    return record[key]?.toString() ?? '';
  }

  static int _compareMessages(WKMsg left, WKMsg right) {
    final orderCompare = left.orderSeq.compareTo(right.orderSeq);
    if (orderCompare != 0) {
      return orderCompare;
    }
    final sequenceCompare = left.messageSeq.compareTo(right.messageSeq);
    if (sequenceCompare != 0) {
      return sequenceCompare;
    }
    return _messageIdentity(left).compareTo(_messageIdentity(right));
  }

  static int _compareRecords(
    Map<String, Object?> left,
    Map<String, Object?> right,
  ) {
    final orderCompare = _readInt(
      left,
      'order_seq',
    ).compareTo(_readInt(right, 'order_seq'));
    if (orderCompare != 0) {
      return orderCompare;
    }
    final sequenceCompare = _readInt(
      left,
      'message_seq',
    ).compareTo(_readInt(right, 'message_seq'));
    if (sequenceCompare != 0) {
      return sequenceCompare;
    }
    return _recordIdentity(left).compareTo(_recordIdentity(right));
  }

  static List<WKMsg> _windowAround(
    List<WKMsg> messages,
    int aroundOrderSeq,
    int limit,
  ) {
    if (messages.length <= limit) {
      return messages;
    }
    final anchorIndex = messages.indexWhere(
      (message) => message.orderSeq >= aroundOrderSeq,
    );
    if (anchorIndex < 0) {
      return messages.sublist(messages.length - limit);
    }
    final before = limit ~/ 2;
    var start = anchorIndex - before;
    if (start < 0) {
      start = 0;
    }
    var end = start + limit;
    if (end > messages.length) {
      end = messages.length;
      start = end - limit;
      if (start < 0) {
        start = 0;
      }
    }
    return messages.sublist(start, end);
  }
}
