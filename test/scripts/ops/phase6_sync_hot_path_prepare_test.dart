import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<void> _copyDirectory(Directory source, Directory target) async {
  await target.create(recursive: true);
  await for (final entity in source.list(recursive: true, followLinks: false)) {
    final relative = entity.path.substring(source.path.length + 1);
    final targetPath = '${target.path}${Platform.pathSeparator}$relative';
    if (entity is Directory) {
      await Directory(targetPath).create(recursive: true);
    } else if (entity is File) {
      await Directory(File(targetPath).parent.path).create(recursive: true);
      await entity.copy(targetPath);
    }
  }
}

Future<void> _runGit(Directory root, List<String> args) async {
  final result = await Process.run('git', args, workingDirectory: root.path);
  expect(result.exitCode, 0, reason: result.stderr.toString());
}

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
    'd5bf39715ff86fad94f143171997f8480558dbcf093a43d33fd9b00f08342812  modules/message/api_conversation.go',
    '369857fd6233e875364b6909622c33585696d0e40455663d33d5b272a50ddf23  modules/message/db_conversation_extra.go',
    '90072a98eb13b35897ee2c6a6135fbd06f42cc2e9316e128699fec506dc3c957  modules/message/phase6_message_sync_test.go',
    'c0ece1c7727f2ebd0ac75cf986c84c3cfaad559c0e873c82c3a79301a3f2b9dc  modules/message/phase6_conversation_extra_test.go',
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

  test('phase6 prepare script builds from reviewed local manifest', () {
    final script = File('scripts/ops/phase6_sync_hot_path_prepare.ps1');
    final content = script.readAsStringSync();

    expect(content, contains('New-BuildContextManifest'));
    expect(content, contains('Assert-ReviewedBuildContextManifest'));
    expect(content, contains('phase6-sync-hot-path-build-context.manifest'));
    expect(content, contains('phase6_sync_hot_path_build_context_manifest=verified'));
    expect(content, contains('build-context-reviewed.tar.gz'));
    expect(content, contains('.build-context.manifest'));
    expect(content, contains(r'tar -xzf "`$remote_tmp/build-context-reviewed.tar.gz"'));
    expect(content, contains(r'build_context_manifest_text=$buildContextManifestArg'));
    expect(content, contains('phase6_sync_hot_path_build_context_unreviewed_remote_file'));
    expect(content, contains('context: __BUILD_CONTEXT_ROOT__'));
    expect(
      content,
      isNot(contains('find go.mod go.sum main.go assets configs internal modules pkg serverlib -type f -print')),
    );
  });

  test('phase6 prepare rejects unreviewed local build context files', () async {
    final temp = await Directory.systemTemp.createTemp('phase6-build-context-');
    try {
      final backendRoot = Directory(
        '${temp.path}${Platform.pathSeparator}backend',
      );
      await _copyDirectory(Directory('.codex-backend-work/src'), backendRoot);
      await _runGit(backendRoot, ['init']);
      await _runGit(backendRoot, ['config', 'user.email', 'codex@example.invalid']);
      await _runGit(backendRoot, ['config', 'user.name', 'Codex']);
      await _runGit(backendRoot, ['add', '.']);
      await _runGit(backendRoot, ['commit', '-m', 'baseline']);

      final extra = File(
        '${backendRoot.path}${Platform.pathSeparator}modules'
        '${Platform.pathSeparator}message'
        '${Platform.pathSeparator}phase6_unreviewed_local.go',
      );
      await extra.writeAsString('package message\n');

      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          'scripts\\ops\\phase6_sync_hot_path_prepare.ps1',
          '-LocalBackendRoot',
          backendRoot.path,
        ],
        workingDirectory: Directory.current.path,
      );

      final output = '${result.stdout}\n${result.stderr}';
      expect(result.exitCode, isNot(0));
      expect(
        output,
        contains(
          'phase6_sync_hot_path_build_context_unreviewed_local_file=modules/message/phase6_unreviewed_local.go',
        ),
      );
      expect(
        output,
        contains('phase6_sync_hot_path_build_context=unreviewed_local_change'),
      );
    } finally {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    }
  }, skip: !Platform.isWindows);

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
