import 'dart:collection';

import 'conversation_projection.dart';
import 'conversation_projection_reducer.dart';

class ConversationProjectionRepository {
  ConversationProjectionRepository(this._reducer);

  final ConversationProjectionReducer _reducer;
  List<ConversationProjection> _snapshot = const [];
  final Map<String, List<ConversationPatch>> _pendingPatches = {};
  bool _hasSeeded = false;

  List<ConversationProjection> get snapshot => UnmodifiableListView(_snapshot);

  void seed(List<ConversationProjection> initial) {
    _snapshot = [...initial]..sort(compareConversationProjection);
    _hasSeeded = true;
    _replayPendingPatches();
  }

  void apply(ConversationPatch patch) {
    if (!_containsConversation(patch.channelId, patch.channelType)) {
      if (_hasSeeded && patch.canBootstrapProjection) {
        _bootstrapFromPatch(patch);
        return;
      }
      _enqueuePendingPatch(patch);
      return;
    }
    _snapshot = _reducer.reduce(_snapshot, patch);
  }

  bool _containsConversation(String channelId, int channelType) {
    return _snapshot.any(
      (item) => item.channelId == channelId && item.channelType == channelType,
    );
  }

  void _enqueuePendingPatch(ConversationPatch patch) {
    final key = _conversationKey(patch.channelId, patch.channelType);
    (_pendingPatches[key] ??= <ConversationPatch>[]).add(patch);
  }

  void _replayPendingPatches() {
    if (_pendingPatches.isEmpty) {
      return;
    }

    final queue = _pendingPatches.values
        .expand((patches) => patches)
        .toList(growable: false);
    _pendingPatches.clear();
    for (final patch in queue) {
      apply(patch);
    }
  }

  void _bootstrapFromPatch(ConversationPatch patch) {
    final key = _conversationKey(patch.channelId, patch.channelType);
    final pendingForKey =
        _pendingPatches.remove(key) ?? const <ConversationPatch>[];

    _snapshot = [..._snapshot, patch.toBootstrapProjection()]
      ..sort(compareConversationProjection);

    for (final pendingPatch in pendingForKey) {
      _snapshot = _reducer.reduce(_snapshot, pendingPatch);
    }

    _snapshot = _reducer.reduce(_snapshot, patch);
  }

  String _conversationKey(String channelId, int channelType) {
    return '$channelType:$channelId';
  }
}
