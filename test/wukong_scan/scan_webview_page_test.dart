import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_scan/scan_webview_page.dart';

void main() {
  test('scan webview authorization avatar uses WKAvatar cache path', () {
    final source = File(
      'lib/wukong_scan/scan_webview_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('Image.network(')));
    expect(source, contains('WKAvatar('));
  });

  group('normalizeScanWebviewInitialUri', () {
    test('accepts absolute http and https URLs', () {
      expect(
        normalizeScanWebviewInitialUri(
          ' https://example.com/path?q=1 ',
        )!.toString(),
        'https://example.com/path?q=1',
      );
      expect(
        normalizeScanWebviewInitialUri('http://example.com')!.toString(),
        'http://example.com',
      );
    });

    test('rejects blank, non-web, and schemeless URLs', () {
      expect(normalizeScanWebviewInitialUri(''), isNull);
      expect(normalizeScanWebviewInitialUri('javascript:alert(1)'), isNull);
      expect(normalizeScanWebviewInitialUri('data:text/html,hello'), isNull);
      expect(normalizeScanWebviewInitialUri('file:///tmp/a.html'), isNull);
      expect(normalizeScanWebviewInitialUri('example.com/path'), isNull);
    });
  });
}
