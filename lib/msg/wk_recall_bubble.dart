import 'package:flutter/material.dart';
import '../../entity/message.dart';

/// Recall message bubble widget
class WKRecallBubble extends StatelessWidget {
  final WKMessage message;

  const WKRecallBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Text(
          message.content,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ),
    );
  }
}
