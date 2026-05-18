import 'package:flutter/material.dart';

import '../../../wukong_base/emoji/android_emoji_catalog.dart';
import '../../../widgets/liquid_glass_tokens.dart';
import '../chat_gif_panel_service.dart';
import '../expression/chat_expression_models.dart';
import 'chat_emoji_panel.dart';

class ChatExpressionPanel extends StatelessWidget {
  const ChatExpressionPanel({
    super.key,
    required this.snapshot,
    required this.activeCategoryId,
    required this.gifResults,
    required this.gifErrorText,
    required this.onCategorySelected,
    required this.onRecentSelected,
    required this.onEmojiSelected,
    required this.onStickerSelected,
    required this.onGifQueryChanged,
    required this.onGifSelected,
    required this.onBackspaceTap,
  });

  final ChatExpressionRegistrySnapshot snapshot;
  final String activeCategoryId;
  final List<ChatGifPanelResult> gifResults;
  final String? gifErrorText;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<ChatExpressionRecentRecord> onRecentSelected;
  final ValueChanged<AndroidEmojiEntry> onEmojiSelected;
  final void Function(String categoryId, ChatStickerDefinition sticker)
  onStickerSelected;
  final ValueChanged<String> onGifQueryChanged;
  final ValueChanged<ChatGifPanelResult> onGifSelected;
  final VoidCallback onBackspaceTap;

  @override
  Widget build(BuildContext context) {
    final tokens = LiquidGlassTokens.of(context);
    final activeCategory = snapshot.categories.firstWhere(
      (item) => item.id == activeCategoryId,
      orElse: () => snapshot.categories.first,
    );

    return Container(
      key: const ValueKey<String>('chat-expression-panel-shell'),
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 280),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: tokens.surfaceSolid,
        borderRadius: LiquidGlassRadii.lg,
        border: Border.all(color: tokens.border),
        boxShadow: LiquidGlassShadows.md,
      ),
      child: Column(
        children: [
          Expanded(child: _buildBody(context, activeCategory)),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: snapshot.categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = snapshot.categories[index];
                return InkWell(
                  key: ValueKey<String>(
                    'chat-expression-category-${category.id}',
                  ),
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onCategorySelected(category.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: category.id == activeCategory.id
                            ? LiquidGlassColors.primary2
                            : tokens.border,
                      ),
                    ),
                    child: Text(
                      category.label,
                      style: TextStyle(color: tokens.text),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, ChatExpressionCategory category) {
    final tokens = LiquidGlassTokens.of(context);
    if (category.id == 'recent') {
      return GridView.builder(
        key: const ValueKey<String>('chat-expression-recent-grid'),
        itemCount: category.recents.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemBuilder: (context, index) {
          final recent = category.recents[index];
          return InkWell(
            key: ValueKey<String>(
              'chat-expression-recent-${recent.logicalKey}',
            ),
            onTap: () => onRecentSelected(recent),
            child: recent.previewKey.isNotEmpty
                ? Image.asset(recent.previewKey, fit: BoxFit.contain)
                : Center(
                    child: Text(
                      recent.displayText,
                      style: TextStyle(color: tokens.text),
                    ),
                  ),
          );
        },
      );
    }

    if (category.isGif) {
      return Column(
        children: [
          TextField(
            key: const ValueKey<String>('chat-expression-gif-search-field'),
            onChanged: onGifQueryChanged,
            style: TextStyle(color: tokens.text),
            decoration: InputDecoration(
              hintText: '搜索动图',
              hintStyle: TextStyle(color: tokens.textSecondary),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: tokens.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (gifErrorText != null && gifErrorText!.trim().isNotEmpty)
            Text(
              gifErrorText!,
              key: const ValueKey<String>('chat-expression-gif-error'),
              style: TextStyle(color: tokens.textSecondary),
            ),
          if (gifResults.isNotEmpty)
            Expanded(
              child: GridView.builder(
                key: const ValueKey<String>('chat-expression-gif-grid'),
                itemCount: gifResults.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final result = gifResults[index];
                  return InkWell(
                    key: ValueKey<String>('chat-expression-gif-item-$index'),
                    onTap: () => onGifSelected(result),
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: tokens.surface),
                      child: Center(
                        child: Text('动图', style: TextStyle(color: tokens.text)),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      );
    }

    if (category.kind == ChatExpressionKind.sticker) {
      return GridView.builder(
        key: const ValueKey<String>('chat-expression-sticker-grid'),
        itemCount: category.stickers.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemBuilder: (context, index) {
          final sticker = category.stickers[index];
          return InkWell(
            key: ValueKey<String>(
              'chat-expression-sticker-${sticker.stickerId}',
            ),
            onTap: () => onStickerSelected(category.id, sticker),
            child: Image.asset(
              sticker.previewKey,
              fit: BoxFit.contain,
              cacheWidth: 128,
              cacheHeight: 128,
              filterQuality: FilterQuality.medium,
            ),
          );
        },
      );
    }

    return Column(
      children: [
        Expanded(
          child: ChatEmojiGridBody(
            emojiTags: category.emojiTags,
            onEmojiTap: onEmojiSelected,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            key: const ValueKey<String>('chat-expression-backspace'),
            onPressed: onBackspaceTap,
            icon: Icon(Icons.backspace_outlined, color: tokens.text),
          ),
        ),
      ],
    );
  }
}
