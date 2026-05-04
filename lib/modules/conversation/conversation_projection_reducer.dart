import 'conversation_projection.dart';

class ConversationProjectionReducer {
  const ConversationProjectionReducer();

  List<ConversationProjection> reduce(
    List<ConversationProjection> current,
    ConversationPatch patch,
  ) {
    final next = [...current];
    final index = next.indexWhere(
      (item) =>
          item.channelId == patch.channelId &&
          item.channelType == patch.channelType,
    );
    if (index < 0) {
      next.sort(compareConversationProjection);
      return next;
    }

    next[index] = next[index].copyWith(
      unreadCount: patch.unreadCount,
      sortTimestamp: patch.sortTimestamp,
      lastMessageDigest: patch.lastMessageDigest,
      isTop: patch.isTop,
      isMuted: patch.isMuted,
    );
    next.sort(compareConversationProjection);
    return next;
  }
}
