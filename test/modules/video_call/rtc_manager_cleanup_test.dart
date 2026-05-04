import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy rtc_manager.dart has been removed', () {
    final legacyFile = File('lib/modules/video_call/rtc_manager.dart');

    expect(legacyFile.existsSync(), isFalse);
  });
}
