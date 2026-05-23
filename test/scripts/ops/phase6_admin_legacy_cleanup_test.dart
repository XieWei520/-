import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin legacy cleanup script is staged and gated', () {
    final script = File('scripts/ops/phase6_admin_legacy_cleanup.ps1');

    expect(script.existsSync(), isTrue);

    final content = script.readAsStringSync();
    expect(content, contains(r'[switch]$Run'));
    expect(content, contains(r'[switch]$AllowAdminCutover'));
    expect(content, contains(r'[switch]$AllowLegacyAdminCleanup'));
    expect(content, contains('Dry run only. Add -Run to inspect legacy admin cleanup plan.'));
    expect(content, contains('Add -Run -AllowAdminCutover to cut /admin/ over'));
    expect(content, contains('Legacy admin cleanup skipped. Add -AllowLegacyAdminCleanup'));
    expect(content, contains('/opt/wukongim-prod/src/deploy/production'));
    expect(content, contains('admin-custom/dist'));
    expect(content, contains('wukongim_prod-admin-nginx-1'));
    expect(content, contains('phase6-admin-cleanup'));
    expect(content, contains('nginx -t'));
    expect(content, contains('nginx -s reload'));
    expect(content, contains("sub_filter 'src=\"/static/' 'src=\"/admin/static/'"));
    expect(content, contains("sub_filter 'href=\"/logo.png\"' 'href=\"/admin/logo.png\""));
    expect(content, contains('location ^~ /admin/static/'));
    expect(content, contains('location ^~ /admin/admin/static/'));
    expect(
      content,
      contains(r'curl -fsS --max-time "`$probe_timeout" "`$release_base_url/admin/"'),
    );
    expect(content, contains('phase6_admin_legacy_cleanup=cutover_completed'));
    expect(content, contains('phase6_admin_legacy_cleanup=cleanup_completed'));

    expect(content, isNot(contains('docker compose down')));
    expect(content, isNot(contains('docker compose build')));
    expect(content, isNot(contains('DROP ')));
    expect(content, isNot(contains('DELETE FROM')));
    expect(content, isNot(contains('TRUNCATE ')));
    expect(content, isNot(contains(r'rm -rf "$remote_root"')));
  });

  test('admin legacy cleanup dry-run explains the two approval gates', () async {
    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        'scripts\\ops\\phase6_admin_legacy_cleanup.ps1',
      ],
      workingDirectory: Directory.current.path,
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final output = result.stdout.toString();
    expect(output, contains('Dry run only'));
    expect(output, contains('-AllowAdminCutover'));
    expect(output, contains('-AllowLegacyAdminCleanup'));
    expect(output, contains('admin-custom/dist'));
    expect(output, contains('wukongim_prod-admin-nginx-1'));
    expect(output, contains(r'curl -fsS --max-time "$probe_timeout" "$release_base_url/admin/"'));
  }, skip: !Platform.isWindows);
}
