import 'package:flutter/foundation.dart';

enum ChatSceneMode { normal, replying, selecting, searching }

@immutable
class ChatSceneState {
  const ChatSceneState({
    this.mode = ChatSceneMode.normal,
    this.actionMessageIdentity,
    this.selectionSeedIdentity,
    this.searchAnchorOrderSeq = 0,
    this.searchKeyword = '',
  });

  final ChatSceneMode mode;
  final String? actionMessageIdentity;
  final String? selectionSeedIdentity;
  final int searchAnchorOrderSeq;
  final String searchKeyword;

  ChatSceneState copyWith({
    ChatSceneMode? mode,
    String? actionMessageIdentity,
    bool clearActionMessageIdentity = false,
    String? selectionSeedIdentity,
    bool clearSelectionSeedIdentity = false,
    int? searchAnchorOrderSeq,
    String? searchKeyword,
  }) {
    return ChatSceneState(
      mode: mode ?? this.mode,
      actionMessageIdentity: clearActionMessageIdentity
          ? null
          : (actionMessageIdentity ?? this.actionMessageIdentity),
      selectionSeedIdentity: clearSelectionSeedIdentity
          ? null
          : (selectionSeedIdentity ?? this.selectionSeedIdentity),
      searchAnchorOrderSeq: searchAnchorOrderSeq ?? this.searchAnchorOrderSeq,
      searchKeyword: searchKeyword ?? this.searchKeyword,
    );
  }
}
