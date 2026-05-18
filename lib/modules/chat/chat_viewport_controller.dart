import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

import 'chat_message_mapper.dart';
import 'chat_message_match_index.dart';
import 'chat_message_view_model.dart';
import 'chat_viewport_restore_anchor.dart';

@immutable
class ChatViewportMessageMatcher {
  const ChatViewportMessageMatcher._();

  static bool equivalent(WKMsg left, WKMsg right) {
    return chatMessageIdentity(left) == chatMessageIdentity(right) ||
        ChatMessageMatchIndex.equivalent(left, right);
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
}

class ChatViewportMessageMatchIndex {
  ChatViewportMessageMatchIndex(Iterable<ChatMessageViewModel> items)
    : _messageIndex = ChatMessageMatchIndex.empty() {
    var index = 0;
    for (final item in items) {
      _indexAt(item, index);
      index++;
    }
  }

  final Map<String, int> _identityToIndex = <String, int>{};
  final ChatMessageMatchIndex _messageIndex;

  int find(WKMsg message) {
    final identityIndex = _identityToIndex[chatMessageIdentity(message)];
    if (identityIndex != null) {
      return identityIndex;
    }
    return _messageIndex.find(message);
  }

  void register(ChatMessageViewModel model, int index) {
    _indexAt(model, index);
  }

  void noteHeadInsertion() {
    shiftIndexesAtOrAfter(0);
  }

  void shiftIndexesAtOrAfter(int insertionIndex) {
    _identityToIndex.updateAll(
      (_, value) => value >= insertionIndex ? value + 1 : value,
    );
    _messageIndex.shiftIndexesAtOrAfter(insertionIndex);
  }

  void _indexAt(ChatMessageViewModel model, int index) {
    _identityToIndex[model.identity] = index;
    _messageIndex.indexMessage(model.message, index);
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
    return restoreAnchorFromConversationExtra(extra);
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
