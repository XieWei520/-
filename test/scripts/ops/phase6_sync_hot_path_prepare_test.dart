import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const releaseFiles = <String>[
    'modules/message/api.go',
    'modules/message/api_conversation.go',
    'modules/message/db_conversation_extra.go',
    'modules/message/phase6_message_sync_test.go',
    'modules/message/phase6_conversation_extra_test.go',
    'modules/message/phase6_conversation_sync_test.go',
  ];

  const manifestRows = <String>[
    'd0a5f3bd0a100ce91b46c3c0b7cf9b0a903550721068d59b83e9439061bfbb40  modules/message/api.go',
    '72051603ee604716fdf85bc72ad09f099d4388014ff8250a850c91bd0a093c9d  modules/message/api_conversation.go',
    'e486e958798a5595f8b54e6bed8030e738c424fea084ec3b637fffd17aaf4cec  modules/message/db_conversation_extra.go',
    '90072a98eb13b35897ee2c6a6135fbd06f42cc2e9316e128699fec506dc3c957  modules/message/phase6_message_sync_test.go',
    '9da21ae6e3477c7695274120b69a7142c4219120a6e8ef049d7a6fdbf5c1e8bd  modules/message/phase6_conversation_extra_test.go',
    '5c41e9eaf45fe632fef150bcbf7d278c5349a79e75718388c5b8495132ad5f8a  modules/message/phase6_conversation_sync_test.go',
  ];

  test('phase6 sync hot path prepare script is guarded', () {
    final script = File('scripts/ops/phase6_sync_hot_path_prepare.ps1');
    expect(script.existsSync(), isTrue);
    final content = script.readAsStringSync();

    expect(content, contains('phase6_sync_hot_path'));
    expect(
      content,
      contains('0004-phase6-sync-hot-path-optimization.patch'),
    );
    expect(content, contains('AllowProductionSync'));
    expect(content, contains('AllowProductionBuild'));
    expect(content, contains('BuildImage'));
    expect(content, contains('phase6_sync_hot_path_previous_image_tag'));
    expect(content, contains('phase6_sql_migration_lint.ps1'));
    expect(content, contains('phase6_prometheus_gate_report.ps1'));

    for (final releaseFile in releaseFiles) {
      expect(content, contains("'$releaseFile'"));
    }
    for (final row in manifestRows) {
      expect(content, contains("'$row'"));
    }
  });

  test('phase6 patch contains only reviewed backend hot path files', () {
    final patch = File(
      'deploy/production/backend-optimization/patches/0004-phase6-sync-hot-path-optimization.patch',
    );
    expect(patch.existsSync(), isTrue);
    final content = patch.readAsStringSync();

    final expectedHeaders =
        releaseFiles
            .map((path) => 'diff --git a/$path b/$path')
            .toSet();
    final actualHeaders =
        RegExp(
          r'^diff --git a/(.+?) b/(.+?)$',
          multiLine: true,
        ).allMatches(content).map((match) => match.group(0)!).toSet();

    expect(actualHeaders, expectedHeaders);
    expect(content, isNot(contains('lib/')));
    expect(content, isNot(contains('android/')));
    expect(content, isNot(contains('web/')));
    expect(content, isNot(contains('.codex-backend-work')));
  });

  test('phase6 sync hot path prepare dry-run verifies manifest', () async {
    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        'scripts\\ops\\phase6_sync_hot_path_prepare.ps1',
      ],
      workingDirectory: Directory.current.path,
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final output = result.stdout.toString();
    expect(output, contains('Dry run only'));
    expect(output, contains('phase6_sync_hot_path'));
    expect(output, contains('Reviewed manifest: verified'));
    expect(output, contains('phase6_sync_hot_path_reviewed_manifest=verified'));
  }, skip: !Platform.isWindows);
}
