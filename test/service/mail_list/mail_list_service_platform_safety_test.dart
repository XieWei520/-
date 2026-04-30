import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MailListService source does not import dart io directly', () {
    final source = File(
      'lib/service/mail_list/mail_list_service.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("import 'dart:io'")));
  });
}
