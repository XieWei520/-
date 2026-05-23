import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phase6 apply migrations script is explicitly write gated', () {
    final script = File('scripts/ops/phase6_apply_migrations.ps1');

    expect(script.existsSync(), isTrue);

    final content = script.readAsStringSync();
    expect(content, contains(r'[switch]$Run'));
    expect(content, contains(r'[switch]$AllowProductionMigration'));
    expect(content, contains('Dry run only. Add -Run and -AllowProductionMigration'));
    expect(content, contains('Refusing to apply production migrations without -AllowProductionMigration'));
    expect(content, contains('/home/ubuntu/wukongim-phase6-backups/20260520T125818Z'));
    expect(content, contains('sha256sum -c'));
    expect(content, contains('phase6_migration_readiness=ready_for_phase6_migration'));
    expect(content, contains('common-20260520-01.sql'));
    expect(content, contains('user-20260520-01.sql'));
    expect(content, contains('ALTER TABLE `app_config`'));
    expect(content, contains('CREATE TABLE IF NOT EXISTS `admin_audit_log`'));
    expect(content, contains('CREATE TABLE IF NOT EXISTS `user_purge_job`'));
    expect(content, contains('CREATE TABLE IF NOT EXISTS `user_purge_verification`'));
    expect(content, contains('INSERT INTO `gorp_migrations`'));
    expect(content, contains('ON DUPLICATE KEY UPDATE'));
    expect(content, contains('phase6_apply_migrations=applied'));

    expect(content, isNot(contains('DROP ')));
    expect(content, isNot(contains('DELETE ')));
    expect(content, isNot(contains('TRUNCATE ')));
    expect(content, isNot(contains('docker compose restart')));
    expect(content, isNot(contains('docker compose up')));
    expect(content, isNot(contains('docker compose down')));
  });

  test('phase6 release spec documents production migration gate', () {
    final spec = File('docs/specs/admin-phase-6-release-hardening.md');

    expect(spec.existsSync(), isTrue);

    final content = spec.readAsStringSync();
    expect(content, contains('phase6_apply_migrations.ps1'));
    expect(content, contains('AllowProductionMigration'));
    expect(content, contains('phase6_apply_migrations=applied'));
  });

  test('phase6 apply migrations dry-run preserves MySQL quoted identifiers',
      () async {
    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        'scripts\\ops\\phase6_apply_migrations.ps1',
      ],
      workingDirectory: Directory.current.path,
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final output = result.stdout.toString();
    expect(output, contains('ALTER TABLE `app_config`'));
    expect(output, contains('CREATE TABLE IF NOT EXISTS `admin_audit_log`'));
    expect(output, contains('CREATE TABLE IF NOT EXISTS `user_purge_job`'));
    expect(output, contains('CREATE TABLE IF NOT EXISTS `user_purge_verification`'));

    final illegalControlChars = output.codeUnits.where(
      (codeUnit) =>
          codeUnit < 32 &&
          codeUnit != 9 &&
          codeUnit != 10 &&
          codeUnit != 13,
    );
    expect(illegalControlChars, isEmpty);
  }, skip: !Platform.isWindows);
}
