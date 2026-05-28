import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phase4 sync load reduction prepare script is gated and scoped', () {
    final script = File('scripts/ops/phase4_sync_load_reduction_prepare.ps1');
    expect(script.existsSync(), isTrue);
    final content = script.readAsStringSync();

    expect(content, contains('phase4-sync-load-reduction'));
    expect(content, contains(r'[switch]$Run'));
    expect(content, contains(r'[switch]$AllowProductionSync'));
    expect(content, contains(r'[switch]$BuildImage'));
    expect(content, contains(r'[switch]$AllowProductionBuild'));
    expect(content, contains(r'[switch]$RunTests'));
    expect(content, contains(r'[switch]$ApplyLocalPatch'));
    expect(content, contains('AllowProductionSync'));
    expect(content, contains('AllowProductionBuild'));
    expect(content, contains('modules/message/api.go'));
    expect(content, contains('modules/message/phase4_sync_load_test.go'));
    expect(content, contains('phase4_sync_load_reduction_sync_backup_dir='));
    expect(
      content,
      contains('phase4_sync_load_reduction_previous_image_tag='),
    );
    expect(
      content,
      contains('phase4_sync_load_reduction_build_context=verified'),
    );
    expect(
      content,
      contains(
        r'docker compose --env-file .env -f "`$remote_tmp/docker-compose.phase4-build.yaml" build tsdd-api',
      ),
    );
    expect(content, contains('function should_include_build_context_path()'));
    expect(content, contains('install -m 0644'));
    expect(content, isNot(contains('docker compose up')));
    expect(content, isNot(contains('docker compose down')));
    expect(content, isNot(contains('docker system prune')));
    expect(content, isNot(contains('docker compose restart')));
    expect(content, isNot(contains('systemctl restart')));
    expect(content, isNot(contains('test-token')));
    expect(content, isNot(contains('dummy-token')));
  });

  test('phase4 sync load reduction patch is backend scoped', () {
    final patch = File(
      'deploy/production/backend-optimization/patches/0002-phase4-sync-load-reduction.patch',
    );
    expect(patch.existsSync(), isTrue);
    final content = patch.readAsStringSync();

    expect(
      content,
      contains('diff --git a/modules/message/api.go b/modules/message/api.go'),
    );
    expect(
      content,
      contains(
        'diff --git a/modules/message/phase4_sync_load_test.go b/modules/message/phase4_sync_load_test.go',
      ),
    );
    expect(content, isNot(contains('TangSengDaoDaoManager-main/')));
    expect(content, isNot(contains('lib/modules/')));
    expect(content, isNot(contains('release_packages/')));
    expect(content, isNot(contains('deploy/production/monitoring/')));
    expect(content, isNot(contains('ops/monitoring/')));
    expect(content, isNot(contains('docker-compose')));
  });

  test('phase4 rollout docs include baseline gates and rollback', () {
    final doc = File('docs/production/phase4-sync-load-reduction-rollout.md');
    expect(doc.existsSync(), isTrue);
    final content = doc.readAsStringSync();

    for (final expected in [
      'phase4_sync_load_reduction_prepare.ps1 -RunTests',
      '-Run -AllowProductionSync -BuildImage -AllowProductionBuild',
      'phase6_backend_service_switch.ps1',
      '/v1/ping',
      'Authorization: Bearer <metrics-token>',
      'sum by (route, method) (increase(wukongim_http_requests_total[24h]))',
      'histogram_quantile(0.99',
      'sum by (status_class) (increase(wukongim_http_requests_total[30m]))',
      'phase4_sync_load_reduction_sync_backup_dir',
      'phase4_sync_load_reduction_previous_image_tag',
      '.phase4_absent_files',
      'modules/message/api.go|modules/message/phase4_sync_load_test.go',
      r'rm -f -- "$path"',
      'rollback',
    ]) {
      expect(content, contains(expected));
    }

    expect(
      content,
      isNot(
        contains(RegExp(r'Bearer\s+(?!<metrics-token>)[A-Za-z0-9._~+/=-]{8,}')),
      ),
      reason: 'runbook must not include a real bearer token',
    );
  });
}
