import 'chat_conversation_extra_gateway.dart';
import 'chat_viewport_controller.dart';
import 'chat_viewport_models.dart';
import 'chat_viewport_restore_anchor.dart';

class ChatConversationRestoreService {
  ChatViewportPersistenceSnapshot _latestViewportSnapshot =
      const ChatViewportPersistenceSnapshot();
  int _browseTo = 0;
  bool _didPersistConversationExtra = false;

  int get browseTo => _browseTo;

  bool get hasPersisted => _didPersistConversationExtra;

  ChatViewportPersistenceSnapshot get latestViewportSnapshot =>
      _latestViewportSnapshot;

  void recordRestoredBrowseTo(int browseTo) {
    _browseTo = browseTo;
  }

  void recordViewportSnapshot(ChatViewportPersistenceSnapshot snapshot) {
    _latestViewportSnapshot = snapshot;
    if (snapshot.maxVisibleMessageSeq > _browseTo) {
      _browseTo = snapshot.maxVisibleMessageSeq;
    }
  }

  Future<ChatViewportRestoreAnchor?> resolveRestoreAnchor({
    required ChatConversationExtraGateway gateway,
    required String channelId,
    required int channelType,
  }) async {
    try {
      final extra = await gateway.load(
        channelId: channelId,
        channelType: channelType,
      );
      if (extra == null) {
        return null;
      }
      recordRestoredBrowseTo(extra.browseTo);
      return restoreAnchorFromConversationExtra(extra);
    } catch (_) {
      return null;
    }
  }

  Future<void> persist({
    required ChatConversationExtraGateway gateway,
    required String channelId,
    required int channelType,
    required String draft,
  }) async {
    if (_didPersistConversationExtra) {
      return;
    }
    final browseTo = _browseTo > _latestViewportSnapshot.maxVisibleMessageSeq
        ? _browseTo
        : _latestViewportSnapshot.maxVisibleMessageSeq;
    if (draft.trim().isEmpty &&
        browseTo <= 0 &&
        _latestViewportSnapshot.keepMessageSeq <= 0 &&
        _latestViewportSnapshot.keepOffsetY == 0) {
      return;
    }
    _didPersistConversationExtra = true;

    try {
      await gateway.save(
        channelId: channelId,
        channelType: channelType,
        browseTo: browseTo,
        keepMessageSeq: _latestViewportSnapshot.keepMessageSeq,
        keepOffsetY: _latestViewportSnapshot.keepOffsetY,
        draft: draft,
      );
    } catch (_) {
      // Conversation extra persistence is best-effort on exit.
    }
  }
}
