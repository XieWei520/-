import 'package:flutter/foundation.dart';

@immutable
class ChatSession {
  const ChatSession({required this.channelId, required this.channelType});

  final String channelId;
  final int channelType;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ChatSession &&
        other.channelId == channelId &&
        other.channelType == channelType;
  }

  @override
  int get hashCode => Object.hash(channelId, channelType);
}
