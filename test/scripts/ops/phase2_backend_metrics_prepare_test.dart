import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phase2 backend metrics prepare script is gated and scoped', () {
    final script = File('scripts/ops/phase2_backend_metrics_prepare.ps1');

    expect(script.existsSync(), isTrue);

    final content = script.readAsStringSync();
    expect(content, contains(r'[switch]$Run'));
    expect(content, contains(r'[switch]$AllowProductionSync'));
    expect(content, contains(r'[switch]$BuildImage'));
    expect(content, contains(r'[switch]$AllowProductionBuild'));
    expect(content, contains(r'[switch]$RunTests'));
    expect(content, contains(r'[switch]$ApplyLocalPatch'));

    expect(content, contains('Dry run only'));
    expect(content, contains('Refusing to sync production backend source without -AllowProductionSync'));
    expect(content, contains('Refusing to build production backend image without -AllowProductionBuild'));
    expect(content, contains('/opt/wukongim-prod/src'));
    expect(content, contains('/opt/wukongim-prod/src/deploy/production'));
    expect(content, contains('backups/phase2-backend-metrics-source-sync'));
    expect(content, contains('phase2_backend_metrics_sync=applied'));
    expect(content, contains('phase2_backend_metrics_build=completed'));
    expect(content, contains('phase2_backend_metrics_build=skipped'));
    expect(content, contains('docker compose --env-file .env build tsdd-api'));

    const releaseFiles = [
      'main.go',
      'modules/message/api.go',
      'modules/file/api.go',
      'serverlib/pkg/metrics/metrics.go',
      'serverlib/pkg/metrics/metrics_test.go',
    ];
    for (final file in releaseFiles) {
      expect(content, contains("'$file'"));
    }

    const outOfScopeFiles = [
      'go.mod',
      'go.sum',
      'serverlib/go.mod',
      'serverlib/go.sum',
      'modules/common/api.go',
      'modules/user/api_manager.go',
      'modules/file/service.go',
      'modules/message/api_manager.go',
      'deploy/production/monitoring/prometheus.yml',
      'ops/monitoring/prometheus/prometheus.yml',
    ];
    for (final file in outOfScopeFiles) {
      expect(content, isNot(contains("'$file'")));
    }

    expect(content, contains(r"Push-Location -LiteralPath (Join-Path $backendRoot 'serverlib')"));
    expect(content, contains('go test -count=1 ./pkg/metrics'));
    expect(content, contains('Running backend module compile gate:'));
    expect(content, contains(r"go test -count=1 -mod=readonly -run '^$' ./modules/message ./modules/file"));

    expect(content, isNot(contains('docker compose up')));
    expect(content, isNot(contains('docker compose down')));
    expect(content, isNot(contains('docker compose restart')));
    expect(content, isNot(contains('systemctl restart')));
  });

  test('phase2 backend metrics prepare dry-run lists manifest without production writes', () async {
    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        'scripts\\ops\\phase2_backend_metrics_prepare.ps1',
      ],
      workingDirectory: Directory.current.path,
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final output = result.stdout.toString();
    expect(output, contains('Dry run only'));
    expect(output, contains('Files to sync:'));
    expect(output, contains('Manifest:'));
    expect(output, contains('main.go'));
    expect(output, contains('modules/message/api.go'));
    expect(output, contains('modules/file/api.go'));
    expect(output, contains('serverlib/pkg/metrics/metrics.go'));
    expect(output, contains('serverlib/pkg/metrics/metrics_test.go'));
    expect(output, isNot(contains('serverlib/go.mod')));
    expect(output, isNot(contains('serverlib/go.sum')));
    expect(output, isNot(contains('phase2_backend_metrics_sync=applied')));
  }, skip: !Platform.isWindows);

  test('phase2 backend metrics prepare rejects unsafe production flags', () async {
    Future<ProcessResult> run(List<String> arguments) {
      return Process.run(
        'powershell',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          'scripts\\ops\\phase2_backend_metrics_prepare.ps1',
          ...arguments,
        ],
        workingDirectory: Directory.current.path,
      );
    }

    final missingSyncApproval = await run(['-Run']);
    expect(missingSyncApproval.exitCode, isNot(0));
    expect(
      '${missingSyncApproval.stdout}\n${missingSyncApproval.stderr}',
      contains('Refusing to sync production backend source without -AllowProductionSync'),
    );

    final missingBuildApproval = await run([
      '-Run',
      '-AllowProductionSync',
      '-BuildImage',
    ]);
    expect(missingBuildApproval.exitCode, isNot(0));
    expect(
      '${missingBuildApproval.stdout}\n${missingBuildApproval.stderr}',
      contains('Refusing to build production backend image without -AllowProductionBuild'),
    );

    final unsafeHost = await run(['-RemoteHost', '-oProxyCommand=bad']);
    expect(unsafeHost.exitCode, isNot(0));
    expect(
      '${unsafeHost.stdout}\n${unsafeHost.stderr}',
      contains('RemoteHost must be a single safe ssh host token'),
    );

    final unsafePath = await run(['-RemoteSourceRoot', '/opt/../src']);
    expect(unsafePath.exitCode, isNot(0));
    expect(
      '${unsafePath.stdout}\n${unsafePath.stderr}',
      contains('RemoteSourceRoot must be a safe absolute remote path'),
    );
  }, skip: !Platform.isWindows);
}
