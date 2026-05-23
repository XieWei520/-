import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('p0 production readiness gate is explicit, read-only, and evidence based', () {
    final script = File('scripts/ops/p0_production_readiness_gate.ps1');

    expect(script.existsSync(), isTrue);

    final content = script.readAsStringSync();
    expect(content, contains(r'[switch]$Run'));
    expect(content, contains('Dry run only. Add -Run to execute read-only P0 production readiness gate.'));
    expect(content, contains('Validate-RemoteHostToken'));
    expect(content, contains('BatchMode=yes'));
    expect(content, contains('StrictHostKeyChecking=accept-new'));
    expect(content, contains('Invoke-ReadOnlyGate'));
    expect(content, contains('local_git_status'));
    expect(content, contains('local_secret_scan'));
    expect(content, contains('remote_container_health'));
    expect(content, contains('remote_public_port_audit'));
    expect(content, contains('remote_nginx_syntax'));
    expect(content, contains('remote_smoke_ping'));
    expect(content, contains('remote_websocket_handshake'));
    expect(content, contains('remote_backup_artifact_audit'));
    expect(content, contains('remote_observability_inventory'));
    expect(content, contains('scripts/ops/secret_log_scan.py'));
    expect(content, contains('git diff --cached'));
    expect(content, contains('docker compose ps'));
    expect(content, contains('docker compose exec -T nginx nginx -t'));
    expect(content, contains('/v1/ping'));
    expect(content, contains('/ws'));
    expect(content, contains('ss -ltnup'));
    expect(content, contains('9090'));
    expect(content, contains('3000'));
    expect(content, contains('p0_readiness=pass'));
    expect(content, contains('failed-gates.txt'));
    expect(content, contains('Evidence:'));

    expect(content, isNot(contains('docker compose restart')));
    expect(content, isNot(contains('docker compose up')));
    expect(content, isNot(contains('docker compose down')));
    expect(content, isNot(contains('docker compose build')));
    expect(content, isNot(contains('systemctl restart')));
    expect(content, isNot(contains('rm -rf')));
    expect(content, isNot(contains('DROP ')));
    expect(content, isNot(contains('DELETE ')));
    expect(content, isNot(contains('UPDATE ')));
    expect(content, isNot(contains('INSERT ')));
    expect(content, isNot(contains('ALTER ')));
    expect(content, isNot(contains('CREATE ')));
    expect(content, isNot(contains('TRUNCATE ')));
  });
}
