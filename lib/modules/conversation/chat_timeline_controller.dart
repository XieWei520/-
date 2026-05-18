import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

import '../chat/chat_message_mapper.dart';
import '../chat/chat_message_view_model.dart';
import '../chat/chat_viewport_controller.dart';
import '../chat/chat_viewport_restore_anchor.dart';

class ChatTimelineController extends StateNotifier<ChatViewportState> {
  ChatTimelineController({
    required ChatMessageMapper mapper,
    required String currentUid,
    this.loadOlderAction,
  }) : _mapper = mapper,
       _currentUid = currentUid,
       super(const ChatViewportState());

  final ChatMessageMapper _mapper;
  final String _currentUid;
  final Future<void> Function()? loadOlderAction;

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
    _replace(items, isLoadingMore: false);
  }

  void applyIncoming(Iterable<WKMsg> messages) {
    final baseItems = <ChatMessageViewModel>[...state.items];
    final headItems = <ChatMessageViewModel>[];
    final matchIndex = ChatViewportMessageMatchIndex(baseItems);
    for (final message in messages) {
      final model = _mapper.map(message, currentUid: _currentUid);
      final existingIndex = matchIndex.find(model.message);
      if (existingIndex != -1) {
        if (existingIndex < headItems.length) {
          headItems[existingIndex] = model;
        } else {
          baseItems[existingIndex - headItems.length] = model;
        }
        matchIndex.register(model, existingIndex);
        continue;
      }

      headItems.insert(0, model);
      matchIndex.noteHeadInsertion();
      matchIndex.register(model, 0);
    }
    if (headItems.isEmpty) {
      _replace(baseItems, isLoadingMore: false);
      return;
    }
    _replace(<ChatMessageViewModel>[
      ...headItems,
      ...baseItems,
    ], isLoadingMore: false);
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
    _replace(next, isLoadingMore: false);
  }

  void appendOlder(Iterable<WKMsg> messages) {
    final baseItems = <ChatMessageViewModel>[...state.items];
    final tailItems = <ChatMessageViewModel>[];
    final matchIndex = ChatViewportMessageMatchIndex(baseItems);
    for (final message in messages) {
      final model = _mapper.map(message, currentUid: _currentUid);
      final existingIndex = matchIndex.find(model.message);
      if (existingIndex != -1) {
        if (existingIndex < baseItems.length) {
          baseItems[existingIndex] = model;
        } else {
          tailItems[existingIndex - baseItems.length] = model;
        }
        matchIndex.register(model, existingIndex);
        continue;
      }

      tailItems.add(model);
      matchIndex.register(model, baseItems.length + tailItems.length - 1);
    }
    if (tailItems.isEmpty) {
      _replace(baseItems, isLoadingMore: false);
      return;
    }
    _replace(<ChatMessageViewModel>[
      ...baseItems,
      ...tailItems,
    ], isLoadingMore: false);
  }

  Future<void> loadOlder() async {
    if (state.isLoadingMore) {
      return;
    }
    _setLoadingMore(true);
    try {
      final action = loadOlderAction;
      if (action != null) {
        await action();
      }
    } finally {
      _setLoadingMore(false);
    }
  }

  void _setLoadingMore(bool isLoadingMore) {
    if (!mounted) {
      return;
    }
    if (state.isLoadingMore == isLoadingMore) {
      return;
    }
    state = ChatViewportState(
      items: state.items,
      identities: state.identities,
      identityToIndex: state.identityToIndex,
      isLoadingMore: isLoadingMore,
    );
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

  void _replace(List<ChatMessageViewModel> items, {bool? isLoadingMore}) {
    final identities = _identities(items);
    final keepIdentitySlice = listEquals(identities, state.identities);
    state = ChatViewportState(
      items: items,
      identities: keepIdentitySlice ? state.identities : identities,
      identityToIndex: keepIdentitySlice
          ? state.identityToIndex
          : _index(items),
      isLoadingMore: isLoadingMore ?? state.isLoadingMore,
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

enum ChatTimelineSyncMode { replaceAll, incoming, refresh, olderPage }

@immutable
class ChatTimelineSyncDecision {
  const ChatTimelineSyncDecision._({
    required this.mode,
    this.incoming = const <WKMsg>[],
    this.olderPage = const <WKMsg>[],
    this.refreshed,
  });

  const ChatTimelineSyncDecision.replaceAll()
    : this._(mode: ChatTimelineSyncMode.replaceAll);

  const ChatTimelineSyncDecision.incoming(List<WKMsg> incoming)
    : this._(mode: ChatTimelineSyncMode.incoming, incoming: incoming);

  const ChatTimelineSyncDecision.refresh(WKMsg refreshed)
    : this._(mode: ChatTimelineSyncMode.refresh, refreshed: refreshed);

  const ChatTimelineSyncDecision.olderPage(List<WKMsg> olderPage)
    : this._(mode: ChatTimelineSyncMode.olderPage, olderPage: olderPage);

  final ChatTimelineSyncMode mode;
  final List<WKMsg> incoming;
  final List<WKMsg> olderPage;
  final WKMsg? refreshed;
}

ChatTimelineSyncDecision decideChatTimelineSync({
  required List<WKMsg> previous,
  required List<WKMsg> next,
  required bool initial,
}) {
  if (initial || previous.isEmpty) {
    return const ChatTimelineSyncDecision.replaceAll();
  }

  final incoming = _extractPrependedMessages(previous, next);
  if (incoming != null) {
    return ChatTimelineSyncDecision.incoming(incoming);
  }

  final olderPage = _extractAppendedOlderMessages(previous, next);
  if (olderPage != null) {
    return ChatTimelineSyncDecision.olderPage(olderPage);
  }

  final refreshed = _extractSingleRefreshedMessage(previous, next);
  if (refreshed != null) {
    return ChatTimelineSyncDecision.refresh(refreshed);
  }

  return const ChatTimelineSyncDecision.replaceAll();
}

List<WKMsg>? _extractPrependedMessages(List<WKMsg> previous, List<WKMsg> next) {
  if (next.length <= previous.length) {
    return null;
  }
  final insertedCount = next.length - previous.length;
  for (var i = 0; i < previous.length; i++) {
    if (!ChatViewportMessageMatcher.equivalent(
      previous[i],
      next[i + insertedCount],
    )) {
      return null;
    }
    if (!ChatViewportMessageMatcher.snapshotEquals(
      previous[i],
      next[i + insertedCount],
    )) {
      return null;
    }
  }
  final prepended = next.take(insertedCount).toList(growable: false);
  return prepended.reversed.toList(growable: false);
}

List<WKMsg>? _extractAppendedOlderMessages(
  List<WKMsg> previous,
  List<WKMsg> next,
) {
  if (next.length <= previous.length) {
    return null;
  }
  for (var i = 0; i < previous.length; i++) {
    if (!ChatViewportMessageMatcher.equivalent(previous[i], next[i])) {
      return null;
    }
    if (!ChatViewportMessageMatcher.snapshotEquals(previous[i], next[i])) {
      return null;
    }
  }
  return next.skip(previous.length).toList(growable: false);
}

WKMsg? _extractSingleRefreshedMessage(List<WKMsg> previous, List<WKMsg> next) {
  if (previous.length != next.length) {
    return null;
  }
  WKMsg? changed;
  for (var i = 0; i < previous.length; i++) {
    final current = previous[i];
    final candidate = next[i];
    if (!ChatViewportMessageMatcher.equivalent(current, candidate)) {
      return null;
    }
    if (ChatViewportMessageMatcher.snapshotEquals(current, candidate)) {
      continue;
    }
    if (changed != null) {
      return null;
    }
    changed = candidate;
  }
  return changed;
}
