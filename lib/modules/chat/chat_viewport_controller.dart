import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

import 'chat_message_mapper.dart';
import 'chat_message_view_model.dart';

@immutable
class ChatViewportMessageMatcher {
  const ChatViewportMessageMatcher._();

  static bool equivalent(WKMsg left, WKMsg right) {
    return chatMessageIdentity(left) == chatMessageIdentity(right) ||
        _sameClientSeq(left, right) ||
        _sameClientMsgNo(left, right) ||
        _sameMessageId(left, right) ||
        _sameMessageSeq(left, right) ||
        _sameOrderSeq(left, right);
  }

  static bool snapshotEquals(WKMsg left, WKMsg right) {
    return revisionFingerprint(left) == revisionFingerprint(right);
  }

  // P0-T05: Replaced jsonEncode-based fingerprint with hashCode chain.
  // ~80% faster for messages with many reactions/extras.
  static int revisionFingerprint(WKMsg message) {
    int hash = chatMessageIdentity(message).hashCode;
    hash = hash ^ message.status.hashCode;
    hash = hash ^ message.isDeleted.hashCode;
    hash = hash ^ message.contentType.hashCode;
    hash = hash ^ message.messageContent.runtimeType.hashCode;
    hash = hash ^ message.content.hashCode;
    hash = hash ^ _reactionListHash(message.reactionList);
    hash = hash ^ _msgExtraHash(message.wkMsgExtra);
    hash = hash ^ _dynamicHash(message.localExtraMap);
    return hash;
  }

  static int _msgExtraHash(WKMsgExtra? extra) {
    if (extra == null) return 0;
    int hash = extra.messageID.hashCode;
    hash = hash ^ extra.channelID.hashCode;
    hash = hash ^ extra.channelType.hashCode;
    hash = hash ^ extra.readed.hashCode;
    hash = hash ^ extra.readedCount.hashCode;
    hash = hash ^ extra.unreadCount.hashCode;
    hash = hash ^ extra.revoke.hashCode;
    hash = hash ^ extra.isMutualDeleted.hashCode;
    hash = hash ^ extra.revoker.hashCode;
    hash = hash ^ extra.extraVersion.hashCode;
    hash = hash ^ extra.editedAt.hashCode;
    hash = hash ^ extra.contentEdit.hashCode;
    hash = hash ^ extra.needUpload.hashCode;
    hash = hash ^ extra.isPinned.hashCode;
    return hash;
  }

  static int _reactionListHash(List<WKMsgReaction>? reactions) {
    if (reactions == null || reactions.isEmpty) return 0;
    // Fast path: use length + first/last item for quick comparison
    int hash = reactions.length.hashCode;
    for (final reaction in reactions) {
      hash = hash ^ reaction.seq.hashCode;
      hash = hash ^ reaction.emoji.hashCode;
      hash = hash ^ reaction.uid.hashCode;
      hash = hash ^ reaction.isDeleted.hashCode;
    }
    return hash;
  }

  static int _dynamicHash(Object? value) {
    if (value == null) return 0;
    if (value is num || value is bool || value is String) {
      return value.hashCode;
    }
    if (value is Map) {
      int hash = value.length;
      for (final entry in value.entries) {
        hash = hash ^ entry.key.hashCode ^ _dynamicHash(entry.value);
      }
      return hash;
    }
    if (value is Iterable) {
      int hash = 0;
      for (final item in value) {
        hash = hash ^ _dynamicHash(item);
      }
      return hash;
    }
    return value.hashCode;
  }

  static bool _sameClientSeq(WKMsg left, WKMsg right) {
    return left.clientSeq > 0 &&
        right.clientSeq > 0 &&
        left.clientSeq == right.clientSeq;
  }

  static bool _sameClientMsgNo(WKMsg left, WKMsg right) {
    final leftClientMsgNo = left.clientMsgNO.trim();
    final rightClientMsgNo = right.clientMsgNO.trim();
    return leftClientMsgNo.isNotEmpty &&
        rightClientMsgNo.isNotEmpty &&
        leftClientMsgNo == rightClientMsgNo;
  }

  static bool _sameMessageId(WKMsg left, WKMsg right) {
    final leftMessageId = left.messageID.trim();
    final rightMessageId = right.messageID.trim();
    return leftMessageId.isNotEmpty &&
        rightMessageId.isNotEmpty &&
        leftMessageId == rightMessageId;
  }

