import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/cache/media_cache_manager.dart';
import 'package:wukong_im_app/wukong_base/views/image_viewer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ImageViewer source does not import dart io directly', () {
    final source = File(
      'lib/wukong_base/views/image_viewer.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("import 'dart:io'")));
  });

  testWidgets('network images use the shared media cache pipeline', (
    tester,
  ) async {
    const imageUrl = 'https://cdn.example.com/full-size.jpg';

    await tester.pumpWidget(
      MaterialApp(
        home: ImageViewer(
          args: ImageViewerArgs(
            images: const <String>[imageUrl],
            enableLongPressOptions: false,
          ),
        ),
      ),
    );

    final cachedImage = tester.widget<CachedMediaImage>(
      find.byType(CachedMediaImage),
    );

    expect(cachedImage.imageUrl, imageUrl);
    expect(cachedImage.cacheKey, imageUrl);
    expect(cachedImage.fit, BoxFit.contain);
    expect(cachedImage.maxWidth, greaterThan(0));
    expect(cachedImage.maxHeight, greaterThan(0));
  });
}
