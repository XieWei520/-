import 'package:meta/meta.dart';

const String chatExpressionStickerFallbackText = '[\u8d34\u7eb8]';

enum ChatExpressionKind { emoji, sticker, gif }

@immutable
class ChatStickerDefinition {
  const ChatStickerDefinition({
    required this.packId,
    required this.stickerId,
    required this.title,
    required this.previewKey,
    required this.animationKey,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.loopCount,
    required this.fallbackText,
  });

  final String packId;
  final String stickerId;
  final String title;
  final String previewKey;
  final String animationKey;
  final String mimeType;
  final int width;
  final int height;
  final int loopCount;
  final String fallbackText;
}

@immutable
class ChatStickerPack {
  const ChatStickerPack({
    required this.packId,
    required this.packVersion,
    required this.title,
    required this.cover,
    required this.stickers,
  });

  final String packId;
  final int packVersion;
  final String title;
  final String cover;
  final List<ChatStickerDefinition> stickers;
}

@immutable
class ChatExpressionRecentRecord {
  const ChatExpressionRecentRecord({
    required this.kind,
    required this.categoryId,
    required this.itemId,
    required this.displayText,
    required this.previewKey,
    required this.animationKey,
    required this.gifUrl,
    required this.width,
    required this.height,
  });

  final ChatExpressionKind kind;
  final String categoryId;
  final String itemId;
  final String displayText;
  final String previewKey;
  final String animationKey;
  final String gifUrl;
  final int width;
  final int height;

  String get logicalKey => '$categoryId:$itemId';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': kind.name,
      'categoryId': categoryId,
      'itemId': itemId,
      'displayText': displayText,
      'previewKey': previewKey,
      'animationKey': animationKey,
      'gifUrl': gifUrl,
      'width': width,
      'height': height,
    };
  }

  factory ChatExpressionRecentRecord.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind']?.toString() ?? '';
    final kind = ChatExpressionKind.values.firstWhere(
      (item) => item.name == kindName,
      orElse: () => ChatExpressionKind.emoji,
    );
    return ChatExpressionRecentRecord(
      kind: kind,
      categoryId: json['categoryId']?.toString() ?? '',
      itemId: json['itemId']?.toString() ?? '',
      displayText: json['displayText']?.toString() ?? '',
      previewKey: json['previewKey']?.toString() ?? '',
      animationKey: json['animationKey']?.toString() ?? '',
      gifUrl: json['gifUrl']?.toString() ?? '',
      width: int.tryParse(json['width']?.toString() ?? '') ?? 0,
      height: int.tryParse(json['height']?.toString() ?? '') ?? 0,
    );
  }
}

@immutable
class ChatExpressionCategory {
  const ChatExpressionCategory({
    required this.id,
    required this.kind,
    required this.label,
    required this.iconKey,
    required this.emojiTags,
    required this.stickers,
    required this.recents,
    this.isGif = false,
  });

  final String id;
  final ChatExpressionKind kind;
  final String label;
  final String iconKey;
  final List<String> emojiTags;
  final List<ChatStickerDefinition> stickers;
  final List<ChatExpressionRecentRecord> recents;
  final bool isGif;
}

@immutable
class ChatExpressionRegistrySnapshot {
  const ChatExpressionRegistrySnapshot({required this.categories});

  final List<ChatExpressionCategory> categories;
}
