/// Chat view menu
/// 
/// Used to navigate to chat page with channel info
class ChatViewMenu {
  /// Channel ID
  final String channelId;

  /// Channel type (0=p2p, 1=group)
  final int channelType;

  /// Tip message order seq (>0 needs strong reminder, =0 normal entry)
  final int tipMsgOrderSeq;

  /// Whether to open as new task
  final bool isNewTask;

  /// Forward message list (optional)
  final List<dynamic>? forwardMsgList;

  ChatViewMenu({
    required this.channelId,
    required this.channelType,
    this.tipMsgOrderSeq = 0,
    this.isNewTask = false,
    this.forwardMsgList,
  });
}

/// Conversation context interface
/// 
/// Used for message sending context
abstract class IConversationContext {
  /// Get channel ID
  String get channelId;

  /// Get channel type
  int get channelType;
}
