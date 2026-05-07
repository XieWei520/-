import 'package:wukongimfluttersdk/entity/msg.dart';

import 'web_chat_cache_store.dart';

class MemoryWebChatCacheStore implements WebChatCacheStore {
  MemoryWebChatCacheStore({this.maxMessagesPerChannel = 500});

  final int maxMessagesPerChannel;
  final Map<String, List<WKMsg>> _messagesByPartition = <String, List<WKMsg>>{};

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
    var messages = List<WKMsg>.from(
      _messagesByPartition[_partitionKey(uid, channelId, channelType)] ??
          const <WKMsg>[],
    );
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
    final byMessageKey = <String, WKMsg>{
      for (final message
          in _messagesByPartition[partitionKey] ?? const <WKMsg>[])
        _messageKey(message): message,
    };
    for (final message in messages) {
      if (message.channelID.isEmpty) {
        message.channelID = channelId;
      }
      if (message.channelType == 0) {
        message.channelType = channelType;
      }
      byMessageKey[_messageKey(message)] = message;
    }
    final next = byMessageKey.values.toList(growable: false)
      ..sort(_compareMessages);
    if (next.length > maxMessagesPerChannel) {
      _messagesByPartition[partitionKey] = next.sublist(
        next.length - maxMessagesPerChannel,
      );
      return;
    }
    _messagesByPartition[partitionKey] = next;
  }

  @override
  Future<void> clearUser({required String uid}) async {
    final normalizedUid = uid.trim();
    final prefix = _partitionPrefix(normalizedUid);
    _messagesByPartition.removeWhere((key, _) => key.startsWith(prefix));
  }

  static String _partitionKey(String uid, String channelId, int channelType) {
    return '${_encodeKeyPart(uid)}|$channelType|${_encodeKeyPart(channelId)}';
  }

  static String _partitionPrefix(String uid) {
    return '${_encodeKeyPart(uid)}|';
  }

  static String _encodeKeyPart(String value) {
    return Uri.encodeComponent(value.trim());
  }

  static int _safeLimit(int limit) {
    return limit <= 0 ? 20 : limit;
  }

  static String _messageKey(WKMsg message) {
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

  static int _compareMessages(WKMsg left, WKMsg right) {
    final orderCompare = left.orderSeq.compareTo(right.orderSeq);
    if (orderCompare != 0) {
      return orderCompare;
    }
    final sequenceCompare = left.messageSeq.compareTo(right.messageSeq);
    if (sequenceCompare != 0) {
      return sequenceCompare;
    }
    final leftIdentity = _messageKey(left);
    final rightIdentity = _messageKey(right);
    return leftIdentity.compareTo(rightIdentity);
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
