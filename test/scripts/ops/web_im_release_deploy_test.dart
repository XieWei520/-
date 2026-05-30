import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Web IM deploy script publishes live build to isolated /im canary path',
    () {
      final script = File('scripts/ops/deploy_web_im_release.ps1');

      expect(script.existsSync(), isTrue);

      final content = script.readAsStringSync();
      expect(content, contains(r"[string]$WebImDir = 'web_im'"));
      expect(content, contains(r"[string]$RemoteRoot = '/opt/wukongim-prod/src/deploy/production'"));
      expect(content, contains(r"[string]$Server = 'ubuntu@42.194.218.158'"));
      expect(content, contains('build_web_im_release.ps1'));
      expect(content, contains(r"$env:VITE_WK_WEB_IM_MODE = 'live'"));
      expect(content, contains(r'$env:VITE_WK_API_BASE_URL = $ApiBaseUrl'));
      expect(content, contains(r"[string]$DeviceFlag = '1'"));
      expect(content, contains(r'$env:VITE_WK_DEVICE_FLAG = $DeviceFlag'));
      expect(content, contains('manifest.webmanifest'));
      expect(content, contains('sw.js'));
      expect(content, contains('offline.html'));
      expect(content, contains(r'RELEASE_DIR="${REMOTE_ROOT}/nginx/html/im"'));
      expect(content, isNot(contains(r'RELEASE_DIR="${REMOTE_ROOT}/nginx/html"')));
      expect(content, contains(r'backup/web-im-release-${TIMESTAMP}'));
      expect(content, contains(r'cp -a "${RELEASE_DIR}" "${BACKUP_DIR}/im"'));
      expect(content, contains('# BEGIN WEB_IM_GRAY_RELEASE'));
      expect(content, contains('location = /im'));
      expect(content, contains('location = /im/index.html'));
      expect(content, contains('location = /im/sw.js'));
      expect(content, contains('location = /im/manifest.webmanifest'));
      expect(content, contains('location ^~ /im/assets/'));
      expect(content, contains('location ^~ /im/'));
      expect(content, contains(r'try_files $uri $uri/ /im/index.html'));
      expect(content, contains('docker compose --env-file .env config -q'));
      expect(content, contains('--force-recreate nginx'));
      expect(content, contains('nginx -t'));
      expect(content, contains(r'curl -k -fsSI "https://${public_domain}/im/"'));
      expect(content, contains('ROLLBACK_HINT'));
      expect(content, contains('WEB_IM_CANARY_URL='));
    },
  );
}
