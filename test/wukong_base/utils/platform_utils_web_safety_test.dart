import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wukong base PlatformUtils source does not import dart io directly', () {
    final source = File(
      'lib/wukong_base/utils/platform_utils.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("import 'dart:io'")));
  });
}
