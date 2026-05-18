import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('connection transport uses conditional browser implementation', () {
    final source =
        File('lib/manager/connection_transport.dart').readAsStringSync();

    expect(source, contains('if (dart.library.html)'));
    expect(source, isNot(contains("import 'dart:io'")));
    expect(
        File('lib/manager/connection_transport_web.dart').existsSync(), isTrue);
  });
}
