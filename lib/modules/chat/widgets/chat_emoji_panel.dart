import 'package:flutter/material.dart';

import '../../../wukong_base/emoji/android_emoji_catalog.dart';
import '../../../wukong_base/emoji/emoji_manager.dart';
import '../../../widgets/wk_colors.dart';

class ChatEmojiPanel extends StatefulWidget {
  const ChatEmojiPanel({
    super.key,
    required this.onEmojiSelected,
    required this.onBackspaceTap,
  });

  final ValueChanged<String> onEmojiSelected;
  final VoidCallback onBackspaceTap;

  @override
  State<ChatEmojiPanel> createState() => _ChatEmojiPanelState();
}

class _ChatEmojiPanelState extends State<ChatEmojiPanel> {
  static const String _recentTabId = 'recent';
  late final Future<void> _initializeFuture = EmojiManager.instance
      .initialize();
  final Set<String> _reportedAssetErrors = <String>{};
  String? _selectedTabId = androidEmojiCatalog.groupIds.isNotEmpty
      ? androidEmojiCatalog.groupIds.first
      : null;

  void _handleEmojiTap(AndroidEmojiEntry entry) {
    EmojiManager.instance.addToRecent(entry.tag);
    setState(() {});
    widget.onEmojiSelected(entry.tag);
  }

  String _resolveSelectedTabId(List<_EmojiTabModel> tabs) {
    final current = _selectedTabId;
    if (current != null && tabs.any((tab) => tab.id == current)) {
      return current;
    }
    final fallback = tabs
        .firstWhere((tab) => tab.id != _recentTabId, orElse: () => tabs.first)
        .id;
    _selectedTabId = fallback;
    return fallback;
  }

  String _labelForGroup(String groupId) {
    switch (groupId) {
      case '0':
        return 'Smileys';
      case '1':
        return 'Gestures';
      case '2':
        return 'Symbols';
      default:
        return 'Group $groupId';
    }
  }

  Widget _buildAssetFallback(
    AndroidEmojiEntry entry,
    Object error,
    StackTrace? stackTrace,
  ) {
    if (_reportedAssetErrors.add(entry.assetPath)) {
      debugPrint(
        '[chat_emoji_panel] failed to load "${entry.assetPath}" '
        '(emoji id: ${entry.id}): $error',
      );
    }
    return Container(
      key: ValueKey<String>('chat-emoji-asset-fallback-${entry.id}'),
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: WKColors.layoutColorSelected,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: WKColors.warning),
      ),
      child: Text(
        entry.tag,
        maxLines: 1,
        overflow: TextOverflow.fade,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: WKColors.colorDark),
      ),
    );
  }

  List<_EmojiTabModel> _tabModels() {
    final tabs = <_EmojiTabModel>[];
    final recentEntries = EmojiManager.instance.recentEmojis
        .map(androidEmojiCatalog.lookupByTag)
        .whereType<AndroidEmojiEntry>()
        .toList(growable: false);
    if (recentEntries.isNotEmpty) {
      tabs.add(
        _EmojiTabModel(
          id: _recentTabId,
          label: 'Recent',
          entries: recentEntries,
        ),
      );
    }
    for (final groupId in androidEmojiCatalog.groupIds) {
      tabs.add(
        _EmojiTabModel(
          id: groupId,
          label: _labelForGroup(groupId),
          entries: androidEmojiCatalog.entriesForGroup(groupId),
        ),
      );
    }
    return tabs;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('chat-emoji-panel'),
      width: double.infinity,
      color: WKColors.homeBg,
      constraints: const BoxConstraints(maxHeight: 260),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: FutureBuilder<void>(
        future: _initializeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          final tabs = _tabModels();
          if (tabs.isEmpty) {
            return const SizedBox.shrink();
          }
          final selectedTabId = _resolveSelectedTabId(tabs);
          final selectedTab = tabs.firstWhere((tab) => tab.id == selectedTabId);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: tabs.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final tab = tabs[index];
                            return ChoiceChip(
                              key: ValueKey<String>('chat-emoji-tab-${tab.id}'),
                              label: Text(tab.label),
                              selected: tab.id == selectedTabId,
                              selectedColor: WKColors.brand100,
                              backgroundColor: WKColors.surfaceSoft,
                              side: BorderSide(
                                color: tab.id == selectedTabId
                                    ? WKColors.brand500
                                    : WKColors.layoutColorSelected,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              onSelected: (_) {
                                if (tab.id == selectedTabId) {
                                  return;
                                }
                                setState(() {
                                  _selectedTabId = tab.id;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _EmojiGrid(
                        entries: selectedTab.entries,
                        onEmojiTap: _handleEmojiTap,
                        assetFallbackBuilder: _buildAssetFallback,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  key: const ValueKey<String>('chat-emoji-delete'),
                  tooltip: 'Delete',
                  onPressed: widget.onBackspaceTap,
                  icon: const Icon(
                    Icons.backspace_outlined,
                    color: WKColors.colorDark,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmojiGrid extends StatelessWidget {
  const _EmojiGrid({
    required this.entries,
    required this.onEmojiTap,
    required this.assetFallbackBuilder,
  });

  final List<AndroidEmojiEntry> entries;
  final ValueChanged<AndroidEmojiEntry> onEmojiTap;
  final Widget Function(
    AndroidEmojiEntry entry,
    Object error,
    StackTrace? stackTrace,
  )
  assetFallbackBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 44)
            .floor()
            .clamp(6, 8)
            .toInt();
        return GridView.builder(
          shrinkWrap: true,
          itemCount: entries.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey<String>('chat-emoji-item-${entry.id}'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => onEmojiTap(entry),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: WKColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Image.asset(
                      entry.assetPath,
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          assetFallbackBuilder(entry, error, stackTrace),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ChatEmojiGridBody extends StatelessWidget {
  const ChatEmojiGridBody({
    super.key,
    required this.emojiTags,
    required this.onEmojiTap,
  });

  final List<String> emojiTags;
  final ValueChanged<AndroidEmojiEntry> onEmojiTap;

  @override
  Widget build(BuildContext context) {
    final entries = emojiTags
        .map(androidEmojiCatalog.lookupByTag)
        .whereType<AndroidEmojiEntry>()
        .toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 44)
            .floor()
            .clamp(6, 8)
            .toInt();
        return GridView.builder(
          key: const ValueKey<String>('chat-expression-emoji-grid'),
          shrinkWrap: true,
          itemCount: entries.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey<String>('chat-expression-emoji-${entry.id}'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => onEmojiTap(entry),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: WKColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Image.asset(
                      entry.assetPath,
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                      errorBuilder: (context, _, __) => Text(
                        entry.tag,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: WKColors.colorDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _EmojiTabModel {
  const _EmojiTabModel({
    required this.id,
    required this.label,
    required this.entries,
  });

  final String id;
  final String label;
  final List<AndroidEmojiEntry> entries;
}
