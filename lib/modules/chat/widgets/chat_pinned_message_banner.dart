import 'package:flutter/material.dart';

import '../../../widgets/wk_colors.dart';

@immutable
class ChatPinnedMessageBannerData {
  const ChatPinnedMessageBannerData({
    required this.previewText,
    required this.count,
  });

  final String previewText;
  final int count;
}

class ChatPinnedMessageBanner extends StatelessWidget {
  const ChatPinnedMessageBanner({
    super.key,
    required this.data,
    required this.onTap,
    this.onClearAll,
  });

  final ChatPinnedMessageBannerData data;
  final VoidCallback onTap;
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    final countLabel =
        data.count > 1 ? '${data.count}\u6761\u7f6e\u9876' : '\u7f6e\u9876';

    return Material(
      color: const Color(0xFFF3F7FF),
      child: SafeArea(
        bottom: false,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFDCE6FF)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  key: const ValueKey<String>('chat-pinned-banner'),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.push_pin_rounded,
                          size: 16,
                          color: WKColors.brand500,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                countLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: WKColors.brand500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                data.previewText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: WKColors.colorDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: WKColors.color999,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (onClearAll != null)
                IconButton(
                  key: const ValueKey<String>('chat-pinned-clear-all'),
                  tooltip: '\u6e05\u7a7a\u7f6e\u9876',
                  onPressed: onClearAll,
                  icon: const Icon(
                    Icons.layers_clear_rounded,
                    color: WKColors.color999,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
