import 'package:flutter/material.dart';
import '../../entity/message.dart';

/// Tip message bubble widget
@Deprecated(
  'Use MessageBubble from lib/widgets/message_bubble.dart instead. Will be removed in v2.0',
)
class WKTipBubble extends StatelessWidget {
  final WKMessage message;

  const WKTipBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(message.content, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ),
      ),
    );
  }
}
