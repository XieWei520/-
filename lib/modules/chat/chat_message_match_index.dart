import 'package:wukongimfluttersdk/entity/msg.dart';

class ChatMessageMatchIndex {
  ChatMessageMatchIndex(Iterable<WKMsg> messages) {
    var index = 0;
    for (final message in messages) {
      indexMessage(message, index);
      index++;
    }
  }

  ChatMessageMatchIndex.empty();

  final Map<int, int> _clientSeqToIndex = <int, int>{};
  final Map<String, int> _clientMsgNoToIndex = <String, int>{};
  final Map<String, int> _messageIdToIndex = <String, int>{};
  final Map<_ScopedSequenceKey, int> _messageSeqToIndex =
      <_ScopedSequenceKey, int>{};
  final Map<_ScopedSequenceKey, int> _orderSeqToIndex =
      <_ScopedSequenceKey, int>{};

  static int findMessageIndex(Iterable<WKMsg> messages, WKMsg target) {
    return ChatMessageMatchIndex(messages).find(target);
  }

  int find(WKMsg target) {
    final clientSeq = target.clientSeq;
    if (clientSeq > 0) {
      final index = _clientSeqToIndex[clientSeq];
      if (index != null) {
        return index;
      }
    }

    final clientMsgNo = _trimmedNonEmpty(target.clientMsgNO);
    if (clientMsgNo != null) {
      final index = _clientMsgNoToIndex[clientMsgNo];
      if (index != null) {
        return index;
      }
    }

    final messageId = _trimmedNonEmpty(target.messageID);
    if (messageId != null) {
      final index = _messageIdToIndex[messageId];
      if (index != null) {
        return index;
      }
    }

    final messageSeqKey = _scopedSequenceKey(target, target.messageSeq);
    if (messageSeqKey != null) {
      final index = _messageSeqToIndex[messageSeqKey];
      if (index != null) {
        return index;
      }
    }

    final orderSeqKey = _scopedSequenceKey(target, target.orderSeq);
    if (orderSeqKey != null) {
      final index = _orderSeqToIndex[orderSeqKey];
      if (index != null) {
        return index;
      }
    }

    return -1;
  }

  static bool equivalent(WKMsg left, WKMsg right) {
    if (left.clientSeq > 0 &&
        right.clientSeq > 0 &&
        left.clientSeq == right.clientSeq) {
      return true;
    }

    final leftClientMsgNo = _trimmedNonEmpty(left.clientMsgNO);
    final rightClientMsgNo = _trimmedNonEmpty(right.clientMsgNO);
    if (leftClientMsgNo != null &&
        rightClientMsgNo != null &&
        leftClientMsgNo == rightClientMsgNo) {
      return true;
    }

    final leftMessageId = _trimmedNonEmpty(left.messageID);
    final rightMessageId = _trimmedNonEmpty(right.messageID);
    if (leftMessageId != null &&
        rightMessageId != null &&
        leftMessageId == rightMessageId) {
      return true;
    }

    final leftMessageSeqKey = _scopedSequenceKey(left, left.messageSeq);
    final rightMessageSeqKey = _scopedSequenceKey(right, right.messageSeq);
    if (leftMessageSeqKey != null &&
        rightMessageSeqKey != null &&
        leftMessageSeqKey == rightMessageSeqKey) {
      return true;
    }

    final leftOrderSeqKey = _scopedSequenceKey(left, left.orderSeq);
    final rightOrderSeqKey = _scopedSequenceKey(right, right.orderSeq);
    return leftOrderSeqKey != null &&
        rightOrderSeqKey != null &&
        leftOrderSeqKey == rightOrderSeqKey;
  }

  void indexMessage(WKMsg message, int index) {
    final clientSeq = message.clientSeq;
    if (clientSeq > 0) {
      _clientSeqToIndex.putIfAbsent(clientSeq, () => index);
    }

    final clientMsgNo = _trimmedNonEmpty(message.clientMsgNO);
    if (clientMsgNo != null) {
      _clientMsgNoToIndex.putIfAbsent(clientMsgNo, () => index);
    }

    final messageId = _trimmedNonEmpty(message.messageID);
    if (messageId != null) {
      _messageIdToIndex.putIfAbsent(messageId, () => index);
    }

    final messageSeqKey = _scopedSequenceKey(message, message.messageSeq);
    if (messageSeqKey != null) {
      _messageSeqToIndex.putIfAbsent(messageSeqKey, () => index);
    }

    final orderSeqKey = _scopedSequenceKey(message, message.orderSeq);
    if (orderSeqKey != null) {
      _orderSeqToIndex.putIfAbsent(orderSeqKey, () => index);
    }
  }

  void shiftIndexesAtOrAfter(int insertionIndex) {
    _shiftIndexes(_clientSeqToIndex, insertionIndex);
    _shiftIndexes(_clientMsgNoToIndex, insertionIndex);
    _shiftIndexes(_messageIdToIndex, insertionIndex);
    _shiftIndexes(_messageSeqToIndex, insertionIndex);
    _shiftIndexes(_orderSeqToIndex, insertionIndex);
  }

  static void _shiftIndexes<K>(Map<K, int> index, int insertionIndex) {
    index.updateAll((_, value) => value >= insertionIndex ? value + 1 : value);
  }

  static String? _trimmedNonEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static _ScopedSequenceKey? _scopedSequenceKey(WKMsg message, int sequence) {
    if (sequence <= 0) {
      return null;
    }
    final channelId = _trimmedNonEmpty(message.channelID);
    if (channelId == null) {
      return null;
    }
    return _ScopedSequenceKey(message.channelType, channelId, sequence);
  }
}

class _ScopedSequenceKey {
  const _ScopedSequenceKey(this.channelType, this.channelId, this.sequence);

  final int channelType;
  final String channelId;
  final int sequence;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _ScopedSequenceKey &&
            other.channelType == channelType &&
            other.channelId == channelId &&
            other.sequence == sequence;
  }

  @override
  int get hashCode => Object.hash(channelType, channelId, sequence);
}
