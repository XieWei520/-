import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web manifest does not force portrait-primary orientation', () {
    final manifest =
        jsonDecode(File('web/manifest.json').readAsStringSync())
            as Map<String, dynamic>;

    expect(manifest['orientation'], isNot('portrait-primary'));
  });
}
