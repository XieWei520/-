class ConversationProjection {
  const ConversationProjection({
    required this.channelId,
    required this.channelType,
    required this.unreadCount,
    required this.sortTimestamp,
    required this.lastMessageDigest,
    this.isTop = false,
    this.isMuted = false,
  });

  final String channelId;
  final int channelType;
  final int unreadCount;
  final int sortTimestamp;
  final String lastMessageDigest;
  final bool isTop;
  final bool isMuted;

  ConversationProjection copyWith({
    int? unreadCount,
    int? sortTimestamp,
    String? lastMessageDigest,
    bool? isTop,
    bool? isMuted,
  }) {
    return ConversationProjection(
      channelId: channelId,
      channelType: channelType,
      unreadCount: unreadCount ?? this.unreadCount,
      sortTimestamp: sortTimestamp ?? this.sortTimestamp,
      lastMessageDigest: lastMessageDigest ?? this.lastMessageDigest,
      isTop: isTop ?? this.isTop,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}

class ConversationPatch {
  const ConversationPatch({
    required this.channelId,
    required this.channelType,
    this.unreadCount,
    this.sortTimestamp,
    this.lastMessageDigest,
    this.isTop,
    this.isMuted,
  });

  const ConversationPatch.unreadAndDigest({
    required String channelId,
    required int channelType,
    required int unreadCount,
    required String lastMessageDigest,
    required int sortTimestamp,
  }) : this(
         channelId: channelId,
         channelType: channelType,
         unreadCount: unreadCount,
         lastMessageDigest: lastMessageDigest,
         sortTimestamp: sortTimestamp,
       );

  const ConversationPatch.flags({
    required String channelId,
    required int channelType,
    required bool isTop,
    required bool isMuted,
  }) : this(
         channelId: channelId,
         channelType: channelType,
         isTop: isTop,
         isMuted: isMuted,
       );

  final String channelId;
  final int channelType;
  final int? unreadCount;
  final int? sortTimestamp;
  final String? lastMessageDigest;
  final bool? isTop;
  final bool? isMuted;

  bool get canBootstrapProjection {
    return unreadCount != null &&
        sortTimestamp != null &&
        lastMessageDigest != null;
  }

  ConversationProjection toBootstrapProjection() {
    if (!canBootstrapProjection) {
      throw StateError(
        'ConversationPatch lacks required fields for projection bootstrap.',
      );
    }

    return ConversationProjection(
      channelId: channelId,
      channelType: channelType,
      unreadCount: unreadCount!,
      sortTimestamp: sortTimestamp!,
      lastMessageDigest: lastMessageDigest!,
      isTop: isTop ?? false,
      isMuted: isMuted ?? false,
    );
  }
}

int compareConversationProjection(
  ConversationProjection left,
  ConversationProjection right,
) {
  if (left.isTop != right.isTop) {
    return left.isTop ? -1 : 1;
  }

  final timestampCompare = right.sortTimestamp.compareTo(left.sortTimestamp);
  if (timestampCompare != 0) {
    return timestampCompare;
  }

  final channelTypeCompare = left.channelType.compareTo(right.channelType);
  if (channelTypeCompare != 0) {
    return channelTypeCompare;
  }

  return left.channelId.compareTo(right.channelId);
}
