import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('server SQL gate scans remote Go SQL risks and slow-query evidence', () {
    final script = File('scripts/ops/phase5_server_sql_gate.ps1');

    expect(script.existsSync(), isTrue);

    final content = script.readAsStringSync();
    expect(content, contains('RemoteHost'));
    expect(content, contains('ubuntu@42.194.218.158'));
    expect(content, contains('RemoteSourceRoot'));
    expect(content, contains('/opt/wukongim-prod/src'));
    expect(content, contains('server_sql_gate.txt'));
    expect(content, contains('Invoke-RemoteBash'));
    expect(content, contains('fmt.Sprintf'));
    expect(content, contains('SQL_RISK'));
    expect(content, contains('slow-query'));
    expect(content, contains('long_query_time'));
    expect(content, contains('slow_query_log'));
    expect(content, contains('exit 1'));
  });

  test('release preflight captures every Phase 5 required gate', () {
    final script = File('scripts/ops/phase5_release_preflight.ps1');

    expect(script.existsSync(), isTrue);

    final content = script.readAsStringSync();
    expect(content, contains('build\\phase5-preflight'));
    expect(content, contains('Invoke-Gate'));
    expect(content, contains('flutter analyze'));
    expect(content, contains('test/scripts/ops/phase5_governance_preflight_test.dart'));
    expect(content, contains('test/modules/chat/chat_page_scene_flow_test.dart'));
    expect(content, contains('docker compose config'));
    expect(content, contains('nginx -t'));
    expect(content, contains('scripts/smoke_test.py --base-url http://127.0.0.1 --timeout 10'));
    expect(content, contains('remote_public_web_smoke'));
    expect(content, contains('remote_websocket_handshake'));
    expect(content, contains('phase5_server_sql_gate.ps1'));
    expect(content, contains('failed-gates'));
    expect(content, contains('exit 1'));
  });

  test('release preflight runbook points operators at the one-key gate', () {
    final doc = File('docs/production/phase-5-release-preflight.md');

    expect(doc.existsSync(), isTrue);

    final content = doc.readAsStringSync();
    expect(content, contains('phase5_release_preflight.ps1'));
    expect(content, contains('phase5_server_sql_gate.ps1'));
    expect(content, contains('build/phase5-preflight'));
    expect(content, contains('server_sql_gate.txt'));
  });
}