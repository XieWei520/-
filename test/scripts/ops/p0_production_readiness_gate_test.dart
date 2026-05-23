import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('p0 production readiness gate is explicit, read-only, and evidence based', () {
    final script = File('scripts/ops/p0_production_readiness_gate.ps1');

    expect(script.existsSync(), isTrue);

    final content = script.readAsStringSync();
    expect(content, contains(r'[switch]$Run'));
    expect(content, contains('Dry run only. Add -Run to execute read-only P0 production readiness gate.'));
    expect(content, contains('Validate-RemoteHostToken'));
    expect(content, contains('BatchMode=yes'));
    expect(content, contains('StrictHostKeyChecking=accept-new'));
    expect(content, contains('Invoke-ReadOnlyGate'));
    expect(content, contains('local_git_status'));
    expect(content, contains('local_secret_scan'));
    expect(content, contains('remote_container_health'));
    expect(content, contains('remote_public_port_audit'));
    expect(content, contains('remote_nginx_syntax'));
    expect(content, contains('remote_smoke_ping'));
    expect(content, contains('remote_websocket_handshake'));
    expect(content, contains('remote_backup_artifact_audit'));
    expect(content, contains('remote_observability_inventory'));
    expect(content, contains('scripts/ops/secret_log_scan.py'));
    expect(content, contains('git diff --cached'));
    expect(content, contains('docker compose ps'));
    expect(content, contains('docker compose exec -T nginx nginx -t'));
    expect(content, contains('/v1/ping'));
    expect(content, contains('/ws'));
    expect(content, contains('ss -ltnup'));
    expect(content, contains('9090'));
    expect(content, contains('3000'));
    expect(content, contains('p0_readiness=pass'));
    expect(content, contains('failed-gates.txt'));
    expect(content, contains('Evidence:'));

    expect(content, isNot(contains('docker compose restart')));
    expect(content, isNot(contains('docker compose up')));
    expect(content, isNot(contains('docker compose down')));
    expect(content, isNot(contains('docker compose build')));
    expect(content, isNot(contains('systemctl restart')));
    expect(content, isNot(contains('rm -rf')));
    expect(content, isNot(contains('DROP ')));
    expect(content, isNot(contains('DELETE ')));
    expect(content, isNot(contains('UPDATE ')));
    expect(content, isNot(contains('INSERT ')));
    expect(content, isNot(contains('ALTER ')));
    expect(content, isNot(contains('CREATE ')));
    expect(content, isNot(contains('TRUNCATE ')));
  });

  test('p0 production readiness gate uses Windows PowerShell compatible ssh arguments', () {
    final script = File('scripts/ops/p0_production_readiness_gate.ps1');

    expect(script.existsSync(), isTrue);

    final content = script.readAsStringSync();
    expect(content, contains(r'$startInfo.Arguments ='));
    expect(content, isNot(contains(r'$startInfo.ArgumentList.Add')));
  });

  test('p0 production readiness gate fails on missing release prerequisites', () {
    final script = File('scripts/ops/p0_production_readiness_gate.ps1');

    expect(script.existsSync(), isTrue);

    final content = script.readAsStringSync();
    expect(content, contains('local_worktree_dirty=true'));
    expect(content, contains('git status --porcelain'));
    expect(content, contains('backup_artifacts_missing=true'));
    expect(content, contains('backup_path_missing='));
    expect(content, contains('observability_stack_missing=true'));
    expect(content, contains('prometheus'));
    expect(content, contains('grafana'));
  });

  test('p0 backup evidence script is explicit, scoped, and checksummed', () {
    final script = File('scripts/ops/p0_create_backup_evidence.ps1');

    expect(script.existsSync(), isTrue);

    final content = script.readAsStringSync();
    expect(content, contains(r'[switch]$Run'));
    expect(content, contains(r'[switch]$AllowProductionWrites'));
    expect(content, contains('Dry run only.'));
    expect(content, contains('Refusing to write production backups without -AllowProductionWrites'));
    expect(content, contains('/opt/wukongim-prod/backups'));
    expect(content, contains('/var/backups/wukongim-sysctl'));
    expect(content, contains('backup_manifest.txt'));
    expect(content, contains('sha256sum'));
    expect(content, contains('mysqldump'));
    expect(content, contains('redis-cli'));
    expect(content, contains('tar'));
    expect(content, contains('docker compose --env-file .env exec -T mysql'));
    expect(content, contains('docker compose --env-file .env exec -T redis'));
    expect(content, contains(r'"`$1"'));
    expect(content, contains(r'sh "`$MYSQL_DATABASE"'));
    expect(content, contains(r'sh -lc'));
    expect(content, contains(r'REDISCLI_AUTH="`$REDIS_PASSWORD"'));
    expect(content, isNot(contains('redis-cli -a')));
    expect(content, contains('Validate-RemoteHostToken'));
    expect(content, contains('Quote-Bash'));
    expect(content, contains('BatchMode=yes'));
    expect(content, contains('sudo -n install -d -m 700'));

    expect(content, isNot(contains('DROP ')));
    expect(content, isNot(contains('DELETE ')));
    expect(content, isNot(contains('UPDATE ')));
    expect(content, isNot(contains('INSERT ')));
    expect(content, isNot(contains('ALTER ')));
    expect(content, isNot(contains('CREATE DATABASE')));
    expect(content, isNot(contains('TRUNCATE ')));
  });

  test('p0 backup evidence dry run preserves remote shell parameters', () {
    final result = Process.runSync(
      'powershell',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        'scripts/ops/p0_create_backup_evidence.ps1',
      ],
    );

    expect(result.exitCode, 0);
    final output = '${result.stdout}\n${result.stderr}';
    expect(output, contains(r'"$1"'));
    expect(output, isNot(contains(r'-p"$MYSQL_ROOT_PASSWORD" ""')));
    expect(output, contains(r'REDISCLI_AUTH="$REDIS_PASSWORD"'));
    expect(output, isNot(contains('redis-cli -a')));
  });

  test('p0 backup evidence docker exec commands do not consume remote script stdin', () {
    final result = Process.runSync(
      'powershell',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        'scripts/ops/p0_create_backup_evidence.ps1',
      ],
    );

    expect(result.exitCode, 0);
    final output = '${result.stdout}\n${result.stderr}';
    expect('</dev/null'.allMatches(output), hasLength(2));
    expect(output, contains(r'sh "$MYSQL_DATABASE" \'));
    expect(output, contains(r'> "$target_dir/redis.rdb"'));
  });

  test('p0 observability stack config is private and preflighted', () {
    final compose = File('deploy/production/docker-compose.observability.yaml');
    final prometheus = File('deploy/production/monitoring/prometheus.yml');
    final script = File('scripts/ops/p0_observability_preflight.ps1');

    expect(compose.existsSync(), isTrue);
    expect(prometheus.existsSync(), isTrue);
    expect(script.existsSync(), isTrue);

    final composeContent = compose.readAsStringSync();
    expect(composeContent, contains('prometheus'));
    expect(composeContent, contains('grafana'));
    expect(composeContent, contains('node-exporter'));
    expect(composeContent, contains('cadvisor'));
    expect(composeContent, contains('127.0.0.1:9090:9090'));
    expect(composeContent, contains('127.0.0.1:3000:3000'));
    expect(composeContent, isNot(contains('0.0.0.0:9090')));
    expect(composeContent, isNot(contains('0.0.0.0:3000')));

    final prometheusContent = prometheus.readAsStringSync();
    expect(prometheusContent, contains('host.docker.internal:5001'));
    expect(prometheusContent, contains('cadvisor:8080'));
    expect(prometheusContent, contains('node-exporter:9100'));

    final scriptContent = script.readAsStringSync();
    expect(scriptContent, contains(r'[switch]$Run'));
    expect(scriptContent, contains('Dry run only.'));
    expect(scriptContent, contains('docker compose'));
    expect(scriptContent, contains('config'));
    expect(scriptContent, contains('local_docker_cli_missing=true'));
    expect(scriptContent, contains('local_compose_config_skipped=true'));
    expect(scriptContent, contains('StrictHostKeyChecking=accept-new'));
    expect(scriptContent, contains('Validate-RemoteHostToken'));
    expect(scriptContent, isNot(contains('docker compose up')));
    expect(scriptContent, isNot(contains('docker compose restart')));
    expect(scriptContent, isNot(contains('systemctl restart')));
  });
}
