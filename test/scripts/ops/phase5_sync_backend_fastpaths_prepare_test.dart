import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final script = File('scripts/ops/phase5_sync_backend_fastpaths_prepare.ps1');

  test('phase5 prepare script exists and names rollout artifacts', () {
    expect(script.existsSync(), isTrue);
    final content = script.readAsStringSync();

    expect(content, contains('phase5_sync_backend_fastpaths'));
    expect(
      content,
      contains(
        'deploy/production/backend-optimization/patches/0003-phase5-sync-backend-fastpaths.patch',
      ),
    );
    expect(content, contains('modules/message/api.go'));
    expect(content, contains('modules/message/db.go'));
    expect(content, contains('modules/message/phase4_sync_load_test.go'));
    expect(content, contains('modules/message/sql/message-20260529-01.sql'));
  });

  test('phase5 prepare script requires explicit production flags', () {
    final content = script.readAsStringSync();

    expect(content, contains('AllowProductionSync'));
    expect(content, contains('AllowProductionBuild'));
    expect(content, contains('BuildImage'));
    expect(
      content,
      contains('phase5_sync_backend_fastpaths_previous_image_tag'),
    );
  });

  test('phase5 patch contains only reviewed backend files', () {
    final patch = File(
      'deploy/production/backend-optimization/patches/0003-phase5-sync-backend-fastpaths.patch',
    );
    expect(patch.existsSync(), isTrue);
    final content = patch.readAsStringSync();
    final diffHeaders = RegExp(
      r'^diff --git a/.* b/.*$',
      multiLine: true,
    ).allMatches(content).map((match) => match.group(0)).toList();

    expect(diffHeaders, [
      'diff --git a/modules/message/api.go b/modules/message/api.go',
      'diff --git a/modules/message/db.go b/modules/message/db.go',
      'diff --git a/modules/message/phase4_sync_load_test.go b/modules/message/phase4_sync_load_test.go',
      'diff --git a/modules/message/sql/message-20260529-01.sql b/modules/message/sql/message-20260529-01.sql',
    ]);
    expect(content, isNot(contains('lib/service/im')));
  });

  test('phase5 migration is sql-migrate annotated and idempotent', () {
    final migration = File(
      '.codex-backend-work/src/modules/message/sql/message-20260529-01.sql',
    );
    expect(migration.existsSync(), isTrue);
    final content = migration.readAsStringSync();

    expect(content, contains('-- +migrate Up'));
    expect(content, contains('-- +migrate Down'));
    expect(content, contains('information_schema.STATISTICS'));
    expect(content, contains('idx_prohibit_words_version'));

    final patch = File(
      'deploy/production/backend-optimization/patches/0003-phase5-sync-backend-fastpaths.patch',
    );
    final patchContent = patch.readAsStringSync();
    expect(patchContent, contains('+-- +migrate Up'));
    expect(patchContent, contains('+-- +migrate Down'));
    expect(patchContent, contains('information_schema.STATISTICS'));
  });
}
