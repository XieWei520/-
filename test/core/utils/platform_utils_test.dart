import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/utils/platform_utils.dart';

void main() {
  group('PlatformUtils', () {
    test('source does not import dart io', () {
      final source = File(
        'lib/core/utils/platform_utils.dart',
      ).readAsStringSync();

      expect(source, isNot(contains("import 'dart:io'")));
    });

    test('reports a concrete platform family for the current runtime', () {
      expect(PlatformUtils.platformName, isNot('Unknown'));
      expect(
        PlatformUtils.isMobile ||
            PlatformUtils.isDesktop ||
            PlatformUtils.isWeb,
        isTrue,
      );
    });
  });
}
