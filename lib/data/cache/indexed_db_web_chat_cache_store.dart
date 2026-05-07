import 'package:wukongimfluttersdk/entity/msg.dart';

import 'indexed_db_web_chat_cache_store_adapter.dart';
import 'web_chat_cache_store.dart';
import 'web_chat_cache_store_memory.dart';

class IndexedDbWebChatCacheStore implements WebChatCacheStore {
  IndexedDbWebChatCacheStore({
    IndexedDbWebChatCacheAdapter? adapter,
    MemoryWebChatCacheStore? memoryFallback,
  }) : _adapter = adapter ?? createIndexedDbWebChatCacheAdapter(),
       _memoryFallback = memoryFallback ?? MemoryWebChatCacheStore();

  final IndexedDbWebChatCacheAdapter _adapter;
  final MemoryWebChatCacheStore _memoryFallback;
  final Map<String, List<Map<String, Object?>>> _recordsByPartition = {};
  bool _loaded = false;
  bool _useMemoryFallback = false;

  @override
  Future<List<WKMsg>> readMessages({
    required String channelId,
    required int channelType,
    required int limit,
    String uid = '',
    int beforeOrderSeq = 0,
    int aroundOrderSeq = 0,
  }) async {
    if (_useMemoryFallback) {
      return _memoryFallback.readMessages(
        channelId: channelId,
        channelType: channelType,
        limit: limit,
        uid: uid,
        beforeOrderSeq: beforeOrderSeq,
        aroundOrderSeq: aroundOrderSeq,
      );
    }
    try {
      await _ensureLoaded();
      return _readPartition(
        uid: uid,
        channelId: channelId,
        channelType: channelType,
        limit: limit,
        beforeOrderSeq: beforeOrderSeq,
        aroundOrderSeq: aroundOrderSeq,
      );
    } catch (_) {
      await _switchToMemoryFallback();
      return _memoryFallback.readMessages(
        channelId: channelId,
        channelType: channelType,
        limit: limit,
        uid: uid,
        beforeOrderSeq: beforeOrderSeq,
        aroundOrderSeq: aroundOrderSeq,
      );
    }
  }

  @override
  Future<void> upsertMessages({
    required String channelId,
    required int channelType,
    required List<WKMsg> messages,
    String uid = '',
  }) async {
    if (_useMemoryFallback) {
      await _memoryFallback.upsertMessages(
        channelId: channelId,
        channelType: channelType,
        messages: messages,
        uid: uid,
      );
      return;
    }
    try {
      await _ensureLoaded();
      final partitionKey = _partitionKey(uid, channelId, channelType);
      final recordsByIdentity = <String, Map<String, Object?>>{
        for (final record in _recordsByPartition[partitionKey] ?? const [])
          _identityKey(record): Map<String, Object?>.from(record),
      };
      for (final message in messages) {
        final normalized = _normalizeMessage(
          message,
          uid: uid,
          channelId: channelId,
          channelType: channelType,
        );
        recordsByIdentity[_identityKey(normalized)] = normalized;
      }
      final next = recordsByIdentity.values.toList(growable: false)
        ..sort(_compareRecords);
      _recordsByPartition[partitionKey] = next.length > _retentionLimit
          ? next.sublist(next.length - _retentionLimit)
          : next;
      await _persist();
    } catch (_) {
      await _switchToMemoryFallback();
      await _memoryFallback.upsertMessages(
        channelId: channelId,
        channelType: channelType,
        messages: messages,
        uid: uid,
      );
    }
  }

  @override
  Future<void> clearUser({required String uid}) async {
    await _memoryFallback.clearUser(uid: uid);
    if (_useMemoryFallback) {
      return;
    }
    try {
      await _ensureLoaded();
      _recordsByPartition.removeWhere(
        (partitionKey, _) =>
            uid.isEmpty ||
            partitionKey.startsWith('$uid::') ||
            partitionKey.startsWith('::'),
      );
      await _persist();
    } catch (_) {
      await _switchToMemoryFallback();
    }
  }

