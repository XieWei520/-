import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phase6 backend migrations contain expected additive objects', () {
    final commonMigration = File(
      '.codex-backend-work/src/modules/common/sql/common-20260520-01.sql',
    );
    final userMigration = File(
      '.codex-backend-work/src/modules/user/sql/user-20260520-01.sql',
    );

    expect(commonMigration.existsSync(), isTrue);
    expect(userMigration.existsSync(), isTrue);

    final common = commonMigration.readAsStringSync();
    expect(common, contains('-- +migrate Up'));
    expect(common, contains('-- +migrate Down'));
    expect(common, contains('ALTER TABLE `app_config`'));
    expect(common, contains('ADD COLUMN `maintenance_enabled`'));
    expect(common, contains('ADD COLUMN `maintenance_title`'));
    expect(common, contains('ADD COLUMN `maintenance_message`'));
    expect(common, contains('CREATE TABLE IF NOT EXISTS `admin_audit_log`'));
    expect(common, contains('CREATE INDEX `admin_audit_log_target_idx`'));
    expect(common, contains('CREATE INDEX `admin_audit_log_operator_idx`'));
    expect(common, contains('CREATE INDEX `admin_audit_log_action_idx`'));

    final user = userMigration.readAsStringSync();
    expect(user, contains('-- +migrate Up'));
    expect(user, contains('-- +migrate Down'));
    expect(user, contains('CREATE TABLE IF NOT EXISTS `user_purge_job`'));
    expect(user, contains('CREATE UNIQUE INDEX `user_purge_job_job_id_uidx`'));
    expect(user, contains('CREATE INDEX `user_purge_job_uid_created_at_idx`'));
    expect(user, contains('CREATE INDEX `user_purge_job_operator_created_at_idx`'));
    expect(user, contains('CREATE TABLE IF NOT EXISTS `user_purge_verification`'));
    expect(user, contains('CREATE INDEX `user_purge_verification_job_idx`'));
    expect(user, contains('preview_json'));
    expect(user, contains('result_json'));
    expect(user, contains('error'));
  });

  test('phase6 release spec documents migration risks and backup gate', () {
    final spec = File('docs/specs/admin-phase-6-release-hardening.md');

    expect(spec.existsSync(), isTrue);

    final content = spec.readAsStringSync();
    expect(content, contains('common-20260520-01.sql'));
    expect(content, contains('user-20260520-01.sql'));
    expect(content, contains('phase6_migration_backup_plan.ps1'));
    expect(content, contains('phase6_mysql_schema_inventory.ps1 -Run'));
    expect(content, contains('ALTER TABLE app_config ADD COLUMN'));
    expect(content, contains('CREATE INDEX'));
    expect(content, contains('not idempotent'));
    expect(content, contains('Do not run Down'));
  });
}
