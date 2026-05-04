import 'package:flutter/material.dart';
import '../../entity/message.dart';

/// Video message bubble widget
class WKVideoBubble extends StatelessWidget {
  final WKMessage message;
  final bool isMe;

  const WKVideoBubble({
    super.key,
    required this.message,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 200,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.grey[400],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(Icons.play_circle_outline, size: 48, color: Colors.white),
        ),
      ),
    );
  }
}
