import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_image_bytes_loader_io.dart';

void main() {
  test('loadChatImageBytes rejects oversized local images', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'wk_chat_large_image',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final image = File('${tempDir.path}${Platform.pathSeparator}large.png');
    await image.writeAsBytes(List<int>.filled(16 * 1024 * 1024 + 1, 1));

    expect(await loadChatImageBytes(image.path), isNull);
  });
}
