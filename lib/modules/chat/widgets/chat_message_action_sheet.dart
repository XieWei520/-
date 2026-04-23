import 'package:flutter/material.dart';
import 'package:wukong_im_app/modules/chat/chat_message_action_policy.dart';
import 'package:wukong_im_app/wukong_base/msg/widget/wk_message_reaction.dart';

const String _emptySheetKey = 'chat-action-sheet-empty';

class ChatMessageActionSheet extends StatelessWidget {
  const ChatMessageActionSheet({
    super.key,
    required this.actions,
    required this.onSelected,
    this.onReactionSelected,
    this.selectedEmoji,
  });

  final List<ChatMessageActionDescriptor> actions;
  final ValueChanged<ChatSceneAction> onSelected;
  final ValueChanged<String>? onReactionSelected;
  final String? selectedEmoji;

  @override
  Widget build(BuildContext context) {
    final showReactionStrip =
        onReactionSelected != null ||
        actions.any((descriptor) => descriptor.action == ChatSceneAction.react);
    if (actions.isEmpty && !showReactionStrip) {
      return const SizedBox.shrink(key: ValueKey<String>(_emptySheetKey));
    }
    final orderedActions = actions.toList(growable: false)
      ..sort((left, right) {
        final orderComparison = left.order.compareTo(right.order);
        if (orderComparison != 0) {
          return orderComparison;
        }
        return left.action.name.compareTo(right.action.name);
      });

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showReactionStrip) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: WKReactionPicker(
                    selectedEmoji: selectedEmoji,
                    onEmojiSelected: (emoji) {
                      final onReactionSelected = this.onReactionSelected;
                      if (onReactionSelected == null) {
                        return;
                      }
                      Navigator.of(context).pop();
                      onReactionSelected(emoji);
                    },
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFD),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE7ECF3)),
                    ),
                    itemExtent: 40,
                    emojiFontSize: 22,
                    spacing: 6,
                    runSpacing: 6,
                  ),
                ),
                const Divider(height: 1, indent: 12, endIndent: 12),
              ],
              ...orderedActions.map(
                (descriptor) => ListTile(
                  key: ValueKey<String>('chat-action-${descriptor.action.name}'),
                  title: Text(descriptor.label),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  visualDensity: const VisualDensity(vertical: -1),
                  onTap: () {
                    Navigator.of(context).pop();
                    onSelected(descriptor.action);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
