import 'package:flutter/material.dart';

import '../../../widgets/wk_colors.dart';

@immutable
class ChatPinnedMessageSheetItemData {
  const ChatPinnedMessageSheetItemData({
    required this.messageId,
    required this.previewText,
    this.countLabel = '',
  });

  final String messageId;
  final String previewText;
  final String countLabel;
}

class ChatPinnedMessageSheet extends StatelessWidget {
  const ChatPinnedMessageSheet({
    super.key,
    required this.items,
    required this.onSelected,
    this.canClearAll = false,
    this.onClearAll,
  });

  final List<ChatPinnedMessageSheetItemData> items;
  final ValueChanged<ChatPinnedMessageSheetItemData> onSelected;
  final bool canClearAll;
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        key: const ValueKey<String>('chat-pinned-sheet'),
        color: WKColors.homeBg,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
                child: Row(
                  children: [
                    Text(
                      '\u7f6e\u9876\u6d88\u606f',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: WKColors.colorDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${items.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: WKColors.color999,
                      ),
                    ),
                    const Spacer(),
                    if (canClearAll && onClearAll != null)
                      TextButton(
                        key: const ValueKey<String>(
                          'chat-pinned-sheet-clear-all',
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          onClearAll!.call();
                        },
                        child: const Text('\u6e05\u7a7a'),
                      ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: WKColors.layoutColor),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      key: ValueKey<String>(
                        'chat-pinned-sheet-item-${item.messageId}',
                      ),
                      leading: const Icon(
                        Icons.push_pin_rounded,
                        size: 18,
                        color: WKColors.brand500,
                      ),
                      title: Text(
                        item.previewText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: item.countLabel.trim().isEmpty
                          ? null
                          : Text(item.countLabel),
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelected(item);
                      },
                    );
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
