import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mengxia_monitor_shell_app/main.dart';

void main() {
  test('default runtime URL is the Mengxia login page', () {
    expect(
      defaultMengxiaRuntimeUrl,
      'https://mx.2026.naaifu.cn/#/pages/login/login',
    );
  });

  test('product title is MX monitor without exposing the runtime URL', () {
    expect(mengxiaShellAppTitle, 'MX信息监控');
    expect(mengxiaShellAppTitle, isNot(contains('mx.2026.naaifu.cn')));
  });

  test('windows package metadata uses MX monitor product name', () {
    final cmake = File('windows/CMakeLists.txt').readAsStringSync();
    final runnerCmake = File(
      'windows/runner/CMakeLists.txt',
    ).readAsStringSync();
    final runnerMain = File('windows/runner/main.cpp').readAsStringSync();
    final resources = File('windows/runner/Runner.rc').readAsStringSync();

    expect(cmake, contains('set(BINARY_NAME "mengxia_monitor_shell_app")'));
    expect(cmake, contains('set(PRODUCT_NAME "MX信息监控")'));
    expect(cmake, contains('file(REMOVE'));
    expect(cmake, contains('mengxia_monitor_shell_app.exe'));
    expect(
      runnerCmake,
      contains(
        r'set_target_properties(${BINARY_NAME} PROPERTIES OUTPUT_NAME "${PRODUCT_NAME}")',
      ),
    );
    expect(
      runnerMain,
      contains(r'window.Create(L"MX\u4FE1\u606F\u76D1\u63A7"'),
    );
    expect(resources, contains('VALUE "FileDescription", "MX信息监控"'));
    expect(resources, contains('VALUE "OriginalFilename", "MX信息监控.exe"'));
    expect(resources, contains('VALUE "ProductName", "MX信息监控"'));
  });

  test('webview user data path uses disposable session directory', () async {
    final base = await Directory.systemTemp.createTemp('mengxia_runtime_test_');
    addTearDown(() async {
      if (await base.exists()) {
        await base.delete(recursive: true);
      }
    });

    final runtime = await prepareMengxiaShellRuntime(base);

    expect(await runtime.sessionDirectory.exists(), isTrue);
    expect(runtime.webviewUserDataPath, runtime.sessionDirectory.path);
    expect(
      runtime.snapshotFile.path.startsWith(runtime.sessionDirectory.path),
      isFalse,
    );
  });

  test(
    'runtime cleanup waits for webview disposal before deleting session',
    () async {
      final base = await Directory.systemTemp.createTemp(
        'mengxia_runtime_test_',
      );
      addTearDown(() async {
        if (await base.exists()) {
          await base.delete(recursive: true);
        }
      });
      final runtime = await prepareMengxiaShellRuntime(base);
      final order = <String>[];

      final deleted = await disposeMengxiaShellRuntimeResources(
        sessionDirectory: runtime.sessionDirectory,
        cancelSubscriptions: <Future<void> Function()>[
          () async => order.add('subscription'),
        ],
        closeServer: () async => order.add('server'),
        disposeWebview: () async {
          order.add('webview');
          expect(await runtime.sessionDirectory.exists(), isTrue);
        },
        cleanupRetryDelays: const <Duration>[Duration.zero],
      );

      expect(deleted, isTrue);
      expect(order, <String>['subscription', 'server', 'webview']);
      expect(await runtime.sessionDirectory.exists(), isFalse);
    },
  );
}
