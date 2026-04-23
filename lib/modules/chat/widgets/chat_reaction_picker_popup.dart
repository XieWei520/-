import 'package:flutter/material.dart';
import 'package:wukong_im_app/wukong_base/msg/widget/wk_message_reaction.dart';

Future<String?> showChatReactionPicker({
  required BuildContext context,
  required bool isSelf,
  String? selectedEmoji,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black12,
    builder: (dialogContext) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(dialogContext).pop(),
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Align(
              alignment: isSelf
                  ? const Alignment(0.75, 0.30)
                  : const Alignment(-0.75, 0.30),
              child: GestureDetector(
                key: const ValueKey<String>('chat-reaction-picker-popup'),
                onTap: () {},
                child: WKReactionPicker(
                  selectedEmoji: selectedEmoji,
                  onEmojiSelected: (emoji) {
                    Navigator.of(dialogContext).pop(emoji);
                  },
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
