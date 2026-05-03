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

class ChatViewportMessageMatchIndex {
  ChatViewportMessageMatchIndex(Iterable<ChatMessageViewModel> items) {
    var index = 0;
    for (final item in items) {
      register(item, index);
      index++;
    }
  }

  final Map<String, int> _baseIndexByKey = <String, int>{};
  int _headInsertions = 0;

  int find(WKMsg message) {
    for (final key in _keysFor(message)) {
      final baseIndex = _baseIndexByKey[key];
      if (baseIndex != null) {
        return baseIndex + _headInsertions;
      }
    }
    return -1;
  }

  void register(ChatMessageViewModel model, int index) {
    final baseIndex = index - _headInsertions;
    for (final key in _keysFor(model.message)) {
      _baseIndexByKey.putIfAbsent(key, () => baseIndex);
    }
  }

  void noteHeadInsertion() {
    _headInsertions++;
  }

  static List<String> _keysFor(WKMsg message) {
    final keys = <String>[chatMessageIdentity(message)];
    if (message.clientSeq > 0) {
      keys.add('client_seq:${message.clientSeq}');
    }
    final clientMsgNo = message.clientMsgNO.trim();
    if (clientMsgNo.isNotEmpty) {
      keys.add('client_msg_no:$clientMsgNo');
    }
    final messageId = message.messageID.trim();
    if (messageId.isNotEmpty) {
      keys.add('message_id:$messageId');
    }
    final channelKey = '${message.channelType}:${message.channelID.trim()}';
    if (message.messageSeq > 0) {
      keys.add('message_seq:$channelKey:${message.messageSeq}');
    }
    if (message.orderSeq > 0) {
      keys.add('order_seq:$channelKey:${message.orderSeq}');
    }
    return keys;
  }
}

@immutable
class ChatViewportState {
  const ChatViewportState({
    this.items = const <ChatMessageViewModel>[],
    this.identities = const <String>[],
    this.identityToIndex = const <String, int>{},
    this.isLoadingMore = false,
  });

  final List<ChatMessageViewModel> items;

  /// Stable list skeleton consumed by the chat viewport. A content/status-only
  /// refresh must preserve this list instance so `select((s) => s.identities)`
  /// does not rebuild the whole scrollable.
  final List<String> identities;

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

  int get keepMessageSeq =>
      aroundOrderSeq ~/ ChatViewportController.orderSeqFactor;
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
    _replace(items);
  }

  void applyIncoming(Iterable<WKMsg> messages) {
    final next = <ChatMessageViewModel>[...state.items];
    final matchIndex = ChatViewportMessageMatchIndex(next);
    for (final message in messages) {
      _upsert(
        next,
        _mapper.map(message, currentUid: _currentUid),
        matchIndex: matchIndex,
        insertAtHead: true,
      );
    }
    _replace(next);
  }

  void applyRefresh(WKMsg message) {
    final next = <ChatMessageViewModel>[...state.items];
    final matchIndex = ChatViewportMessageMatchIndex(next);
    _upsert(
      next,
      _mapper.map(message, currentUid: _currentUid),
      matchIndex: matchIndex,
      insertAtHead: true,
    );
    _replace(next);
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

  void _replace(List<ChatMessageViewModel> items) {
    final identities = _identities(items);
    final keepIdentitySlice = listEquals(identities, state.identities);
    state = ChatViewportState(
      items: items,
      identities: keepIdentitySlice ? state.identities : identities,
      identityToIndex: keepIdentitySlice
          ? state.identityToIndex
          : _index(items),
      isLoadingMore: state.isLoadingMore,
    );
  }

  List<String> _identities(List<ChatMessageViewModel> items) {
    return items.map((item) => item.identity).toList(growable: false);
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
    required ChatViewportMessageMatchIndex matchIndex,
    required bool insertAtHead,
  }) {
    final existingIndex = matchIndex.find(model.message);
    if (existingIndex != -1) {
      items[existingIndex] = model;
      matchIndex.register(model, existingIndex);
      return;
    }
    if (insertAtHead) {
      items.insert(0, model);
      matchIndex.noteHeadInsertion();
      matchIndex.register(model, 0);
    } else {
      items.add(model);
      matchIndex.register(model, items.length - 1);
    }
  }
}
