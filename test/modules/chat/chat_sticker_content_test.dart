import 'package:flutter_test/flutter_test.dart';
import 'package:wukongimfluttersdk/model/wk_sticker_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test('WKStickerContent round-trips required fields with media keys', () {
    final original = WKStickerContent(
      packId: 'pack-1',
      stickerId: 'sticker-1',
      packVersion: 2,
      title: 'Wave',
      mimeType: 'image/webp',
      width: 240,
      height: 180,
      loopCount: 3,
      previewKey: 'preview-abc',
      animationKey: 'anim-xyz',
      fallbackText: '  自定义贴纸  ',
      url: 'https://cdn.example.com/sticker.webp',
      localPath: 'C:/stickers/sticker.webp',
    );

    final encoded = original.encodeJson();
    final decoded = WKStickerContent().decodeJson(encoded) as WKStickerContent;

    expect(decoded.contentType, WkMessageContentType.sticker);
    expect(decoded.packId, 'pack-1');
    expect(decoded.stickerId, 'sticker-1');
    expect(decoded.packVersion, 2);
    expect(decoded.title, 'Wave');
    expect(decoded.mimeType, 'image/webp');
    expect(decoded.width, 240);
    expect(decoded.height, 180);
    expect(decoded.loopCount, 3);
    expect(decoded.previewKey, 'preview-abc');
    expect(decoded.animationKey, 'anim-xyz');
    expect(decoded.fallbackText, '  自定义贴纸  ');
    expect(decoded.url, 'https://cdn.example.com/sticker.webp');
    expect(decoded.localPath, 'C:/stickers/sticker.webp');
  });

  test('WKStickerContent display/search text uses fallback with [贴纸] default', () {
    final defaultContent = WKStickerContent(fallbackText: '   ');
    expect(defaultContent.displayText(), '[贴纸]');
    expect(defaultContent.searchableWord(), '[贴纸]');

    final customContent = WKStickerContent(fallbackText: '  自定义贴纸  ');
    expect(customContent.displayText(), '自定义贴纸');
    expect(customContent.searchableWord(), '自定义贴纸');
  });
}
