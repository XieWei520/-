import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('top-level WKFileUtils source does not import dart io directly', () {
    final source = File('lib/utils/wk_file_utils.dart').readAsStringSync();

    expect(source, isNot(contains("import 'dart:io'")));
  });

  test('wukong base WKFileUtils source does not import dart io directly', () {
    final source = File(
      'lib/wukong_base/utils/wk_file_utils.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("import 'dart:io'")));
  });
}
