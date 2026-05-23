import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phase6 migration readiness gate is read-only and run gated', () {
    final script = File('scripts/ops/phase6_migration_readiness_gate.ps1');

    expect(script.existsSync(), isTrue);

    final content = script.readAsStringSync();
    expect(content, contains(r'[switch]$Run'));
    expect(content, contains('Dry run only. Add -Run to execute read-only Phase 6 migration readiness gate.'));
    expect(content, contains('Validate-RemoteHostToken'));
    expect(content, contains('BatchMode=yes'));
    expect(content, contains('StrictHostKeyChecking=accept-new'));
    expect(content, contains('phase6_migration_readiness=ready_for_phase6_migration'));
    expect(content, contains('phase6_migration_readiness=already_migrated'));
    expect(content, contains('phase6_migration_readiness=inconsistent_phase6_schema'));
    expect(content, contains('phase6_migration_readiness=blocked_missing_gorp_migrations'));
    expect(content, contains('required_tables_present='));
    expect(content, contains('maintenance_columns_present='));
    expect(content, contains('required_indexes_present='));
    expect(content, contains('phase6_records_present='));
    expect(content, contains('run_mysql_scalar'));
    expect(content, contains(r"printf '%s\n'"));
    expect(content, contains('gorp_migrations'));
    expect(content, contains('common-20260520-01.sql'));
    expect(content, contains('user-20260520-01.sql'));

    expect(content, isNot(contains('DROP ')));
    expect(content, isNot(contains('DELETE ')));
    expect(content, isNot(contains('UPDATE ')));
    expect(content, isNot(contains('INSERT ')));
    expect(content, isNot(contains('ALTER ')));
    expect(content, isNot(contains('CREATE ')));
    expect(content, isNot(contains('TRUNCATE ')));
    expect(content, isNot(contains('docker compose restart')));
    expect(content, isNot(contains('docker compose up')));
    expect(content, isNot(contains('docker compose down')));
  });

  test('phase6 release spec includes migration readiness gate', () {
    final spec = File('docs/specs/admin-phase-6-release-hardening.md');

    expect(spec.existsSync(), isTrue);

    final content = spec.readAsStringSync();
    expect(content, contains('phase6_migration_readiness_gate.ps1'));
    expect(content, contains('ready_for_phase6_migration'));
    expect(content, contains('already_migrated'));
    expect(content, contains('inconsistent_phase6_schema'));
  });
}
