import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:juliang_monitor_shell_app/main.dart';
import 'package:local_monitor_shell_core/local_monitor_shell_core.dart';

void main() {
  test('default shell configuration targets the Juliang aggregate panel', () {
    expect(defaultJuliangRuntimeUrl, 'https://msg.juliang888.top/');
    expect(defaultJuliangShellPort, 18796);
    expect(defaultJuliangShellToken, 'wukong-juliang-shell-dev');
  });

  test(
    'initial shell status is online login-required strict incognito',
    () async {
      final base = await Directory.systemTemp.createTemp('juliang_shell_test_');
      addTearDown(() async {
        if (await base.exists()) {
          await base.delete(recursive: true);
        }
      });
      final runtime = await prepareJuliangShellRuntime(base);
      final store = ShellStore(runtime.snapshotFile);

      await initializeJuliangShellStore(
        store,
        clock: () => DateTime.parse('2026-05-17T03:00:00Z'),
      );
      final snapshot = await store.load();

      expect(snapshot.shellState, 'online');
      expect(snapshot.loginState, 'login_required');
      expect(snapshot.captureState, 'stopped');
      expect(snapshot.hookState, 'healthy');
      expect(snapshot.runtimeUrl, defaultJuliangRuntimeUrl);
      expect(snapshot.pageTitle, juliangShellAppTitle);
      expect(snapshot.webviewAvailable, isFalse);
      expect(snapshot.shellMode, 'desktop_shell');
      expect(snapshot.pageKind, 'login');
      expect(snapshot.probeDiagnostics['strict_incognito'], isTrue);
      expect(snapshot.probeDiagnostics['requires_manual_login'], isTrue);
      expect(snapshot.probeDiagnostics['reuses_cookies'], isFalse);
      expect(snapshot.probeDiagnostics['reuses_local_storage'], isFalse);
      expect(snapshot.probeDiagnostics['reuses_history'], isFalse);
      expect(snapshot.probeDiagnostics['persistent_profile_directory'], isNull);
      expect(snapshot.probeDiagnostics['persistent_session_directory'], isNull);
    },
  );

  test('/status uses the Juliang shell bearer token', () async {
    final base = await Directory.systemTemp.createTemp('juliang_shell_test_');
    addTearDown(() async {
      if (await base.exists()) {
        await base.delete(recursive: true);
      }
    });
    final runtime = await prepareJuliangShellRuntime(base);
    final store = ShellStore(runtime.snapshotFile);
    await initializeJuliangShellStore(store);
    final shellServer = createJuliangShellServer(store: store, port: 0);
    final boundServer = await shellServer.start();
    addTearDown(shellServer.close);
    final uri = Uri.parse(
      'http://${boundServer.address.address}:${boundServer.port}/status',
    );
    final client = HttpClient();
    addTearDown(client.close);

    final unauthorizedRequest = await client.getUrl(uri);
    final unauthorizedResponse = await unauthorizedRequest.close();
    expect(unauthorizedResponse.statusCode, HttpStatus.unauthorized);
    await utf8.decodeStream(unauthorizedResponse);

    final request = await client.getUrl(uri);
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $defaultJuliangShellToken',
    );
    final response = await request.close();
    final body = jsonDecode(await utf8.decodeStream(response));

    expect(response.statusCode, HttpStatus.ok);
    expect(body['runtime_url'], defaultJuliangRuntimeUrl);
    expect(body['login_state'], 'login_required');
    expect(body['capture_state'], 'stopped');
    expect(body['probe_diagnostics']['strict_incognito'], isTrue);
  });

  test('webview user data path uses disposable session directory', () async {
    final base = await Directory.systemTemp.createTemp('juliang_shell_test_');
    addTearDown(() async {
      if (await base.exists()) {
        await base.delete(recursive: true);
      }
    });

    final runtime = await prepareJuliangShellRuntime(base);

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
      final base = await Directory.systemTemp.createTemp('juliang_shell_test_');
      addTearDown(() async {
        if (await base.exists()) {
          await base.delete(recursive: true);
        }
      });
      final runtime = await prepareJuliangShellRuntime(base);
      final order = <String>[];

      final deleted = await disposeJuliangShellRuntimeResources(
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
