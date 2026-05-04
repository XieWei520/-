import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class ChatSelectionState {
  ChatSelectionState({
    Set<String> selectedIdentities = const <String>{},
  }) : selectedIdentities = Set<String>.unmodifiable(selectedIdentities);

  final Set<String> selectedIdentities;

  bool get canForward => selectedIdentities.isNotEmpty;
  bool get canFavorite => selectedIdentities.length == 1;
  int get selectedCount => selectedIdentities.length;

  ChatSelectionState copyWith({
    Set<String>? selectedIdentities,
  }) {
    return ChatSelectionState(
      selectedIdentities: selectedIdentities ?? this.selectedIdentities,
    );
  }
}

class ChatSelectionController extends StateNotifier<ChatSelectionState> {
  ChatSelectionController() : super(ChatSelectionState());

  void seed(String identity) {
    state = state.copyWith(selectedIdentities: <String>{identity});
  }

  void toggle(String identity) {
    final next = <String>{...state.selectedIdentities};
    if (!next.add(identity)) {
      next.remove(identity);
    }
    state = state.copyWith(selectedIdentities: next);
  }

  void clear() {
    state = ChatSelectionState();
  }
}
