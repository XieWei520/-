/// Read message detail menu
/// 
/// Used for reading detailed message info
class ReadMsgDetailMenu {
  /// Message ID
  final String messageId;

  /// Channel ID
  final String channelId;

  /// Channel type
  final int channelType;

  ReadMsgDetailMenu({
    required this.messageId,
    required this.channelId,
    required this.channelType,
  });
}

/// Video reading menu
/// 
/// Used for marking video as read
class VideoReadingMenu {
  /// Message ID
  final String messageId;

  /// Channel ID
  final String channelId;

  VideoReadingMenu({
    required this.messageId,
    required this.channelId,
  });
}
