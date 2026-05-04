import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ReportPage source does not import dart io directly', () {
    final source = File(
      'lib/modules/report/report_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("import 'dart:io'")));
  });
}
