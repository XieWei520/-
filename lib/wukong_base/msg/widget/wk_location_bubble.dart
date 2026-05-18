import 'package:flutter/material.dart';
import '../../entity/message.dart';

/// Location message bubble widget
@Deprecated(
  'Use MessageBubble from lib/widgets/message_bubble.dart instead. Will be removed in v2.0',
)
class WKLocationBubble extends StatelessWidget {
  final WKMessage message;
  final bool isMe;

  const WKLocationBubble({super.key, required this.message, this.isMe = false});

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on, color: Colors.red),
            const SizedBox(height: 4),
            Text(message.content, style: TextStyle(color: isMe ? Colors.white : Colors.black), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
