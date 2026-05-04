import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const guardedSources = <String>[
    'lib/core/utils/qr_export_utils.dart',
    'lib/wukong_base/utils/download_manager.dart',
    'lib/wukong_base/utils/file_utils.dart',
    'lib/wukong_base/utils/image_cache.dart',
    'lib/wukong_base/utils/image_utils.dart',
    'lib/wk_foundation/runtime/windows_sqlite_loader.dart',
  ];

  for (final sourcePath in guardedSources) {
    test('$sourcePath does not import dart io directly', () {
      final source = File(sourcePath).readAsStringSync();

      expect(source, isNot(contains("import 'dart:io'")));
    });
  }
}
