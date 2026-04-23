import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/modules/chat/expression/chat_expression_models.dart';
import 'package:wukong_im_app/modules/chat/expression/chat_expression_recent_store.dart';
import 'package:wukong_im_app/modules/chat/expression/chat_expression_registry.dart';
import 'package:wukong_im_app/modules/chat/expression/chat_sticker_pack_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'registry exposes recent, emoji groups, bundled stickers, and GIF inside one strip',
    () async {
      final registry = ChatExpressionRegistry(
        recentStore: ChatExpressionRecentStore(),
        stickerPackLoader: ChatStickerPackLoader(
          manifestPaths: const <String>[
            'assets/stickers/sample_pack/manifest.json',
          ],
        ),
      );

      final snapshot = await registry.load();
      final categories = snapshot.categories;
      final firstStickerIndex = categories.indexWhere(
        (item) => item.kind == ChatExpressionKind.sticker,
      );
      final gifIndex = categories.indexWhere(
        (item) => item.kind == ChatExpressionKind.gif,
      );

      expect(categories.first.id, 'recent');
      expect(
        categories.any((item) => item.kind == ChatExpressionKind.emoji),
        isTrue,
      );
      expect(firstStickerIndex, greaterThan(0));
      expect(gifIndex, greaterThan(firstStickerIndex));
      expect(categories.last.id, 'gif');
    },
  );

  test(
    'recent records persist logical sticker keys instead of asset paths',
    () async {
      final store = ChatExpressionRecentStore();

      await store.save(const <ChatExpressionRecentRecord>[
        ChatExpressionRecentRecord(
          kind: ChatExpressionKind.sticker,
          categoryId: 'sticker:android_sample_motion',
          itemId: 'typing',
          displayText: '[\u8d34\u7eb8]',
          previewKey: 'assets/stickers/sample_pack/typing.webp',
          animationKey: 'assets/stickers/sample_pack/typing.webp',
          gifUrl: '',
          width: 512,
          height: 512,
        ),
      ]);

      final loaded = await store.load();

      expect(loaded.single.logicalKey, 'sticker:android_sample_motion:typing');
      expect(loaded.single.categoryId, 'sticker:android_sample_motion');
      expect(loaded.single.itemId, 'typing');
    },
  );
}
