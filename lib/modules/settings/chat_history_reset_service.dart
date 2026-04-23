import 'package:flutter/foundation.dart';

@immutable
class ChatHistoryTarget {
  const ChatHistoryTarget({required this.channelId, required this.channelType});

  final String channelId;
  final int channelType;
}

class ChatHistoryResetService {
  const ChatHistoryResetService({
    required this.loadTargets,
    required this.clearChannelMessages,
    required this.clearAllConversations,
  });

  final Future<List<ChatHistoryTarget>> Function() loadTargets;
  final Future<void> Function(String channelId, int channelType)
  clearChannelMessages;
  final Future<void> Function() clearAllConversations;

  Future<void> clearAll() async {
    final targets = await loadTargets();
    for (final target in targets) {
      await clearChannelMessages(target.channelId, target.channelType);
    }
    await clearAllConversations();
  }
}
