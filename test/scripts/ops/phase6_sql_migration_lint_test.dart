import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const scriptPath = 'scripts/ops/phase6_sql_migration_lint.ps1';

  test('phase6 SQL migration lint script documents required gates', () {
    final script = File(scriptPath);

    expect(script.existsSync(), isTrue);

    final content = script.readAsStringSync();
    expect(content, contains('-- +migrate Up'));
    expect(content, contains('-- +migrate Down'));
    expect(content, contains('information_schema.STATISTICS'));
    expect(content, contains('CREATE INDEX'));
    expect(content, contains('phase6_sql_migration_lint=pass'));
    expect(content, contains('phase6_sql_migration_lint=fail'));
  });

  test(
    'phase6 SQL migration lint dry run passes for current changes',
    () async {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptPath,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      final output = result.stdout.toString();
      expect(output, contains('phase6_sql_migration_lint=pass'));
      expect(output, contains('phase6_sql_migration_lint_files='));
    },
    skip: !Platform.isWindows,
  );

  test(
    'phase6 SQL migration lint rejects bare index migrations',
    () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'phase6_sql_migration_lint_bad_',
      );
      addTearDown(() async {
        if (tempRoot.existsSync()) {
          await tempRoot.delete(recursive: true);
        }
      });

      final sqlDir = Directory(
        '${tempRoot.path}${Platform.pathSeparator}modules'
        '${Platform.pathSeparator}message${Platform.pathSeparator}sql',
      );
      await sqlDir.create(recursive: true);
      final sqlFile = File(
        '${sqlDir.path}${Platform.pathSeparator}message-20260529-01.sql',
      );
      await sqlFile.writeAsString(
        'CREATE INDEX `message_uid_idx` ON `message` (`uid`);\n',
      );

      final result = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptPath,
        '-BackendRoot',
        tempRoot.path,
        '-All',
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, isNot(0));
      final output = '${result.stdout}\n${result.stderr}';
      expect(output, contains('missing Up'));
      expect(output, contains('missing Down'));
      expect(output, contains('phase6_sql_migration_lint=fail'));
    },
    skip: !Platform.isWindows,
  );

  test(
    'phase6 SQL migration lint rejects staged bare index migrations by default',
    () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'phase6_sql_migration_lint_staged_',
      );
      addTearDown(() async {
        if (tempRoot.existsSync()) {
          await tempRoot.delete(recursive: true);
        }
      });

      final init = await Process.run(
        'git',
        ['init'],
        workingDirectory: tempRoot.path,
      );
      expect(init.exitCode, 0, reason: init.stderr.toString());

      final sqlDir = Directory(
        '${tempRoot.path}${Platform.pathSeparator}modules'
        '${Platform.pathSeparator}message${Platform.pathSeparator}sql',
      );
      await sqlDir.create(recursive: true);
      final sqlFile = File(
        '${sqlDir.path}${Platform.pathSeparator}message-20260529-01.sql',
      );
      await sqlFile.writeAsString('''
-- +migrate Up
CREATE INDEX `message_uid_idx` ON `message` (`uid`);

-- +migrate Down
DROP INDEX `message_uid_idx` ON `message`;
''');

      final add = await Process.run(
        'git',
        ['add', 'modules/message/sql/message-20260529-01.sql'],
        workingDirectory: tempRoot.path,
      );
      expect(add.exitCode, 0, reason: add.stderr.toString());

      final result = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptPath,
        '-BackendRoot',
        tempRoot.path,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, isNot(0));
      final output = '${result.stdout}\n${result.stderr}';
      expect(output, contains('modules/message/sql/message-20260529-01.sql'));
      expect(output, contains('CREATE INDEX requires'));
      expect(output, contains('phase6_sql_migration_lint=fail'));
    },
    skip: !Platform.isWindows,
  );

  test(
    'phase6 SQL migration lint deduplicates staged and working tree overlap',
    () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'phase6_sql_migration_lint_overlap_',
      );
      addTearDown(() async {
        if (tempRoot.existsSync()) {
          await tempRoot.delete(recursive: true);
        }
      });

      final init = await Process.run(
        'git',
        ['init'],
        workingDirectory: tempRoot.path,
      );
      expect(init.exitCode, 0, reason: init.stderr.toString());

      final sqlDir = Directory(
        '${tempRoot.path}${Platform.pathSeparator}modules'
        '${Platform.pathSeparator}message${Platform.pathSeparator}sql',
      );
      await sqlDir.create(recursive: true);
      final sqlFile = File(
        '${sqlDir.path}${Platform.pathSeparator}message-20260529-01.sql',
      );
      await sqlFile.writeAsString('''
-- +migrate Up
SELECT 1;

-- +migrate Down
SELECT 1;
''');

      final addInitial = await Process.run(
        'git',
        ['add', 'modules/message/sql/message-20260529-01.sql'],
        workingDirectory: tempRoot.path,
      );
      expect(addInitial.exitCode, 0, reason: addInitial.stderr.toString());

      final commit = await Process.run(
        'git',
        [
          '-c',
          'user.email=test@example.invalid',
          '-c',
          'user.name=Test User',
          'commit',
          '-m',
          'seed migration',
        ],
        workingDirectory: tempRoot.path,
      );
      expect(commit.exitCode, 0, reason: commit.stderr.toString());

      await sqlFile.writeAsString('''
-- +migrate Up
SELECT 2;

-- +migrate Down
SELECT 2;
''');

      final addStaged = await Process.run(
        'git',
        ['add', 'modules/message/sql/message-20260529-01.sql'],
        workingDirectory: tempRoot.path,
      );
      expect(addStaged.exitCode, 0, reason: addStaged.stderr.toString());

      await sqlFile.writeAsString('''
-- +migrate Up
SELECT 3;

-- +migrate Down
SELECT 3;
''');

      final result = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptPath,
        '-BackendRoot',
        tempRoot.path,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final output = result.stdout.toString();
      expect(output, contains('phase6_sql_migration_lint=pass'));
      expect(output, contains('phase6_sql_migration_lint_files=1'));
      expect(
        RegExp(
          r'^modules/message/sql/message-20260529-01\.sql$',
          multiLine: true,
        ).allMatches(output),
        hasLength(1),
      );
    },
    skip: !Platform.isWindows,
  );

  test(
    'phase6 SQL migration lint rejects create table if not exists as index guard',
    () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'phase6_sql_migration_lint_table_guard_',
      );
      addTearDown(() async {
        if (tempRoot.existsSync()) {
          await tempRoot.delete(recursive: true);
        }
      });

      final sqlDir = Directory(
        '${tempRoot.path}${Platform.pathSeparator}modules'
        '${Platform.pathSeparator}message${Platform.pathSeparator}sql',
      );
      await sqlDir.create(recursive: true);
      final sqlFile = File(
        '${sqlDir.path}${Platform.pathSeparator}message-20260529-01.sql',
      );
      await sqlFile.writeAsString('''
-- +migrate Up
CREATE TABLE IF NOT EXISTS `message_index_marker` (
  `id` BIGINT NOT NULL PRIMARY KEY
);
CREATE INDEX `message_uid_idx` ON `message` (`uid`);

-- +migrate Down
DROP INDEX `message_uid_idx` ON `message`;
DROP TABLE `message_index_marker`;
''');

      final result = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptPath,
        '-BackendRoot',
        tempRoot.path,
        '-All',
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, isNot(0));
      final output = '${result.stdout}\n${result.stderr}';
      expect(output, contains('CREATE INDEX requires'));
      expect(output, contains('phase6_sql_migration_lint=fail'));
    },
    skip: !Platform.isWindows,
  );

  test(
    'phase6 SQL migration lint accepts CRLF migrate markers',
    () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'phase6_sql_migration_lint_crlf_',
      );
      addTearDown(() async {
        if (tempRoot.existsSync()) {
          await tempRoot.delete(recursive: true);
        }
      });

      final sqlDir = Directory(
        '${tempRoot.path}${Platform.pathSeparator}modules'
        '${Platform.pathSeparator}message${Platform.pathSeparator}sql',
      );
      await sqlDir.create(recursive: true);
      final sqlFile = File(
        '${sqlDir.path}${Platform.pathSeparator}message-20260529-01.sql',
      );
      await sqlFile.writeAsString(
        [
          '-- +migrate Up',
          'SELECT 1;',
          '',
          '-- +migrate Down',
          'SELECT 1;',
          '',
        ].join('\r\n'),
      );

      final result = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptPath,
        '-BackendRoot',
        tempRoot.path,
        '-All',
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(
        result.stdout.toString(),
        contains('phase6_sql_migration_lint=pass'),
      );
    },
    skip: !Platform.isWindows,
  );

  test(
    'phase6 SQL migration lint accepts annotated idempotent index migrations',
    () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'phase6_sql_migration_lint_good_',
      );
      addTearDown(() async {
        if (tempRoot.existsSync()) {
          await tempRoot.delete(recursive: true);
        }
      });

      final sqlDir = Directory(
        '${tempRoot.path}${Platform.pathSeparator}modules'
        '${Platform.pathSeparator}message${Platform.pathSeparator}sql',
      );
      await sqlDir.create(recursive: true);
      final sqlFile = File(
        '${sqlDir.path}${Platform.pathSeparator}message-20260529-01.sql',
      );
      await sqlFile.writeAsString('''
-- +migrate Up
SET @index_exists = (
  SELECT COUNT(1)
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'message'
    AND INDEX_NAME = 'message_uid_idx'
);
SET @ddl = IF(
  @index_exists = 0,
  'CREATE INDEX `message_uid_idx` ON `message` (`uid`)',
  'SELECT 1'
);
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- +migrate Down
DROP INDEX `message_uid_idx` ON `message`;
''');

      final result = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptPath,
        '-BackendRoot',
        tempRoot.path,
        '-All',
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(
        result.stdout.toString(),
        contains('phase6_sql_migration_lint=pass'),
      );
    },
    skip: !Platform.isWindows,
  );
}
