import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phase3 backend optimization prepare script is gated and scoped', () {
    final script = File('scripts/ops/phase3_backend_optimization_prepare.ps1');

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
    expect(content, contains('backups/phase3-backend-optimization-source-sync'));
    expect(content, contains('phase3_backend_optimization_sync=applied'));
    expect(content, contains('phase3_backend_optimization_build=completed'));
    expect(content, contains('phase3_backend_optimization_build=skipped'));
    expect(content, contains('docker compose --env-file .env build tsdd-api'));

    const releaseFiles = [
      'modules/user/api.go',
      'modules/user/api_im_route_test.go',
      'modules/message/api_conversation.go',
      'modules/message/api_conversation_syncack_test.go',
      'modules/file/service_minio.go',
      'modules/file/service_minio_test.go',
      'serverlib/pkg/metrics/metrics.go',
      'serverlib/pkg/metrics/metrics_test.go',
    ];
    for (final file in releaseFiles) {
      expect(content, contains("'$file'"));
    }

    const outOfScopeFiles = [
      'main.go',
      'go.mod',
      'go.sum',
      'serverlib/go.mod',
      'serverlib/go.sum',
      'modules/message/api.go',
      'modules/file/api.go',
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
    expect(content, contains('go test -count=1 ./pkg/metrics -run TestStorageOperationMetricsDoNotLeakObjectPaths'));
    expect(content, contains('Running backend module tests:'));
    expect(content, contains(r"go test -count=1 ./modules/user ./modules/message ./modules/file"));

    expect(content, isNot(contains('docker compose up')));
    expect(content, isNot(contains('docker compose down')));
    expect(content, isNot(contains('docker compose restart')));
    expect(content, isNot(contains('systemctl restart')));
    expect(content, isNot(contains('test-token')));
    expect(content, isNot(contains('dummy-token')));
  });

  test('phase3 backend optimization patch exists and stays backend-scoped', () {
    final patch = File(
      'deploy/production/backend-optimization/patches/0001-phase3-backend-low-risk-optimization.patch',
    );
    expect(patch.existsSync(), isTrue);

    final content = patch.readAsStringSync();
    for (final expected in [
      'diff --git a/modules/user/api.go b/modules/user/api.go',
      'diff --git a/modules/user/api_im_route_test.go b/modules/user/api_im_route_test.go',
      'diff --git a/modules/message/api_conversation.go b/modules/message/api_conversation.go',
      'diff --git a/modules/message/api_conversation_syncack_test.go b/modules/message/api_conversation_syncack_test.go',
      'diff --git a/modules/file/service_minio.go b/modules/file/service_minio.go',
      'diff --git a/modules/file/service_minio_test.go b/modules/file/service_minio_test.go',
      'diff --git a/serverlib/pkg/metrics/metrics.go b/serverlib/pkg/metrics/metrics.go',
      'diff --git a/serverlib/pkg/metrics/metrics_test.go b/serverlib/pkg/metrics/metrics_test.go',
    ]) {
      expect(content, contains(expected));
    }

    for (final unexpected in [
      'TangSengDaoDaoManager-main/',
      'lib/modules/',
      'release_packages/',
      'deploy/production/monitoring/',
      'ops/monitoring/',
      'docker-compose',
    ]) {
      expect(content, isNot(contains(unexpected)));
    }
  });

  test('phase3 backend optimization rollout runbook covers gates and rollback', () {
    final doc = File('docs/production/phase3-backend-optimization-rollout.md');
    expect(doc.existsSync(), isTrue);

    final content = doc.readAsStringSync();
    for (final expected in [
      'phase3_backend_optimization_prepare.ps1 -RunTests',
      '-Run -AllowProductionSync',
      '-BuildImage -AllowProductionBuild',
      'phase6_backend_service_switch.ps1',
      '-Run',
      '-AllowProductionServiceSwitch',
      '/v1/ping',
      'Authorization: Bearer <metrics-token>',
      'phase3_backend_optimization_sync_backup_dir',
      'up{job="wukongim_api"}',
      'sum by (status_class) (increase(wukongim_http_requests_total[30m]))',
      'histogram_quantile(0.95',
      'histogram_quantile(0.99',
      'sum by (operation, result) (increase(wukongim_operation_total[30m]))',
      'sum by (provider, operation, result) (increase(wukongim_storage_operation_total[30m]))',
      'sum(increase(wukongim_http_requests_total{route="unknown"}[30m]))',
      'rsync -a',
    ]) {
      expect(content, contains(expected));
    }

    expect(
      content,
      isNot(contains(RegExp(r'Bearer\s+(?!<metrics-token>)[A-Za-z0-9._~+/=-]{8,}'))),
      reason: 'runbook must not include a real bearer token',
    );
  });

  test('phase3 backend optimization prepare dry-run lists manifest without production writes', () async {
    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        'scripts\\ops\\phase3_backend_optimization_prepare.ps1',
      ],
      workingDirectory: Directory.current.path,
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final output = result.stdout.toString();
    expect(output, contains('Dry run only'));
    expect(output, contains('Files to sync:'));
    expect(output, contains('Manifest:'));
    expect(output, contains('phase3_backend_optimization_sync_backup_dir'));
    expect(output, contains('modules/user/api.go'));
    expect(output, contains('modules/message/api_conversation.go'));
    expect(output, contains('modules/file/service_minio.go'));
    expect(output, contains('serverlib/pkg/metrics/metrics.go'));
    expect(output, isNot(contains('serverlib/go.mod')));
    expect(output, isNot(contains('serverlib/go.sum')));
    expect(output, isNot(contains('phase3_backend_optimization_sync=applied')));
    expect(output, isNot(contains('test-token')));
    expect(output, isNot(contains('dummy-token')));
  }, skip: !Platform.isWindows);

  test('phase3 backend optimization prepare rejects unsafe production flags', () async {
    Future<ProcessResult> run(List<String> arguments) {
      return Process.run(
        'powershell',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          'scripts\\ops\\phase3_backend_optimization_prepare.ps1',
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
