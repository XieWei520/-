import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phase6 backend release prepare script is sync and build gated', () {
    final script = File('scripts/ops/phase6_backend_release_prepare.ps1');

    expect(script.existsSync(), isTrue);

    final content = script.readAsStringSync();
    expect(content, contains(r'[switch]$Run'));
    expect(content, contains(r'[switch]$AllowProductionSync'));
    expect(content, contains(r'[switch]$BuildImage'));
    expect(content, contains(r'[switch]$AllowProductionBuild'));
    expect(content, contains('Dry run only. Add -Run -AllowProductionSync'));
    expect(content, contains('Refusing to sync production backend source without -AllowProductionSync'));
    expect(content, contains('Refusing to build production backend image without -AllowProductionBuild'));
    expect(content, contains('/opt/wukongim-prod/src'));
    expect(content, contains('/opt/wukongim-prod/src/deploy/production'));
    expect(content, contains('phase6_backend_sync=applied'));
    expect(content, contains('phase6_backend_build=completed'));
    expect(content, contains('phase6_backend_build=skipped'));
    expect(content, contains('backups/phase6-source-sync'));
    expect(content, contains('docker compose --env-file .env build tsdd-api callgateway'));

    expect(content, contains('modules/common/db_admin_audit.go'));
    expect(content, contains('modules/common/sql/common-20260520-01.sql'));
    expect(content, contains('modules/file/service.go'));
    expect(content, contains('modules/file/service_minio.go'));
    expect(content, contains('modules/user/db_user_purge.go'));
    expect(content, contains('modules/user/user_purge.go'));
    expect(content, contains('modules/user/sql/user-20260520-01.sql'));

    expect(content, isNot(contains('docker compose restart')));
    expect(content, isNot(contains('docker compose up')));
    expect(content, isNot(contains('docker compose down')));
    expect(content, isNot(contains(r'rm -rf "$remote_source"')));
    expect(content, isNot(contains('DROP ')));
    expect(content, isNot(contains('DELETE FROM')));
    expect(content, isNot(contains('TRUNCATE ')));
  });

  test('phase6 backend release prepare dry-run lists expected files', () async {
    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        'scripts\\ops\\phase6_backend_release_prepare.ps1',
      ],
      workingDirectory: Directory.current.path,
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final output = result.stdout.toString();
    expect(output, contains('Dry run only'));
    expect(output, contains('modules/common/api_manager.go'));
    expect(output, contains('modules/common/db_admin_audit.go'));
    expect(output, contains('modules/common/sql/common-20260520-01.sql'));
    expect(output, contains('modules/file/service.go'));
    expect(output, contains('modules/file/service_minio.go'));
    expect(output, contains('modules/user/api_manager.go'));
    expect(output, contains('modules/user/db_user_purge.go'));
    expect(output, contains('modules/user/user_purge.go'));
    expect(output, contains('modules/user/sql/user-20260520-01.sql'));
    expect(output, contains('Manifest:'));
  }, skip: !Platform.isWindows);
}
