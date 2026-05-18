import 'package:flutter/material.dart';
import '../../entity/message.dart';

/// Message bubble widget
@Deprecated(
  'Use MessageBubble from lib/widgets/message_bubble.dart instead. Will be removed in v2.0',
)
class WKMessageBubble extends StatelessWidget {
  final WKMessage message;
  final bool isMe;

  const WKMessageBubble({
    super.key,
    required this.message,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.content,
          style: TextStyle(color: isMe ? Colors.white : Colors.black),
        ),
      ),
    );
  }
}
