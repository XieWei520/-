import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'chat_expression_models.dart';

class ChatStickerPackLoader {
  ChatStickerPackLoader({
    this.manifestPaths = const <String>[
      'assets/stickers/sample_pack/manifest.json',
    ],
  });

  final List<String> manifestPaths;
  List<ChatStickerPack>? _cachedPacks;

  Future<List<ChatStickerPack>> load() async {
    final cachedPacks = _cachedPacks;
    if (cachedPacks != null) {
      return cachedPacks;
    }

    final packs = <ChatStickerPack>[];
    for (final manifestPath in manifestPaths) {
      final rawManifest = await rootBundle.loadString(manifestPath);
      final manifest = Map<String, dynamic>.from(
        jsonDecode(rawManifest) as Map,
      );
      final packId = manifest['packId']?.toString() ?? '';
      final stickers = (manifest['stickers'] as List<dynamic>? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .map(
            (item) => ChatStickerDefinition(
              packId: packId,
              stickerId: item['stickerId']?.toString() ?? '',
              title: item['title']?.toString() ?? '',
              previewKey: item['preview']?.toString() ?? '',
              animationKey: item['animation']?.toString() ?? '',
              mimeType: item['mimeType']?.toString() ?? '',
              width: int.tryParse(item['width']?.toString() ?? '') ?? 0,
              height: int.tryParse(item['height']?.toString() ?? '') ?? 0,
              loopCount: int.tryParse(item['loopCount']?.toString() ?? '') ?? 0,
              fallbackText:
                  item['fallbackText']?.toString() ??
                  chatExpressionStickerFallbackText,
            ),
          )
          .toList(growable: false);

      packs.add(
        ChatStickerPack(
          packId: packId,
          packVersion:
              int.tryParse(manifest['packVersion']?.toString() ?? '') ?? 0,
          title: manifest['title']?.toString() ?? '',
          cover: manifest['cover']?.toString() ?? '',
          stickers: stickers,
        ),
      );
    }

    final resolvedPacks = List<ChatStickerPack>.unmodifiable(packs);
    _cachedPacks = resolvedPacks;
    return resolvedPacks;
  }
}
