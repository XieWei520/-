import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phase6 mysql schema inventory script is read-only and gated', () {
    final script = File('scripts/ops/phase6_mysql_schema_inventory.ps1');

    expect(script.existsSync(), isTrue);

    final content = script.readAsStringSync();
    expect(content, contains(r'[switch]$Run'));
    expect(content, contains('Dry run only. Add -Run to execute read-only MySQL schema inventory.'));
    expect(content, contains('Validate-RemoteHostToken'));
    expect(content, contains('docker compose --env-file .env exec -T mysql'));
    expect(content, contains(r'exec -T mysql sh -lc'));
    expect(content, contains(r'SET @db := \"`$1\"'));
    expect(content, contains('information_schema.tables'));
    expect(content, contains('information_schema.statistics'));
    expect(content, contains('information_schema.partitions'));
    expect(content, contains('information_schema.columns'));
    expect(content, contains('gorp_migrations'));
    expect(content, contains('app_config'));
    expect(content, contains('maintenance_enabled'));
    expect(content, contains('maintenance_title'));
    expect(content, contains('maintenance_message'));
    expect(content, contains('common-20260520-01.sql'));
    expect(content, contains('user-20260520-01.sql'));
    expect(content, contains('required_phase6_table'));
    expect(content, contains('required_phase6_index'));
    expect(content, contains('phase6_migration_record'));
    expect(content, contains('phase6_migration_record_status'));
    expect(content, contains('LEFT JOIN gorp_migrations'));
    expect(content, contains('SHOW DATABASES'));
    expect(content, contains('SELECT @db AS selected_database'));
    expect(content, contains('COUNT(*) AS table_count'));
    expect(content, contains('SELECT TABLE_NAME'));
    expect(content, contains('SELECT TABLE_NAME, COLUMN_NAME'));
    expect(content, contains('SELECT TABLE_NAME AS purge_related_table'));

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
}
