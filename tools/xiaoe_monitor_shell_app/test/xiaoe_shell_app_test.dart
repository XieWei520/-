import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_monitor_shell_core/local_monitor_shell_core.dart';
import 'package:xiaoe_monitor_shell_app/main.dart';

void main() {
  test('default shell configuration targets XiaoeTech muti_index', () {
    expect(defaultXiaoeRuntimeUrl, 'https://study.xiaoe-tech.com/#/muti_index');
    expect(defaultXiaoeShellPort, 18806);
    expect(defaultXiaoeShellToken, 'wukong-xiaoe-shell-dev');
    expect(xiaoeShellAppTitle, '小鹅通信息监控');
  });

  test(
    'initial shell status waits for manual target page navigation',
    () async {
      final base = await Directory.systemTemp.createTemp('xiaoe_shell_test_');
      addTearDown(() async {
        if (await base.exists()) {
          await base.delete(recursive: true);
        }
      });
      final runtime = await prepareXiaoeShellRuntime(base);
      final store = ShellStore(runtime.snapshotFile);

      await initializeXiaoeShellStore(
        store,
        clock: () => DateTime.parse('2026-05-17T08:00:00Z'),
      );
      final snapshot = await store.load();

      expect(snapshot.shellState, 'online');
      expect(snapshot.captureState, 'stopped');
      expect(snapshot.loginState, 'unknown');
      expect(snapshot.hookState, 'healthy');
      expect(snapshot.runtimeUrl, defaultXiaoeRuntimeUrl);
      expect(snapshot.pageTitle, xiaoeShellAppTitle);
      expect(snapshot.webviewAvailable, isFalse);
      expect(snapshot.shellMode, 'desktop_shell');
      expect(snapshot.pageKind, 'muti_index');
      expect(snapshot.probeDiagnostics['target_url'], defaultXiaoeRuntimeUrl);
      expect(snapshot.probeDiagnostics['manual_target_page_required'], isTrue);
      expect(snapshot.probeDiagnostics['requires_login_session'], isTrue);
      expect(snapshot.probeDiagnostics['captures_live_comments'], isTrue);
      expect(snapshot.probeDiagnostics['captures_circle_course_files'], isTrue);
      expect(snapshot.probeDiagnostics['file_size_limit_bytes'], 20971520);
    },
  );

  test('/status uses the XiaoeTech shell bearer token', () async {
    final base = await Directory.systemTemp.createTemp('xiaoe_shell_test_');
    addTearDown(() async {
      if (await base.exists()) {
        await base.delete(recursive: true);
      }
    });
    final runtime = await prepareXiaoeShellRuntime(base);
    final store = ShellStore(runtime.snapshotFile);
    await initializeXiaoeShellStore(store);
    final shellServer = createXiaoeShellServer(store: store, port: 0);
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
      'Bearer $defaultXiaoeShellToken',
    );
    final response = await request.close();
    final body = jsonDecode(await utf8.decodeStream(response));

    expect(response.statusCode, HttpStatus.ok);
    expect(body['runtime_url'], defaultXiaoeRuntimeUrl);
    expect(body['login_state'], 'unknown');
    expect(body['capture_state'], 'stopped');
    expect(body['probe_diagnostics']['manual_target_page_required'], isTrue);
  });

  test(
    'runtime uses a stable WebView profile for XiaoeTech login session',
    () async {
      final base = await Directory.systemTemp.createTemp('xiaoe_shell_test_');
      addTearDown(() async {
        if (await base.exists()) {
          await base.delete(recursive: true);
        }
      });

      final runtime = await prepareXiaoeShellRuntime(base);

      expect(await runtime.profileDirectory.exists(), isTrue);
      expect(runtime.webviewUserDataPath, runtime.profileDirectory.path);
      expect(
        runtime.profileDirectory.path,
        contains('xiaoe_monitor_shell_profile'),
      );
      expect(
        runtime.snapshotFile.path.startsWith(runtime.profileDirectory.path),
        isFalse,
      );
    },
  );
}
