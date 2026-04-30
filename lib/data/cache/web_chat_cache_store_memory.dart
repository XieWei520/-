import 'package:wukongimfluttersdk/entity/msg.dart';

import 'web_chat_cache_store.dart';

class MemoryWebChatCacheStore implements WebChatCacheStore {
  MemoryWebChatCacheStore({this.maxMessagesPerChannel = 500});

  final int maxMessagesPerChannel;
  final Map<String, List<WKMsg>> _messagesByChannel = <String, List<WKMsg>>{};

  @override
  Future<List<WKMsg>> readMessages({
    required String channelId,
    required int channelType,
    required int limit,
    int beforeOrderSeq = 0,
    int aroundOrderSeq = 0,
  }) async {
    final pageLimit = _safeLimit(limit);
    var messages = List<WKMsg>.from(
      _messagesByChannel[_channelKey(channelId, channelType)] ??
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
    required String channelId,
    required int channelType,
    required List<WKMsg> messages,
  }) async {
    if (messages.isEmpty) {
      return;
    }
    final channelKey = _channelKey(channelId, channelType);
    final byMessageKey = <String, WKMsg>{
      for (final message in _messagesByChannel[channelKey] ?? const <WKMsg>[])
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
      _messagesByChannel[channelKey] = next.sublist(
        next.length - maxMessagesPerChannel,
      );
      return;
    }
    _messagesByChannel[channelKey] = next;
  }

  @override
  Future<void> clearUser({required String uid}) async {
    _messagesByChannel.clear();
  }

  static String _channelKey(String channelId, int channelType) {
    return '$channelType:$channelId';
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
    return 'order:${message.orderSeq}';
  }

  static int _compareMessages(WKMsg left, WKMsg right) {
    final orderCompare = left.orderSeq.compareTo(right.orderSeq);
    if (orderCompare != 0) {
      return orderCompare;
    }
    return left.messageSeq.compareTo(right.messageSeq);
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
