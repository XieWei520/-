import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('moments publish page source does not import dart io directly', () {
    final source = File(
      'lib/modules/moments/publish_moment_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("import 'dart:io'")));
  });

  test('moments service source does not import dart io directly', () {
    final source = File(
      'lib/modules/moments/moments_service.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("import 'dart:io'")));
  });

  test('moments image grids use the shared media cache pipeline', () {
    final sources = <String>[
      File('lib/modules/moments/moments_page.dart').readAsStringSync(),
      File('lib/modules/moments/moment_detail_page.dart').readAsStringSync(),
    ];

    for (final source in sources) {
      expect(source, isNot(contains('Image.network(')));
      expect(source, contains('CachedMediaImage('));
    }
  });
}
