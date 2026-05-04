/// Message reaction menu
/// 
/// Used for message emoji reactions
class MsgReactionMenu {
  /// Emoji unicode
  final String emoji;

  /// Message ID
  final String messageId;

  /// Channel ID
  final String channelId;

  /// Channel type
  final int channelType;

  /// Message order seq
  final int messageSeq;

  MsgReactionMenu({
    required this.emoji,
    required this.messageId,
    required this.channelId,
    required this.channelType,
    required this.messageSeq,
  });
}
