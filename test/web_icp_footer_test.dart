import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'web entrypoint hangs readable Xiang ICP filing number linking to MIIT home page',
    () {
      final index = File('web/index.html').readAsStringSync();
      const filingNumber = '\u6e58ICP\u59072026016828\u53f7';
      const wrongProvinceNumber = '\u6caaICP\u59072026016828\u53f7';

      expect(index, contains(filingNumber));
      expect(index, isNot(contains(wrongProvinceNumber)));
      expect(index, isNot(contains('?ICP?2026016828?')));
      expect(index, contains('https://beian.miit.gov.cn/'));
      expect(index, contains('target="_blank"'));
      expect(index, contains('rel="noopener noreferrer"'));
    },
  );
}
