import '../../../wukong_base/emoji/android_emoji_catalog.dart';
import 'chat_expression_models.dart';
import 'chat_expression_recent_store.dart';
import 'chat_sticker_pack_loader.dart';

class ChatExpressionRegistry {
  ChatExpressionRegistry({
    ChatExpressionRecentStore? recentStore,
    ChatStickerPackLoader? stickerPackLoader,
  }) : _recentStore = recentStore ?? ChatExpressionRecentStore(),
       _stickerPackLoader = stickerPackLoader ?? ChatStickerPackLoader();

  final ChatExpressionRecentStore _recentStore;
  final ChatStickerPackLoader _stickerPackLoader;

  Future<ChatExpressionRegistrySnapshot> load() async {
    final recents = _normalizeRecents(await _recentStore.load());
    final packs = await _stickerPackLoader.load();

    final categories = <ChatExpressionCategory>[
      ChatExpressionCategory(
        id: 'recent',
        kind: ChatExpressionKind.emoji,
        label: '最近',
        iconKey: 'recent',
        emojiTags: const <String>[],
        stickers: const <ChatStickerDefinition>[],
        recents: recents,
      ),
      for (final groupId in androidEmojiCatalog.groupIds)
        ChatExpressionCategory(
          id: 'emoji:$groupId',
          kind: ChatExpressionKind.emoji,
          label: groupId,
          iconKey: 'emoji:$groupId',
          emojiTags: androidEmojiCatalog
              .entriesForGroup(groupId)
              .map((item) => item.tag)
              .toList(growable: false),
          stickers: const <ChatStickerDefinition>[],
          recents: const <ChatExpressionRecentRecord>[],
        ),
      for (final pack in packs)
        ChatExpressionCategory(
          id: 'sticker:${pack.packId}',
          kind: ChatExpressionKind.sticker,
          label: pack.title,
          iconKey: pack.cover,
          emojiTags: const <String>[],
          stickers: pack.stickers,
          recents: const <ChatExpressionRecentRecord>[],
        ),
      const ChatExpressionCategory(
        id: 'gif',
        kind: ChatExpressionKind.gif,
        label: '动图',
        iconKey: 'gif',
        emojiTags: <String>[],
        stickers: <ChatStickerDefinition>[],
        recents: <ChatExpressionRecentRecord>[],
        isGif: true,
      ),
    ];

    return ChatExpressionRegistrySnapshot(
      categories: List<ChatExpressionCategory>.unmodifiable(categories),
    );
  }

  List<ChatExpressionRecentRecord> _normalizeRecents(
    List<ChatExpressionRecentRecord> records,
  ) {
    final normalized = <ChatExpressionRecentRecord>[];
    final seenKeys = <String>{};
    for (final record in records) {
      final item = _normalizeRecent(record);
      if (item == null || !seenKeys.add(item.logicalKey)) {
        continue;
      }
      normalized.add(item);
    }
    return List<ChatExpressionRecentRecord>.unmodifiable(normalized);
  }

  ChatExpressionRecentRecord? _normalizeRecent(
    ChatExpressionRecentRecord record,
  ) {
    switch (record.kind) {
      case ChatExpressionKind.emoji:
        final entry =
            androidEmojiCatalog.lookupByTag(record.itemId) ??
            androidEmojiCatalog.lookupByTag(record.displayText) ??
            androidEmojiCatalog.lookupById(record.itemId);
        if (entry == null) {
          return null;
        }
        return ChatExpressionRecentRecord(
          kind: ChatExpressionKind.emoji,
          categoryId: 'emoji:${entry.groupId}',
          itemId: entry.tag,
          displayText: entry.tag,
          previewKey: entry.assetPath,
          animationKey: '',
          gifUrl: '',
          width: 0,
          height: 0,
        );
      case ChatExpressionKind.sticker:
        return record.itemId.trim().isEmpty ? null : record;
      case ChatExpressionKind.gif:
        return record.gifUrl.trim().isEmpty ? null : record;
    }
  }

  Future<void> rememberEmoji(AndroidEmojiEntry entry) {
    return _recentStore.remember(
      ChatExpressionRecentRecord(
        kind: ChatExpressionKind.emoji,
        categoryId: 'emoji:${entry.groupId}',
        itemId: entry.tag,
        displayText: entry.tag,
        previewKey: entry.assetPath,
        animationKey: '',
        gifUrl: '',
        width: 0,
        height: 0,
      ),
    );
  }

  Future<void> rememberSticker(ChatStickerDefinition sticker) {
    return _recentStore.remember(
      ChatExpressionRecentRecord(
        kind: ChatExpressionKind.sticker,
        categoryId: 'sticker:${sticker.packId}',
        itemId: sticker.stickerId,
        displayText: sticker.fallbackText,
        previewKey: sticker.previewKey,
        animationKey: sticker.animationKey,
        gifUrl: '',
        width: sticker.width,
        height: sticker.height,
      ),
    );
  }

  Future<void> rememberGif({
    required String title,
    required String url,
    required int width,
    required int height,
  }) {
    return _recentStore.remember(
      ChatExpressionRecentRecord(
        kind: ChatExpressionKind.gif,
        categoryId: 'gif',
        itemId: title.isNotEmpty ? title : url,
        displayText: '动图',
        previewKey: '',
        animationKey: '',
        gifUrl: url,
        width: width,
        height: height,
      ),
    );
  }

  Future<void> rememberRecent(ChatExpressionRecentRecord record) {
    return _recentStore.remember(record);
  }
}
