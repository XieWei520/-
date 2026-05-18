import 'package:flutter/material.dart';

import '../../../widgets/liquid_glass_tokens.dart';

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
    final countLabel = data.count > 1
        ? '${data.count}\u6761\u7f6e\u9876'
        : '\u7f6e\u9876';

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                LiquidGlassColors.primary2.withValues(alpha: 0.10),
                LiquidGlassColors.primary.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: LiquidGlassRadii.lg,
            border: Border.all(
              color: LiquidGlassColors.primary2.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const ValueKey<String>('chat-pinned-banner'),
                    borderRadius: LiquidGlassRadii.lg,
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.push_pin_rounded,
                            size: 16,
                            color: LiquidGlassColors.primary2,
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
                                    color: LiquidGlassColors.primary2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  data.previewText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: LiquidGlassColors.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.keyboard_arrow_up_rounded,
                            color: LiquidGlassColors.textSecondary,
                          ),
                        ],
                      ),
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
                    color: LiquidGlassColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
