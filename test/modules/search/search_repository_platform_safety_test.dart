import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SearchRepositoryImpl does not import dart io directly', () {
    final source = File(
      'lib/modules/search/data/search_repository_impl.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("import 'dart:io'")));
  });
}