  Future<void> _switchToMemoryFallback() async {
    if (_useMemoryFallback) {
      return;
    }
    await _hydrateMemoryFallback();
    _useMemoryFallback = true;
  }

  Future<void> _hydrateMemoryFallback() async {
    for (final partition in _recordsByPartition.values) {
      if (partition.isEmpty) {
        continue;
      }
      final first = partition.first;
      await _memoryFallback.upsertMessages(
        uid: _stringValue(first, 'uid'),
        channelId: _stringValue(first, 'channelId'),
        channelType: _intValue(first, 'channelType'),
        messages: partition
            .map((record) => _messageFromRecord(record))
            .toList(growable: false),
      );
    }
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) {
      return;
    }
    final records = await _adapter.readAll();
    _recordsByPartition.clear();
    for (final record in records) {
      final uid = _stringValue(record, 'uid');
      final channelId = _stringValue(record, 'channelId');
      final channelType = _intValue(record, 'channelType');
      final partitionKey = _partitionKey(uid, channelId, channelType);
      _recordsByPartition.putIfAbsent(
        partitionKey,
        () => <Map<String, Object?>>[],
      );
      _recordsByPartition[partitionKey]!.add(Map<String, Object?>.from(record));
    }
    for (final entry in _recordsByPartition.entries) {
      entry.value.sort(_compareRecords);
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    final records = <Map<String, Object?>>[];
    for (final partition in _recordsByPartition.values) {
      for (final record in partition) {
        records.add(Map<String, Object?>.from(record));
      }
    }
    await _adapter.writeAll(records);
  }

  List<WKMsg> _readPartition({
    required String uid,
    required String channelId,
    required int channelType,
    required int limit,
    required int beforeOrderSeq,
    required int aroundOrderSeq,
  }) {
    final records = List<Map<String, Object?>>.from(
      _recordsByPartition[_partitionKey(uid, channelId, channelType)] ??
          const <Map<String, Object?>>[],
    )..sort(_compareRecords);
    final pageLimit = _safeLimit(limit);
    if (beforeOrderSeq > 0) {
      final filtered = records
          .where((record) => _intValue(record, 'orderSeq') < beforeOrderSeq)
          .toList(growable: false);
      return _pageLatest(filtered, pageLimit);
    }
    if (aroundOrderSeq > 0) {
      return _windowAround(
        records,
        aroundOrderSeq,
        pageLimit,
      ).map((record) => _messageFromRecord(record)).toList(growable: false);
    }
    return _pageLatest(records, pageLimit);
  }

  static String _partitionKey(String uid, String channelId, int channelType) {
    return '$uid::$channelType:$channelId';
  }

  static int _safeLimit(int limit) {
    return limit <= 0 ? 20 : limit;
  }

  static const int _retentionLimit = 2000;

  static Map<String, Object?> _normalizeMessage(
    WKMsg message, {
    required String uid,
    required String channelId,
    required int channelType,
  }) {
    return <String, Object?>{
      'uid': uid,
      'channelId': message.channelID.isEmpty ? channelId : message.channelID,
      'channelType': message.channelType == 0
          ? channelType
          : message.channelType,
      'messageID': message.messageID,
      'clientMsgNO': message.clientMsgNO,
      'messageSeq': message.messageSeq,
      'orderSeq': message.orderSeq,
      'contentType': message.contentType,
      'content': message.content,
      'status': message.status,
      'voiceStatus': message.voiceStatus,
      'isDeleted': message.isDeleted,
      'searchableWord': message.searchableWord,
      'expireTime': message.expireTime,
      'expireTimestamp': message.expireTimestamp,
      'viewed': message.viewed,
      'viewedAt': message.viewedAt,
      'topicID': message.topicID,
      'fromUID': message.fromUID,
      'timestamp': message.timestamp,
    };
  }

