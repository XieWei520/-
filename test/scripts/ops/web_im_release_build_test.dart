import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web im release build script builds independent /im PWA artifacts', () {
    final script = File('scripts/ops/build_web_im_release.ps1');
    expect(script.existsSync(), isTrue);

    final content = script.readAsStringSync();
    expect(content, contains(r"[string]$WebImDir = 'web_im'"));
    expect(content, contains('pnpm --dir'));
    expect(content, contains('build'));
    expect(content, contains('dist'));
    expect(content, contains('index.html'));
    expect(content, contains('manifest.webmanifest'));
    expect(content, contains('sw.js'));
    expect(content, contains('offline.html'));
    expect(content, contains('WEB_IM_RELEASE_DIR='));
  });
}
