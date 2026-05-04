import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Flutter Web release pruner removes unused renderer artifacts safely',
    () {
      final script = File('scripts/ops/prune_flutter_web_release.ps1');

      expect(script.existsSync(), isTrue);

      final content = script.readAsStringSync();
      expect(content, contains(r'[switch]$DryRun'));
      expect(content, contains('flutter_bootstrap.js'));
      expect(content, contains('main.dart.js'));
      expect(content, contains('"renderer":"canvaskit"'));
      expect(content, contains('canvaskit/canvaskit.js'));
      expect(content, contains('canvaskit/canvaskit.wasm'));
      expect(content, contains('canvaskit/chromium/canvaskit.js'));
      expect(content, contains('canvaskit/chromium/canvaskit.wasm'));
      expect(content, contains('*.js.symbols'));
      expect(content, contains('skwasm*'));
      expect(content, contains('wimp*'));
      expect(content, contains(r'[switch]$KeepBundledChineseFont'));
      expect(content, contains('WKNotoSansSC'));
      expect(content, contains('noto_sans_sc_vf.ttf'));
      expect(content, contains('FontManifest.json'));
      expect(content, contains('ConvertFrom-Json'));
      expect(content, contains('ConvertTo-Json'));
      expect(content, contains('Remove-Item'));
      expect(content, isNot(contains(r'Remove-Item -Recurse $BuildWebDir')));
    },
  );

  test(
    'Flutter Web release pruner removes bundled Chinese font safely',
    () async {
      final script = File('scripts/ops/prune_flutter_web_release.ps1').absolute;
      final temp = Directory.systemTemp.createTempSync('wk_web_prune_test_');

      try {
        void writeText(String relativePath, String value) {
          final file = File('${temp.path}/$relativePath');
          file.parent.createSync(recursive: true);
          file.writeAsStringSync(value);
        }

        void writeBytes(String relativePath, List<int> value) {
          final file = File('${temp.path}/$relativePath');
          file.parent.createSync(recursive: true);
          file.writeAsBytesSync(value);
        }

        writeText(
          'flutter_bootstrap.js',
          '_flutter.buildConfig={"builds":[{"renderer":"canvaskit"}]};',
        );
        writeText(
          'main.dart.js',
          '["Microsoft YaHei UI","PingFang SC","Segoe UI Emoji"]',
        );
        writeBytes('canvaskit/canvaskit.js', [1]);
        writeBytes('canvaskit/canvaskit.wasm', [1]);
        writeBytes('canvaskit/chromium/canvaskit.js', [1]);
        writeBytes('canvaskit/chromium/canvaskit.wasm', [1]);
        writeBytes('canvaskit/skwasm.js', [1]);
        writeBytes('canvaskit/wimp.wasm', [1]);
        writeBytes('canvaskit/canvaskit.js.symbols', [1]);
        writeText(
          'assets/FontManifest.json',
          jsonEncode([
            {
              'family': 'WKRMedium',
              'fonts': [
                {'asset': 'assets/reference_ui/fonts/rmedium.ttf'},
              ],
            },
            {
              'family': 'WKChineseWebSubset',
              'fonts': [
                {
                  'asset':
                      'assets/reference_ui/fonts/noto_sans_sc_web_subset.ttf',
                },
              ],
            },
            {
              'family': 'WKNotoSansSC',
              'fonts': [
                {'asset': 'assets/reference_ui/fonts/noto_sans_sc_vf.ttf'},
              ],
            },
          ]),
        );
        writeBytes('assets/assets/reference_ui/fonts/rmedium.ttf', [1]);
        writeBytes(
          'assets/assets/reference_ui/fonts/noto_sans_sc_web_subset.ttf',
          [1, 2],
        );
        writeBytes('assets/assets/reference_ui/fonts/noto_sans_sc_vf.ttf', [
          1,
          2,
          3,
          4,
        ]);

        final result = await Process.run('powershell', [
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          script.path,
          '-BuildWebDir',
          temp.path,
        ]);

        expect(
          result.exitCode,
          0,
          reason: 'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
        );
        expect(File('${temp.path}/canvaskit/skwasm.js').existsSync(), isFalse);
        expect(File('${temp.path}/canvaskit/wimp.wasm').existsSync(), isFalse);
        expect(
          File('${temp.path}/canvaskit/canvaskit.js.symbols').existsSync(),
          isFalse,
        );
        expect(
          File(
            '${temp.path}/assets/assets/reference_ui/fonts/noto_sans_sc_vf.ttf',
          ).existsSync(),
          isFalse,
        );

        final manifest =
            jsonDecode(
                  File(
                    '${temp.path}/assets/FontManifest.json',
                  ).readAsStringSync(),
                )
                as List<dynamic>;
        expect(
          manifest.map((entry) => (entry as Map<String, dynamic>)['family']),
          isNot(contains('WKNotoSansSC')),
        );
        expect(
          manifest.map((entry) => (entry as Map<String, dynamic>)['family']),
          contains('WKChineseWebSubset'),
        );
        expect(
          File('${temp.path}/canvaskit/canvaskit.js').existsSync(),
          isTrue,
        );
        expect(
          File('${temp.path}/canvaskit/chromium/canvaskit.wasm').existsSync(),
          isTrue,
        );
      } finally {
        temp.deleteSync(recursive: true);
      }
    },
  );

  test(
    'Flutter Web release pruner preserves Skwasm runtime artifacts for Wasm builds',
    () async {
      final script = File('scripts/ops/prune_flutter_web_release.ps1').absolute;
      final temp = Directory.systemTemp.createTempSync(
        'wk_web_wasm_prune_test_',
      );

      try {
        void writeText(String relativePath, String value) {
          final file = File('${temp.path}/$relativePath');
          file.parent.createSync(recursive: true);
          file.writeAsStringSync(value);
        }

        void writeBytes(String relativePath, List<int> value) {
          final file = File('${temp.path}/$relativePath');
          file.parent.createSync(recursive: true);
          file.writeAsBytesSync(value);
        }

        writeText('flutter_bootstrap.js', '''
_flutter.buildConfig={"builds":[
  {"compileTarget":"dart2wasm","renderer":"skwasm","mainWasmPath":"main.dart.wasm","jsSupportRuntimePath":"main.dart.mjs"},
  {"compileTarget":"dart2js","renderer":"canvaskit","mainJsPath":"main.dart.js"}
]};
''');
        writeText(
          'main.dart.js',
          '["Microsoft YaHei UI","PingFang SC","Segoe UI Emoji"]',
        );
        writeBytes('main.dart.wasm', [1]);
        writeBytes('main.dart.mjs', [1]);
        writeBytes('canvaskit/canvaskit.js', [1]);
        writeBytes('canvaskit/canvaskit.wasm', [1]);
        writeBytes('canvaskit/chromium/canvaskit.js', [1]);
        writeBytes('canvaskit/chromium/canvaskit.wasm', [1]);
        writeBytes('canvaskit/skwasm.js', [1]);
        writeBytes('canvaskit/skwasm.wasm', [1]);
        writeBytes('canvaskit/skwasm_heavy.js', [1]);
        writeBytes('canvaskit/skwasm_heavy.wasm', [1]);
        writeBytes('canvaskit/wimp.js', [1]);
        writeBytes('canvaskit/wimp.wasm', [1]);
        writeBytes('canvaskit/skwasm.js.symbols', [1]);
        writeBytes('canvaskit/wimp.js.symbols', [1]);
        writeText(
          'assets/FontManifest.json',
          jsonEncode([
            {
              'family': 'WKNotoSansSC',
              'fonts': [
                {'asset': 'assets/reference_ui/fonts/noto_sans_sc_vf.ttf'},
              ],
            },
          ]),
        );

        final result = await Process.run('powershell', [
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          script.path,
          '-BuildWebDir',
          temp.path,
        ]);

        expect(
          result.exitCode,
          0,
          reason: 'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
        );
        expect(File('${temp.path}/canvaskit/skwasm.js').existsSync(), isTrue);
        expect(File('${temp.path}/canvaskit/skwasm.wasm').existsSync(), isTrue);
        expect(
          File('${temp.path}/canvaskit/skwasm_heavy.js').existsSync(),
          isTrue,
        );
        expect(
          File('${temp.path}/canvaskit/skwasm_heavy.wasm').existsSync(),
          isTrue,
        );
        expect(File('${temp.path}/canvaskit/wimp.js').existsSync(), isTrue);
        expect(File('${temp.path}/canvaskit/wimp.wasm').existsSync(), isTrue);
        expect(
          File('${temp.path}/canvaskit/skwasm.js.symbols').existsSync(),
          isFalse,
        );
        expect(
          File('${temp.path}/canvaskit/wimp.js.symbols').existsSync(),
          isFalse,
        );
      } finally {
        temp.deleteSync(recursive: true);
      }
    },
  );
}
