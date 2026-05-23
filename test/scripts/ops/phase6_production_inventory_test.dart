import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phase6 production inventory script is read-only and gated', () {
    final script = File('scripts/ops/phase6_production_inventory.ps1');

    expect(script.existsSync(), isTrue);

    final content = script.readAsStringSync();
    expect(content, contains(r'[switch]$Run'));
    expect(content, contains('Dry run only. Add -Run to execute read-only SSH inventory.'));
    expect(content, contains('Validate-RemoteHostToken'));
    expect(content, contains('Invoke-RemoteBash'));
    expect(content, contains('BatchMode=yes'));
    expect(content, contains('StrictHostKeyChecking=accept-new'));
    expect(content, contains(r'$startInfo.Arguments ='));
    expect(content, contains('docker compose --env-file .env ps'));
    expect(content, contains('docker compose --env-file .env config --services'));
    expect(content, contains('systemctl list-units'));
    expect(content, contains('find /opt -maxdepth 4'));
    expect(content, contains(r'compose_candidates="`$(find /opt -maxdepth 4'));
    expect(content, contains(r'2>/dev/null || true)"'));

    expect(content, isNot(contains('docker compose restart')));
    expect(content, isNot(contains('docker compose up')));
    expect(content, isNot(contains('docker compose down')));
    expect(content, isNot(contains('docker compose build')));
    expect(content, isNot(contains('migrate up')));
    expect(content, isNot(contains('scp')));
    expect(content, isNot(contains('rm -rf')));
    expect(content, isNot(contains('DROP DATABASE')));
    expect(content, isNot(contains('DELETE FROM')));
    expect(content, isNot(contains(r'ArgumentList.Add($arg)')));
  });
}
