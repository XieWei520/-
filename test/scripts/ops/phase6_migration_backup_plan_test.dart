import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phase6 migration backup plan is dry-run first and write gated', () {
    final script = File('scripts/ops/phase6_migration_backup_plan.ps1');

    expect(script.existsSync(), isTrue);

    final content = script.readAsStringSync();
    expect(content, contains(r'[switch]$Run'));
    expect(content, contains(r'[switch]$AllowProductionWrites'));
    expect(content, contains('Dry run only. Add -Run and -AllowProductionWrites'));
    expect(content, contains('Refusing to write production backups without -AllowProductionWrites'));
    expect(content, contains('Validate-RemoteHostToken'));
    expect(content, contains('BatchMode=yes'));
    expect(content, contains('StrictHostKeyChecking=accept-new'));
    expect(content, contains('mysqldump'));
    expect(content, contains('--single-transaction'));
    expect(content, contains('--routines'));
    expect(content, contains('--triggers'));
    expect(content, contains('--events'));
    expect(content, contains('< /dev/null | gzip -c'));
    expect(content, contains('database_dump_done='));
    expect(content, contains('source_archive_done='));
    expect(content, contains('compose_archive_done='));
    expect(content, contains('tar --exclude'));
    expect(content, contains("--exclude='*.log'"));
    expect(content, contains("--exclude='src/deploy/production/rendered/coturn-certs'"));
    expect(content, contains("--exclude='production/rendered/coturn-certs'"));
    expect(content, contains("--exclude='production/data'"));
    expect(content, contains("--exclude='production/logs'"));
    expect(content, contains('sha256sum'));
    expect(content, contains('/home/ubuntu/wukongim-phase6-backups'));
    expect(content, contains('umask 077'));
    expect(content, contains('chmod 700'));

    expect(content, isNot(contains('docker compose restart')));
    expect(content, isNot(contains('docker compose up')));
    expect(content, isNot(contains('docker compose down')));
    expect(content, isNot(contains('migrate up')));
    expect(content, isNot(contains('DROP ')));
    expect(content, isNot(contains('DELETE ')));
    expect(content, isNot(contains('UPDATE ')));
    expect(content, isNot(contains('INSERT ')));
    expect(content, isNot(contains('TRUNCATE ')));
    expect(content, isNot(contains('rm -rf')));
  });
}
