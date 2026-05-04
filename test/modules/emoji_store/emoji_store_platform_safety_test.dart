import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('EmojiStorePage source does not import dart io directly', () {
    final source = File(
      'lib/modules/emoji_store/emoji_store_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("import 'dart:io'")));
  });

  test('remote emoji previews use the shared media cache pipeline', () {
    final source = File(
      'lib/modules/emoji_store/emoji_store_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('Image.network(')));
    expect(source, contains('CachedMediaImage('));
  });
}
