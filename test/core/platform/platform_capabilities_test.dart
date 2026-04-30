import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/platform/platform_capabilities.dart';

void main() {
  test('platform capabilities source stays web safe', () {
    final source = File(
      'lib/core/platform/platform_capabilities.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("import 'dart:io'")));
  });

  test('default capabilities expose a concrete platform family', () {
    final capabilities = defaultPlatformCapabilities();

    expect(capabilities.platformFamily, isNotEmpty);
    expect(
      capabilities.supportsLocalSqlite || capabilities.supportsIndexedDbCache,
      isTrue,
    );
  });
}
