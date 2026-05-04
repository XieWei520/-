import 'package:flutter/material.dart';

import '../../../widgets/wk_emoji_text.dart';

class ChatReplyPreviewStrip extends StatelessWidget {
  const ChatReplyPreviewStrip({
    super.key,
    required this.previewText,
    required this.onClose,
  });

  final String previewText;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 18),
          const SizedBox(width: 8),
          Expanded(child: _buildPreviewText(context)),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }

  Widget _buildPreviewText(BuildContext context) {
    final style =
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle(fontSize: 14);
    if (WKEmojiText.containsAndroidEmoji(previewText)) {
      return WKEmojiText(
        text: previewText,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Text(previewText, maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}
