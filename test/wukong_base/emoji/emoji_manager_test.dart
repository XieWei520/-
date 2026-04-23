import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/wukong_base/emoji/android_emoji_catalog.dart';
import 'package:wukong_im_app/wukong_base/emoji/emoji_manager.dart';
import 'package:wukong_im_app/wukong_base/emoji/sticker_manager.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageUtils.init();
    await StorageUtils.clear();
    EmojiManager.instance.debugResetForTest();
  });

  test(
    'initializes from Android catalog and persists recents by tag',
    () async {
      final manager = EmojiManager.instance;
      await manager.initialize();

      final categoryIds = manager.categories.map((item) => item.id).toList();
      expect(categoryIds, containsAll(<String>['0', '1', '2']));

      final tag = androidEmojiCatalog.lookupById('0_0')!.tag;
      manager.addToRecent(tag);

      expect(manager.recentEmojis.first, tag);
      expect(manager.search(tag), contains(tag));
    },
  );

  test(
    'reconciles built-in catalog packs while preserving custom packs and favorites',
    () async {
      final defaultPack = EmojiManager.defaultPacks.first;
      final storedRaw = <String>[
        jsonEncode(
          const EmojiPack(
            id: 'custom_pack',
            name: 'Custom',
            emojis: <String>['custom://emoji'],
          ).toJson(),
        ),
        jsonEncode(
          EmojiPack(
            id: defaultPack.id,
            name: 'Stale Builtin',
            coverUrl: 'stale_cover',
            emojis: const <String>['stale_tag'],
            isFavorite: true,
            isBuiltIn: true,
          ).toJson(),
        ),
      ];
      await StorageUtils.setStringList('wk_emoji_packs_v2', storedRaw);

      final manager = EmojiManager.instance;
      manager.debugResetForTest();
      await manager.initialize();

      final packsById = <String, EmojiPack>{
        for (final pack in manager.packs) pack.id: pack,
      };

      expect(packsById['custom_pack']?.emojis, const <String>[
        'custom://emoji',
      ]);
      for (final builtIn in EmojiManager.defaultPacks) {
        expect(packsById, contains(builtIn.id));
      }

      final reconciled = packsById[defaultPack.id]!;
      expect(reconciled.emojis, defaultPack.emojis);
      expect(reconciled.coverUrl, defaultPack.coverUrl);
      expect(reconciled.isFavorite, isTrue);
    },
  );

  test('maps built-in stickers to Android catalog asset paths', () async {
    final manager = EmojiManager.instance;
    await manager.initialize();

    final stickerManager = StickerManager.instance;
    await stickerManager.loadCategories();

    final builtInPack = EmojiManager.defaultPacks.first;
    final builtInCategory = stickerManager.categories.firstWhere(
      (item) => item.id == builtInPack.id,
    );
    final firstTag = builtInPack.emojis.first;
    final entry = androidEmojiCatalog.lookupByTag(firstTag)!;
    final firstSticker = builtInCategory.stickers.first;

    expect(firstSticker.localPath, entry.assetPath);
    expect(firstSticker.name, entry.id);
    expect(firstSticker.displayUrl, entry.assetPath);
  });

  test(
    'keeps custom sticker values renderable for catalog tags and uppercase URLs',
    () async {
      final manager = EmojiManager.instance;
      await manager.initialize();

      final tag = androidEmojiCatalog.lookupById('0_0')!.tag;
      await manager.addPack(
        id: 'custom_renderable',
        name: 'Custom Renderable',
        emojis: <String>[
          tag,
          'HTTPS://cdn.example.com/EMOJI.PNG',
          'plain_custom_value',
        ],
      );

      final stickerManager = StickerManager.instance;
      await stickerManager.loadCategories();
      final customCategory = stickerManager.categories.firstWhere(
        (item) => item.id == 'custom_renderable',
      );

      final catalogSticker = customCategory.stickers[0];
      final urlSticker = customCategory.stickers[1];
      final plainSticker = customCategory.stickers[2];

      expect(catalogSticker.displayUrl, isNotEmpty);
      expect(
        catalogSticker.localPath,
        androidEmojiCatalog.lookupByTag(tag)!.assetPath,
      );

      expect(urlSticker.displayUrl, 'HTTPS://cdn.example.com/EMOJI.PNG');
      expect(urlSticker.url, 'HTTPS://cdn.example.com/EMOJI.PNG');

      expect(plainSticker.displayUrl, isNotEmpty);
      expect(plainSticker.displayUrl, 'plain_custom_value');
    },
  );
}
