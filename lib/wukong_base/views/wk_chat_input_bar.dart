import 'package:flutter/material.dart';

/// Chat input bar widget
@Deprecated(
  'Use ChatComposer with ChatComposerController instead. Will be removed in v2.0',
)
class WKChatInputBar extends StatelessWidget {
  final TextEditingController? controller;
  final VoidCallback? onSend;
  final VoidCallback? onVoice;
  final VoidCallback? onEmoji;
  final VoidCallback? onMore;

  const WKChatInputBar({
    super.key,
    this.controller,
    this.onSend,
    this.onVoice,
    this.onEmoji,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.add), onPressed: onMore),
          Expanded(child: TextField(controller: controller)),
          IconButton(icon: const Icon(Icons.emoji_emotions), onPressed: onEmoji),
          IconButton(icon: const Icon(Icons.mic), onPressed: onVoice),
        ],
      ),
    );
  }
}
