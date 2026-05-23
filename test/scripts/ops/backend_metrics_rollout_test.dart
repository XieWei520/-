import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monitoring configs scrape protected backend metrics endpoint', () {
    final expectedTargets = {
      'ops/monitoring/prometheus/prometheus.yml': 'host.docker.internal:8080',
      'deploy/production/monitoring/prometheus.yml': 'tsdd-api:8090',
    };

    for (final entry in expectedTargets.entries) {
      final path = entry.key;
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: path);

      final content = file.readAsStringSync();
      final block = _jobBlock(content, 'wukongim_api');
      expect(block, contains('metrics_path: /metrics'), reason: path);
      expect(block, contains(entry.value), reason: path);
      expect(block, isNot(contains(RegExp(r'bearer_token\s*:'))), reason: path);
      expect(block, isNot(contains(RegExp(r'credentials\s*:'))), reason: path);
      expect(block, isNot(contains('expected-token')), reason: path);
      expect(block, isNot(contains('<metrics-token>')), reason: path);

      expect(block, contains('authorization:'), reason: path);
      expect(block, contains('credentials_file: /run/secrets/wukongim_metrics_token'), reason: path);
    }
  });

  test('compose files wire metrics token without committing a secret', () {
    for (final path in [
      'ops/monitoring/docker-compose.yml',
      'deploy/production/docker-compose.observability.yaml',
    ]) {
      final compose = File(path);
      expect(compose.existsSync(), isTrue, reason: path);

      final content = compose.readAsStringSync();
      expect(
        content,
        contains('./secrets/wukongim_metrics_token:/run/secrets/wukongim_metrics_token:ro'),
        reason: path,
      );
      expect(content, isNot(contains('<metrics-token>')), reason: path);
    }

    final productionCompose = File('deploy/production/docker-compose.yaml');
    expect(productionCompose.existsSync(), isTrue);
    final productionContent = productionCompose.readAsStringSync();
    expect(
      productionContent,
      contains('WUKONGIM_METRICS_TOKEN: "\${WUKONGIM_METRICS_TOKEN}"'),
    );

    final envExample = File('deploy/production/.env.example').readAsStringSync();
    expect(envExample, contains('WUKONGIM_METRICS_TOKEN=CHANGE_ME_METRICS_TOKEN'));
    expect(envExample, isNot(contains(RegExp(r'WUKONGIM_METRICS_TOKEN=(?!CHANGE_ME_METRICS_TOKEN)\S+'))));

    final gitignore = File('.gitignore').readAsStringSync();
    expect(gitignore, contains('/ops/monitoring/secrets/'));
    expect(gitignore, contains('/deploy/production/secrets/'));
  });

  test('backend metrics rollout runbook covers validation and rollback', () {
    final doc = File('docs/production/backend-metrics-rollout.md');
    expect(doc.existsSync(), isTrue);

    final content = doc.readAsStringSync();
    for (final expected in [
      'phase2_backend_metrics_prepare.ps1 -RunTests',
      '-Run -AllowProductionSync',
      '-BuildImage -AllowProductionBuild',
      'phase6_backend_service_switch.ps1',
      '-Run',
      '-AllowProductionServiceSwitch',
      '/v1/ping',
      'docker exec wukongim_prod-tsdd-api-1 wget --header="Authorization: Bearer <metrics-token>" -q -O - http://127.0.0.1:8090/metrics',
      'Authorization: Bearer <metrics-token>',
      'Prometheus',
      'target is up',
      'tsdd-api:8090',
      'credentials_file: /run/secrets/wukongim_metrics_token',
      './secrets/wukongim_metrics_token',
      'WUKONGIM_METRICS_TOKEN',
      'phase2_backend_metrics_sync_backup_dir',
      'histogram_quantile(0.95',
      'wukongim_http_requests_total',
      'wukongim_http_request_duration_seconds_bucket',
      'wukongim_operation_duration_seconds_bucket',
      'wukongim_operation_total{operation="file_upload",result="failure"}',
    ]) {
      expect(content, contains(expected));
    }

    expect(
      content,
      contains('requires\n`Authorization: Bearer <token>` for every caller, including loopback'),
    );
    expect(
      content,
      contains('token is intentionally unset, only loopback requests are accepted'),
    );
    expect(
      content,
      contains('wukongim_http_requests_total{status_class="5xx"}'),
    );

    expect(
      content,
      isNot(contains(RegExp('WUKONGIM_METRICS_TOKEN\\s*=\\s*[^\\s<]'))),
      reason: 'runbook must document token handling without committing a secret',
    );
    expect(
      content,
      isNot(contains(RegExp(r'wukongim_metrics_token\s*:\s*[A-Za-z0-9]'))),
      reason: 'runbook must not include an inline metrics token',
    );
  });
}

String _jobBlock(String source, String jobName) {
  final start = source.indexOf('- job_name: $jobName');
  expect(start, isNonNegative, reason: 'missing Prometheus job $jobName');
  final nextJob = source.indexOf('\n  - job_name:', start + 1);
  if (nextJob == -1) {
    return source.substring(start);
  }
  return source.substring(start, nextJob);
}
