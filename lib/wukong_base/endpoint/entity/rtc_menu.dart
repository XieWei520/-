/// RTC (Real-Time Call) menu
/// 
/// Used for initiating voice/video calls
class RTCMenu {
  /// Call type: 0=voice, 1=video
  final int callType;

  /// Channel ID
  final String? channelId;

  /// Channel type
  final int? channelType;

  /// Conversation context (for chat-related calls)
  final dynamic conversationContext;

  RTCMenu({
    this.callType = 0,
    this.channelId,
    this.channelType,
    this.conversationContext,
  });
}

/// Create video call menu
/// 
/// Used for creating video calls with selected members
class CreateVideoCallMenu {
  /// Channel ID
  final String channelId;

  /// Channel type
  final int channelType;

  /// Selected channels for the call
  final List<dynamic>? channels;

  CreateVideoCallMenu({
    required this.channelId,
    required this.channelType,
    this.channels,
  });
}
