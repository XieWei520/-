import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phase6 backend service switch script is gated and refreshes nginx', () {
    final script = File('scripts/ops/phase6_backend_service_switch.ps1');

    expect(script.existsSync(), isTrue);

    final content = script.readAsStringSync();
    expect(content, contains(r'[switch]$Run'));
    expect(content, contains(r'[switch]$AllowProductionServiceSwitch'));
    expect(content, contains('Dry run only. Add -Run -AllowProductionServiceSwitch'));
    expect(content, contains('Refusing to switch production backend services without -AllowProductionServiceSwitch'));
    expect(content, contains('/opt/wukongim-prod/src/deploy/production'));
    expect(content, contains('docker compose --env-file .env up -d --no-deps --force-recreate tsdd-api callgateway'));
    expect(content, contains('wait_for_health tsdd-api'));
    expect(content, contains('wait_for_health callgateway'));
    expect(content, contains('internal_ping='));
    expect(content, contains(r'docker exec "$tsdd_container_id" wget'));
    expect(content, contains('external_ping='));
    expect(content, contains('nginx_recent_502_count='));
    expect(content, contains(r'docker exec "$nginx_container_id" nginx -t'));
    expect(content, contains('docker compose --env-file .env restart nginx'));
    expect(content, contains(r'post_nginx_restart_since="$(date -u +%Y-%m-%dT%H:%M:%SZ)"'));
    expect(
      content,
      contains(r'curl -fsS --max-time "$probe_timeout" "$release_base_url/v1/ping"'),
    );
    expect(
      content,
      contains(r'docker compose --env-file .env logs --since="$post_nginx_restart_since" nginx'),
    );
    expect(content, contains('phase6_backend_service_switch=blocked_internal_ping'));
    expect(content, contains('phase6_backend_service_switch=blocked_external_ping'));
    expect(content, contains('phase6_backend_service_switch=completed'));
    expect(content, contains('phase6-remote-bash-'));
    expect(content, contains(r'[System.Text.UTF8Encoding]::new($false)'));
    expect(content, contains(r'[System.IO.File]::WriteAllText($remoteScriptFile'));
    expect(
      content,
      contains(
        r"$startInfo.Arguments = '/d /c ' + (Quote-CmdArgument -Value $cmdFile) + ' 2>&1'",
      ),
    );
    expect(content, contains(r'$startInfo.RedirectStandardError = $false'));
    expect(content, isNot(contains(r'$process.StandardError.ReadToEnd()')));

    expect(content, isNot(contains('docker compose build')));
    expect(content, isNot(contains('docker compose down')));
    expect(content, isNot(contains('migrate up')));
    expect(content, isNot(contains('sql-migrate')));
    expect(content, isNot(contains('DROP ')));
    expect(content, isNot(contains('DELETE FROM')));
    expect(content, isNot(contains('TRUNCATE ')));
    expect(content, isNot(contains(r'rm -rf "$remote_root"')));
  });

  test('phase6 backend service switch dry-run lists the guarded rollout', () async {
    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        'scripts\\ops\\phase6_backend_service_switch.ps1',
      ],
      workingDirectory: Directory.current.path,
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final output = result.stdout.toString();
    expect(output, contains('Dry run only'));
    expect(output, contains('tsdd-api callgateway'));
    expect(output, contains('restart nginx'));
    expect(output, contains('https://infoequity.cn'));
    expect(output, contains('phase6_backend_service_switch=completed'));
  }, skip: !Platform.isWindows);
}
