import 'package:flutter/material.dart';

import '../../../widgets/wk_colors.dart';
import '../../../widgets/wk_design_tokens.dart';

class WKMessageReaction {
  final String emoji;
  final int count;
  final bool isMe;
  final List<String> usernames;

  WKMessageReaction({
    required this.emoji,
    required this.count,
    required this.isMe,
    required this.usernames,
  });

  factory WKMessageReaction.fromJson(Map<String, dynamic> json) {
    return WKMessageReaction(
      emoji: json['emoji'] ?? '',
      count: json['count'] ?? 0,
      isMe: json['is_me'] ?? false,
      usernames: List<String>.from(json['usernames'] ?? const <String>[]),
    );
  }
}

class WKMessageReactions extends StatelessWidget {
  final List<WKMessageReaction> reactions;
  final void Function(String emoji)? onReactionTap;
  final VoidCallback? onAddReaction;

  const WKMessageReactions({
    super.key,
    required this.reactions,
    this.onReactionTap,
    this.onAddReaction,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: reactions.map(_buildReactionChip).toList(growable: false),
      ),
    );
  }

  Widget _buildReactionChip(WKMessageReaction reaction) {
    final backgroundColor = reaction.isMe
        ? const Color(0xFFEAF2FF)
        : Colors.white;
    final borderColor = reaction.isMe
        ? const Color(0xFF2D6CDF)
        : const Color(0xFFE2E7F0);
    final countColor = reaction.isMe
        ? const Color(0xFF2457C5)
        : const Color(0xFF5E6472);

    return GestureDetector(
      key: ValueKey<String>('message-reaction-chip-${reaction.emoji}'),
      onTap: () => onReactionTap?.call(reaction.emoji),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: reaction.isMe ? 1.2 : 1,
          ),
          boxShadow: WKShadows.soft,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              reaction.emoji,
              style: TextStyle(
                fontSize: 15,
                height: 1,
                fontFamilyFallback: WKTypography.fontFamilyFallback,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${reaction.count}',
              style: TextStyle(
                fontSize: 12,
                color: countColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WKReactionPicker extends StatelessWidget {
  static const List<String> commonEmojis = [
    '\u{1F44D}',
    '\u2764\uFE0F',
    '\u{1F600}',
    '\u{1F389}',
    '\u{1F44F}',
    '\u{1F525}',
    '\u{1F60F}',
    '\u{1F637}',
    '\u{1F629}',
    '\u{1F616}',
    '\u{1F4AA}',
    '\u{1F44C}',
  ];

  const WKReactionPicker({
    super.key,
    required this.onEmojiSelected,
    this.selectedEmoji,
    this.emojis = commonEmojis,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    this.decoration,
    this.itemExtent = 44,
    this.emojiFontSize = 24,
    this.spacing = 8,
    this.runSpacing = 8,
  });

  final void Function(String emoji) onEmojiSelected;
  final String? selectedEmoji;
  final List<String> emojis;
  final EdgeInsetsGeometry padding;
  final BoxDecoration? decoration;
  final double itemExtent;
  final double emojiFontSize;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    final rawSelectedEmoji = selectedEmoji?.trim() ?? '';
    final normalizedSelectedEmoji = _normalizeSelectedEmoji(selectedEmoji);
    final resolvedDecoration =
        decoration ??
        BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(26),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        );

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: padding,
      decoration: resolvedDecoration,
      child: Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        children: emojis
            .map((emoji) {
              final selected =
                  _normalizeSelectedEmoji(emoji) == normalizedSelectedEmoji;
              final emittedEmoji = selected && rawSelectedEmoji.isNotEmpty
                  ? rawSelectedEmoji
                  : emoji;
              return InkWell(
                key: ValueKey<String>('reaction-picker-$emoji'),
                onTap: () => onEmojiSelected(emittedEmoji),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: itemExtent,
                  height: itemExtent,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFEAF2FF)
                        : WKColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF2D6CDF)
                          : const Color(0xFFE2E7F0),
                    ),
                  ),
                  child: Text(
                    emoji,
                    style: TextStyle(
                      fontSize: emojiFontSize,
                      fontFamilyFallback: WKTypography.fontFamilyFallback,
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  static String _normalizeSelectedEmoji(String? emoji) {
    if (emoji == null) {
      return '';
    }
    return emoji.trim().replaceAll('\uFE0F', '').replaceAll('\uFE0E', '');
  }
}
