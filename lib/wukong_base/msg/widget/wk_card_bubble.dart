import 'package:flutter/material.dart';
import '../../entity/message.dart';

/// Card message bubble widget
class WKCardBubble extends StatelessWidget {
  final WKMessage message;
  final bool isMe;

  const WKCardBubble({super.key, required this.message, this.isMe = false});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person),
            const SizedBox(width: 8),
            Expanded(child: Text(message.content, style: TextStyle(color: isMe ? Colors.white : Colors.black), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}
