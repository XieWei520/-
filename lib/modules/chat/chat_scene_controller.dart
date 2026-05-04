import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_scene_models.dart';

class ChatSceneController extends StateNotifier<ChatSceneState> {
  ChatSceneController({
    VoidCallback? onLeaveReplyMode,
    VoidCallback? onLeaveSelectionMode,
    VoidCallback? onLeaveSearchMode,
  }) : _onLeaveReplyMode = onLeaveReplyMode,
       _onLeaveSelectionMode = onLeaveSelectionMode,
       _onLeaveSearchMode = onLeaveSearchMode,
       super(const ChatSceneState());

  final VoidCallback? _onLeaveReplyMode;
  final VoidCallback? _onLeaveSelectionMode;
  final VoidCallback? _onLeaveSearchMode;

  void showActionMenuFor(String messageIdentity) {
    state = state.copyWith(actionMessageIdentity: messageIdentity);
  }

  void closeActionMenu() {
    state = state.copyWith(clearActionMessageIdentity: true);
  }

  void enterReplyMode() {
    _leaveCurrentModeIfSwitchingTo(ChatSceneMode.replying);
    state = state.copyWith(
      mode: ChatSceneMode.replying,
      clearActionMessageIdentity: true,
      clearSelectionSeedIdentity: true,
      searchAnchorOrderSeq: 0,
      searchKeyword: '',
    );
  }

  void enterSelectionMode({String? seedIdentity}) {
    _leaveCurrentModeIfSwitchingTo(ChatSceneMode.selecting);
    state = state.copyWith(
      mode: ChatSceneMode.selecting,
      clearActionMessageIdentity: true,
      selectionSeedIdentity: seedIdentity,
      searchAnchorOrderSeq: 0,
      searchKeyword: '',
    );
  }

  void enterSearchMode({
    required int anchorOrderSeq,
    String initialKeyword = '',
  }) {
    _leaveCurrentModeIfSwitchingTo(ChatSceneMode.searching);
    state = state.copyWith(
      mode: ChatSceneMode.searching,
      clearActionMessageIdentity: true,
      clearSelectionSeedIdentity: true,
      searchAnchorOrderSeq: anchorOrderSeq,
      searchKeyword: initialKeyword,
    );
  }

  void updateSearchKeyword(String keyword) {
    if (state.mode != ChatSceneMode.searching) {
      return;
    }
    state = state.copyWith(searchKeyword: keyword);
  }

  void restoreNormal() {
    _leaveCurrentModeIfSwitchingTo(ChatSceneMode.normal);
    state = state.copyWith(
      mode: ChatSceneMode.normal,
      clearActionMessageIdentity: true,
      clearSelectionSeedIdentity: true,
      searchAnchorOrderSeq: 0,
      searchKeyword: '',
    );
  }

  void _leaveCurrentModeIfSwitchingTo(ChatSceneMode nextMode) {
    if (state.mode == nextMode) {
      return;
    }
    _invokeLeaveHookFor(state.mode);
  }

  void _invokeLeaveHookFor(ChatSceneMode mode) {
    switch (mode) {
      case ChatSceneMode.normal:
        return;
      case ChatSceneMode.replying:
        _onLeaveReplyMode?.call();
        return;
      case ChatSceneMode.selecting:
        _onLeaveSelectionMode?.call();
        return;
      case ChatSceneMode.searching:
        _onLeaveSearchMode?.call();
        return;
    }
  }
}
