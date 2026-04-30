import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AudioRecordManager facade source does not import dart io directly', () {
    final source = File(
      'lib/wukong_base/utils/audio_record_manager.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("import 'dart:io'")));
  });
}
