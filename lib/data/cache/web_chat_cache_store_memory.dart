import 'package:wukongimfluttersdk/entity/msg.dart';

import 'web_chat_cache_store.dart';

class MemoryWebChatCacheStore implements WebChatCacheStore {
  MemoryWebChatCacheStore({this.maxMessagesPerChannel = 2000});

  final int maxMessagesPerChannel;
  final Map<String, List<Map<String, Object?>>> _recordsByPartition = {};

  @override
  Future<List<WKMsg>> readMessages({
    required String channelId,
    required int channelType,
    required int limit,
    String uid = '',
    int beforeOrderSeq = 0,
    int aroundOrderSeq = 0,
  }) async {
    final records = List<Map<String, Object?>>.from(
      _recordsByPartition[_partitionKey(uid, channelId, channelType)] ??
          const <Map<String, Object?>>[],
    )..sort(_compareRecords);

    final pageLimit = _safeLimit(limit);
    if (beforeOrderSeq > 0) {
      final filtered = records
          .where((record) => _intValue(record, 'orderSeq') < beforeOrderSeq)
          .toList(growable: false);
      return _pageLatest(
        filtered,
        pageLimit,
      ).map((record) => _messageFromRecord(record)).toList(growable: false);
    }
    if (aroundOrderSeq > 0) {
      return _windowAround(
        records,
        aroundOrderSeq,
        pageLimit,
      ).map((record) => _messageFromRecord(record)).toList(growable: false);
    }
    return _pageLatest(
      records,
      pageLimit,
    ).map((record) => _messageFromRecord(record)).toList(growable: false);
  }

  @override
  Future<void> upsertMessages({
    required String channelId,
    required int channelType,
    required List<WKMsg> messages,
    String uid = '',
  }) async {
    if (messages.isEmpty) {
      return;
    }

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
    _recordsByPartition[partitionKey] = next.length > maxMessagesPerChannel
        ? next.sublist(next.length - maxMessagesPerChannel)
        : next;
  }

  @override
  Future<void> clearUser({required String uid}) async {
    _recordsByPartition.removeWhere(
      (partitionKey, _) =>
          uid.isEmpty ||
          partitionKey.startsWith('$uid::') ||
          partitionKey.startsWith('::'),
    );
  }

  static String _partitionKey(String uid, String channelId, int channelType) {
    return '$uid::$channelType:$channelId';
  }

  static int _safeLimit(int limit) {
    return limit <= 0 ? 20 : limit;
  }

  static Map<String, Object?> _normalizeMessage(
    WKMsg message, {
    required String uid,
    required String channelId,
    required int channelType,
  }) {
    final next = <String, Object?>{
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
    return next;
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

  static List<Map<String, Object?>> _pageLatest(
    List<Map<String, Object?>> records,
    int limit,
  ) {
    if (records.length <= limit) {
      return records;
    }
    return records.sublist(records.length - limit);
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
