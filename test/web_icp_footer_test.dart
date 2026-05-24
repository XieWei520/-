import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'web entrypoint does not hang a global ICP footer outside Flutter routes',
    () {
      final index = File('web/index.html').readAsStringSync();
      const filingNumber = '\u6e58ICP\u59072026016828\u53f7';

      expect(index, isNot(contains(filingNumber)));
      expect(index, isNot(contains('?ICP?2026016828?')));
      expect(index, isNot(contains('https://beian.miit.gov.cn/')));
      expect(index, isNot(contains('icp-footer')));
      expect(index, isNot(contains('wk-icp-footer')));
    },
  );
}
