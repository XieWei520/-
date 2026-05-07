import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web entrypoint hangs ICP filing number linking to MIIT home page', () {
    final index = File('web/index.html').readAsStringSync();

    expect(index, contains('沪ICP备2026016828号'));
    expect(index, contains('https://beian.miit.gov.cn/'));
    expect(index, contains('target="_blank"'));
    expect(index, contains('rel="noopener noreferrer"'));
  });
}