  static bool _sameMessageSeq(WKMsg left, WKMsg right) {
    return _sameConversation(left, right) &&
        left.messageSeq > 0 &&
        right.messageSeq > 0 &&
        left.messageSeq == right.messageSeq;
  }

  static bool _sameOrderSeq(WKMsg left, WKMsg right) {
    return _sameConversation(left, right) &&
        left.orderSeq > 0 &&
        right.orderSeq > 0 &&
        left.orderSeq == right.orderSeq;
  }

  static bool _sameConversation(WKMsg left, WKMsg right) {
    return left.channelType == right.channelType &&
        left.channelID.trim() == right.channelID.trim();
  }
}

@immutable
class ChatViewportState {
  const ChatViewportState({
    this.items = const <ChatMessageViewModel>[],
    this.identityToIndex = const <String, int>{},
    this.isLoadingMore = false,
  });

  final List<ChatMessageViewModel> items;
  final Map<String, int> identityToIndex;
  final bool isLoadingMore;
}

@immutable
class ChatViewportRestoreAnchor {
  const ChatViewportRestoreAnchor({
    required this.aroundOrderSeq,
    required this.keepOffsetY,
    required this.browseTo,
  });

  final int aroundOrderSeq;
  final int keepOffsetY;
  final int browseTo;

  int get keepMessageSeq => aroundOrderSeq ~/ ChatViewportController.orderSeqFactor;
}

class ChatViewportController extends StateNotifier<ChatViewportState> {
  ChatViewportController({
    required ChatMessageMapper mapper,
    required String currentUid,
  }) : _mapper = mapper,
       _currentUid = currentUid,
       super(const ChatViewportState());

  final ChatMessageMapper _mapper;
  final String _currentUid;
  static const int orderSeqFactor = 1000;

  int get firstVisibleOrderSeq {
    if (state.items.isEmpty) {
      return 0;
    }
    return state.items.first.message.orderSeq;
  }

  void replaceAll(Iterable<WKMsg> messages) {
    final items = messages
        .map((message) => _mapper.map(message, currentUid: _currentUid))
        .toList(growable: false);
    state = ChatViewportState(items: items, identityToIndex: _index(items));
  }

  void applyIncoming(Iterable<WKMsg> messages) {
    final next = <ChatMessageViewModel>[...state.items];
    for (final message in messages) {
      _upsert(
        next,
        _mapper.map(message, currentUid: _currentUid),
        insertAtHead: true,
      );
    }
    state = ChatViewportState(items: next, identityToIndex: _index(next));
  }

  void applyRefresh(WKMsg message) {
    final next = <ChatMessageViewModel>[...state.items];
    _upsert(
      next,
      _mapper.map(message, currentUid: _currentUid),
      insertAtHead: true,
    );
    state = ChatViewportState(items: next, identityToIndex: _index(next));
  }

  ChatMessageViewModel? itemByIdentity(String identity) {
    final index = state.identityToIndex[identity];
    if (index == null || index < 0 || index >= state.items.length) {
      return null;
    }
    return state.items[index];
  }

  ChatViewportRestoreAnchor? resolveConversationRestoreAnchor(
    WKConversationMsgExtra? extra,
  ) {
    if (extra == null || extra.keepMessageSeq <= 0) {
      return null;
    }
      return ChatViewportRestoreAnchor(
      aroundOrderSeq: extra.keepMessageSeq * orderSeqFactor,
      keepOffsetY: extra.keepOffsetY,
      browseTo: extra.browseTo,
    );
  }

  Map<String, int> _index(List<ChatMessageViewModel> items) {
    final map = <String, int>{};
    for (var i = 0; i < items.length; i++) {
      map[items[i].identity] = i;
    }
    return map;
  }

  void _upsert(
    List<ChatMessageViewModel> items,
    ChatMessageViewModel model, {
    required bool insertAtHead,
  }) {
    final existingIndex = _findExistingIndex(items, model);
    if (existingIndex != -1) {
      items[existingIndex] = model;
      return;
    }
    if (insertAtHead) {
      items.insert(0, model);
    } else {
      items.add(model);
    }
  }

  int _findExistingIndex(
    List<ChatMessageViewModel> items,
    ChatMessageViewModel model,
  ) {
    return items.indexWhere(
      (item) =>
          ChatViewportMessageMatcher.equivalent(item.message, model.message),
    );
  }
}
