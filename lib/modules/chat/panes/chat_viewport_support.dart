import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

const String emptyMessageText = '\u6682\u65e0\u6d88\u606f';

class OlderMessagesLoadingIndicator extends StatelessWidget {
  const OlderMessagesLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class ChatImagePreviewItem {
  const ChatImagePreviewItem({
    required this.identity,
    required this.message,
    required this.url,
  });

  final String identity;
  final WKMsg message;
  final String url;
}

@immutable
class VisibleViewportItem {
  const VisibleViewportItem({
    required this.messageSeq,
    required this.top,
    required this.identity,
  });

  final int messageSeq;
  final double top;
  final String identity;
}
