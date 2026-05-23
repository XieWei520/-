import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'flutter web deploy script publishes build web through nginx html mount',
    () {
      final script = File('scripts/ops/deploy_flutter_web_release.ps1');

      expect(script.existsSync(), isTrue);

      final content = script.readAsStringSync();
      expect(content, contains(r'[string]$BuildWebDir = '));
      expect(content, contains('build\\web'));
      expect(content, contains('prune_flutter_web_release.ps1'));
      expect(content, contains('[STEP] Pruning Flutter Web release artifacts'));
      expect(content, contains('-NoProfile'));
      expect(content, contains('-ExecutionPolicy Bypass'));
      expect(content, contains(r'-BuildWebDir $resolvedBuildDir'));
      expect(content, contains('flutter_bootstrap.js'));
      expect(content, contains('wk_pwa_service_worker.js'));
      expect(content, contains('offline.html'));
      expect(content, contains('tar -C'));
      expect(content, contains('scp'));
      expect(content, contains('function Invoke-WithRetry'));
      expect(content, contains(r'[int]$MaxAttempts = 3'));
      expect(content, contains(r'Start-Sleep -Seconds $DelaySeconds'));
      expect(content, contains(r'UTF8Encoding]::new($false)'));
      expect(content, contains('./nginx/html:/usr/share/nginx/html:ro'));
      expect(content, contains('docker compose --env-file .env config -q'));
      expect(content, contains('--force-recreate nginx'));
      expect(content, contains('nginx -t'));
      expect(content, contains(r'rm -f "${ARCHIVE}" "$0"'));
      expect(content, isNot(contains('chmod +x')));
      expect(content, contains('ROLLBACK_HINT'));
    },
  );
}
