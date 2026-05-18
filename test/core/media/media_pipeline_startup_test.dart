import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main startup initializes the shared media cache manager', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains("import 'core/cache/media_cache_manager.dart';"));
    expect(source, contains('MediaCacheManager.instance.initialize()'));
  });
}
