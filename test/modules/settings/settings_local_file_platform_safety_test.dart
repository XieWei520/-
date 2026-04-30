import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const guardedSources = <String>[
    'lib/modules/settings/cache_clean_service.dart',
    'lib/modules/settings/message_backup/backup_restore_message_service.dart',
    'lib/wukong_uikit/setting/error_logs_page.dart',
    'lib/wukong_uikit/user/avatar_crop_page.dart',
  ];

  for (final sourcePath in guardedSources) {
    test('$sourcePath does not import dart io directly', () {
      final source = File(sourcePath).readAsStringSync();

      expect(source, isNot(contains("import 'dart:io'")));
    });
  }
}
