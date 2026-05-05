import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/expression/chat_sticker_pack_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bundled sticker pack uses lightweight previews before full animations',
    () async {
      final packs = await ChatStickerPackLoader().load();
      final samplePack = packs.singleWhere(
        (pack) => pack.packId == 'android_sample_motion',
      );

      expect(samplePack.stickers, isNotEmpty);

      for (final sticker in samplePack.stickers) {
        expect(sticker.previewKey, contains('/previews/'));
        expect(sticker.previewKey, isNot(sticker.animationKey));
        expect(sticker.animationKey, endsWith('.webp'));

        final preview = File(sticker.previewKey);
        expect(preview.existsSync(), isTrue);
        expect(
          preview.lengthSync(),
          lessThanOrEqualTo(96 * 1024),
          reason:
              '${sticker.stickerId} preview should stay cheap to fetch/decode',
        );
      }
    },
  );

  test(
    'pubspec includes nested sticker preview assets in web release builds',
    () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final stickerAssetLines = pubspec
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.startsWith('- assets/stickers/'))
          .toList(growable: false);

      expect(
        stickerAssetLines,
        contains('- assets/stickers/sample_pack/manifest.json'),
      );
      expect(
        stickerAssetLines,
        contains('- assets/stickers/sample_pack/previews/'),
      );
      expect(stickerAssetLines, isNot(contains('- assets/stickers/')));
      expect(
        stickerAssetLines,
        isNot(contains('- assets/stickers/sample_pack/')),
      );
    },
  );
}
