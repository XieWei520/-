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
    expect(content, contains(r'$Script | ssh $RemoteHost'));
    expect(content, contains("'bash -s'"));
    expect(content, isNot(contains('bash -lc')));
    expect(content, contains('fmt.Sprintf'));
    expect(content, contains('SQL_RISK'));
    expect(content, contains('looks_like_sql'));
    expect(content, contains('is_db_context'));
    expect(content, contains('SQL_RISK_SQL_LITERAL'));
    expect(content, contains('slow-query'));
    expect(content, contains('long_query_time'));
    expect(content, contains('slow_query_log'));
    expect(content, contains('exit 1'));
  });

  test('server SQL gate ships Python probe via base64 environment variable', () {
    final script = File('scripts/ops/phase5_server_sql_gate.ps1');

    expect(script.existsSync(), isTrue);

    final content = script.readAsStringSync();
    expect(content, contains('[Convert]::ToBase64String'));
    expect(content, contains('PHASE5_SQL_PROBE_B64'));
    expect(content, contains('python3 -c'));
    expect(content, contains('base64.b64decode'));
    expect(content, isNot(contains("python3 - <<'PY'")));
  });

  test('release preflight captures every Phase 5 required gate', () {
    final script = File('scripts/ops/phase5_release_preflight.ps1');

    expect(script.existsSync(), isTrue);

    final content = script.readAsStringSync();
    expect(content, contains('build\\phase5-preflight'));
    expect(content, contains('Invoke-Gate'));
    expect(content, contains('flutter analyze'));
    expect(
      content,
      contains('test/scripts/ops/phase5_governance_preflight_test.dart'),
    );
    expect(
      content,
      contains('test/modules/chat/chat_page_scene_flow_test.dart'),
    );
    expect(content, contains('docker compose config'));
    expect(content, contains('Invoke-RemoteBash'));
    expect(content, contains(r'$Script | ssh $RemoteHost'));
    expect(content, contains("'bash -s'"));
    expect(content, isNot(contains('bash -lc')));
    expect(content, contains('nginx -t'));
    expect(content, contains('docker compose exec -T nginx nginx -t'));
    expect(content, isNot(contains('wukongim-prod-nginx')));
    expect(
      content,
      contains(
        r'scripts/smoke_test.py --base-url https://`$public_domain --timeout 10',
      ),
    );
    expect(content, isNot(contains('--base-url http://127.0.0.1')));
    expect(content, contains('remote_public_web_smoke'));
    expect(content, contains('remote_websocket_handshake'));
    expect(content, contains('phase5_server_sql_gate.ps1'));
    expect(content, contains('server_sql_gate_child'));
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
