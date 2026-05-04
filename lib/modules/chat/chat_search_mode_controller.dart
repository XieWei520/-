import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class ChatSearchModeState {
  const ChatSearchModeState({
    this.isActive = false,
    this.anchorOrderSeq = 0,
    this.keyword = '',
  });

  final bool isActive;
  final int anchorOrderSeq;
  final String keyword;

  ChatSearchModeState copyWith({
    bool? isActive,
    int? anchorOrderSeq,
    String? keyword,
  }) {
    return ChatSearchModeState(
      isActive: isActive ?? this.isActive,
      anchorOrderSeq: anchorOrderSeq ?? this.anchorOrderSeq,
      keyword: keyword ?? this.keyword,
    );
  }
}

class ChatSearchModeController extends StateNotifier<ChatSearchModeState> {
  ChatSearchModeController() : super(const ChatSearchModeState());

  void open({required int anchorOrderSeq}) {
    state = state.copyWith(
      isActive: true,
      anchorOrderSeq: anchorOrderSeq,
      keyword: '',
    );
  }

  void updateKeyword(String keyword) {
    state = state.copyWith(keyword: keyword);
  }

  void close() {
    state = state.copyWith(isActive: false);
  }
}
