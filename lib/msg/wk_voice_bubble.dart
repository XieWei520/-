import 'package:flutter/material.dart';
import '../../entity/message.dart';

/// Voice message bubble widget
class WKVoiceBubble extends StatelessWidget {
  final WKMessage message;
  final bool isMe;
  final double width;

  const WKVoiceBubble({
    super.key,
    required this.message,
    this.isMe = false,
    this.width = 100,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_arrow,
              color: isMe ? Colors.white : Colors.black,
            ),
            const SizedBox(width: 8),
            Text(
              '${message.content}s',
              style: TextStyle(color: isMe ? Colors.white : Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}
