/// Send text menu
/// 
/// Used for sending text messages
class SendTextMenu {
  /// Text content to send
  final String text;

  /// Conversation context
  final dynamic conversationContext;

  SendTextMenu({
    required this.text,
    this.conversationContext,
  });
}