  static WKMsg _messageFromRecord(Map<String, Object?> record) {
    return WKMsg()
      ..channelID = _stringValue(record, 'channelId')
      ..channelType = _intValue(record, 'channelType')
      ..messageID = _stringValue(record, 'messageID')
      ..clientMsgNO = _stringValue(record, 'clientMsgNO')
      ..messageSeq = _intValue(record, 'messageSeq')
      ..orderSeq = _intValue(record, 'orderSeq')
      ..contentType = _intValue(record, 'contentType')
      ..content = _stringValue(record, 'content')
      ..status = _intValue(record, 'status')
      ..voiceStatus = _intValue(record, 'voiceStatus')
      ..isDeleted = _intValue(record, 'isDeleted')
      ..searchableWord = _stringValue(record, 'searchableWord')
      ..expireTime = _intValue(record, 'expireTime')
      ..expireTimestamp = _intValue(record, 'expireTimestamp')
      ..viewed = _intValue(record, 'viewed')
      ..viewedAt = _intValue(record, 'viewedAt')
      ..topicID = _stringValue(record, 'topicID')
      ..fromUID = _stringValue(record, 'fromUID')
      ..timestamp = _intValue(record, 'timestamp');
  }

  static List<WKMsg> _pageLatest(
    List<Map<String, Object?>> records,
    int limit,
  ) {
    if (records.length <= limit) {
      return records
          .map((record) => _messageFromRecord(record))
          .toList(growable: false);
    }
    return records
        .sublist(records.length - limit)
        .map((record) => _messageFromRecord(record))
        .toList(growable: false);
  }

  static List<Map<String, Object?>> _windowAround(
    List<Map<String, Object?>> records,
    int aroundOrderSeq,
    int limit,
  ) {
    if (records.length <= limit) {
      return records;
    }
    final anchorIndex = records.indexWhere(
      (record) => _intValue(record, 'orderSeq') >= aroundOrderSeq,
    );
    if (anchorIndex < 0) {
      return records.sublist(records.length - limit);
    }
    final before = limit ~/ 2;
    var start = anchorIndex - before;
    if (start < 0) {
      start = 0;
    }
    var end = start + limit;
    if (end > records.length) {
      end = records.length;
      start = end - limit;
      if (start < 0) {
        start = 0;
      }
    }
    return records.sublist(start, end);
  }

  static String _identityKey(Map<String, Object?> record) {
    final messageId = _stringValue(record, 'messageID').trim();
    if (messageId.isNotEmpty) {
      return 'message:$messageId';
    }
    final clientMsgNo = _stringValue(record, 'clientMsgNO').trim();
    if (clientMsgNo.isNotEmpty) {
      return 'client:$clientMsgNo';
    }
    final messageSeq = _intValue(record, 'messageSeq');
    if (messageSeq != 0) {
      return 'seq:$messageSeq';
    }
    return 'order:${_intValue(record, "orderSeq")}';
  }

  static int _compareRecords(
    Map<String, Object?> left,
    Map<String, Object?> right,
  ) {
    final orderCompare = _intValue(
      left,
      'orderSeq',
    ).compareTo(_intValue(right, 'orderSeq'));
    if (orderCompare != 0) {
      return orderCompare;
    }
    final messageSeqCompare = _intValue(
      left,
      'messageSeq',
    ).compareTo(_intValue(right, 'messageSeq'));
    if (messageSeqCompare != 0) {
      return messageSeqCompare;
    }
    final messageIdCompare = _stringValue(
      left,
      'messageID',
    ).compareTo(_stringValue(right, 'messageID'));
    if (messageIdCompare != 0) {
      return messageIdCompare;
    }
    return _stringValue(
      left,
      'clientMsgNO',
    ).compareTo(_stringValue(right, 'clientMsgNO'));
  }

  static int _intValue(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static String _stringValue(Map<String, Object?> record, String key) {
    final value = record[key];
    return value?.toString() ?? '';
  }
}
