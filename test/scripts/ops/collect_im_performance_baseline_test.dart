import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('baseline collector redaction', () {
    test('defines a centralized redaction helper and uses <redacted>', () {
      final content =
          File('scripts/ops/collect_im_performance_baseline.ps1')
              .readAsStringSync();

      expect(content, contains('function Redact-SensitiveText'));
      expect(content, contains('<redacted>'));
      final redactBlock = _functionBlock(content, 'Redact-SensitiveText');
      expect(redactBlock, contains('password'));
      expect(redactBlock, contains('token'));
      expect(redactBlock, contains('secret'));
      expect(redactBlock, contains('key'));
      expect(redactBlock, contains('pwd'));
      expect(redactBlock, contains('dsn'));
      expect(
        _functionBlock(content, 'Write-RedactedContent'),
        contains('Redact-SensitiveText'),
      );
    });

    test(
      'remote nginx config, nginx log, and api log capture paths pass through redaction',
      () {
        final content =
            File('scripts/ops/collect_im_performance_baseline.ps1')
                .readAsStringSync();

        expect(
          _functionBlock(content, 'Invoke-Capture'),
          contains('Write-RedactedContent'),
        );
        expect(
          _functionBlock(content, 'Write-DirectorySize'),
          contains('Write-RedactedContent'),
        );
        expect(
          content,
          contains('remote_nginx_config'),
          reason: 'expected nginx config capture to remain present',
        );
        expect(
          content,
          contains('remote_recent_nginx_log'),
          reason: 'expected nginx log capture to remain present',
        );
        expect(
          content,
          contains('remote_recent_api_log'),
          reason: 'expected api log capture to remain present',
        );
        expect(
          _invokeCaptureBlock(content, 'remote_nginx_config'),
          contains('ssh'),
        );
        expect(
          _invokeCaptureBlock(content, 'remote_recent_nginx_log'),
          contains('docker logs --since 30m --tail 300 wukongim-prod-nginx'),
        );
        expect(
          _invokeCaptureBlock(content, 'remote_recent_api_log'),
          contains('docker logs --since 30m --tail 300 wukongim-prod-tsdd-api'),
        );
      },
    );

    test('redaction helper handles empty output and preserves later fields', () {
      final content =
          File('scripts/ops/collect_im_performance_baseline.ps1')
              .readAsStringSync();

      expect(
        _functionBlock(content, 'Write-RedactedContent'),
        contains('[AllowEmptyString()]'),
      );
      expect(
        _functionBlock(content, 'Redact-SensitiveText'),
        contains('structuredFieldBoundary'),
      );
      expect(
        _functionBlock(content, 'Redact-SensitiveText'),
        contains('Redact-SensitiveValueMatch'),
      );
    });

    test('redaction helper removes raw sensitive values at runtime', () async {
      if (!Platform.isWindows) {
        return;
      }

      final result = await Process.run('powershell', <String>[
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        r'''
$ErrorActionPreference = 'Stop'
$script = Get-Content -Raw scripts\ops\collect_im_performance_baseline.ps1
$start = $script.IndexOf('function Redact-SensitiveText')
$end = $script.IndexOf("Invoke-Capture -Name 'local_git_status'")
if ($start -lt 0 -or $end -lt 0 -or $end -le $start) { throw 'missing function bounds' }
. ([scriptblock]::Create($script.Substring($start, $end - $start)))
$fieldA = 'Authori' + 'zation'
$fieldB = 'pass' + 'word'
$fieldC = 'to' + 'ken'
$fieldD = 'd' + 'sn'
$sample = "$fieldA`: Bearer abc $fieldB=raw $fieldC=tok $fieldD=mysql://root:pw@host normal=ok refreshToken=1"
$redacted = Redact-SensitiveText -Text $sample
if ($redacted.Contains('Bearer' + ' abc') -or
    $redacted.Contains('=' + 'raw') -or
    $redacted.Contains('=' + 'tok') -or
    $redacted.Contains('mysql' + '://')) {
  throw "redaction failed: $redacted"
}
if (!$redacted.Contains("$fieldB=<redacted>") -or
    !$redacted.Contains("$fieldC=<redacted>") -or
    !$redacted.Contains("$fieldD=<redacted>") -or
    !$redacted.Contains('normal=ok') -or
    !$redacted.Contains('refreshToken=1')) {
  throw "field preservation failed: $redacted"
}
$path = Join-Path $env:TEMP 'wukong-baseline-empty-redaction.txt'
Write-RedactedContent -Path $path -Text ''
if (![string]::IsNullOrWhiteSpace((Get-Content -Raw $path))) { throw 'empty write failed' }
'runtime_redaction_ok'
''',
      ]);

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(result.stdout.toString(), contains('runtime_redaction_ok'));
    });
  });

  test(
    'baseline collector captures local build and remote runtime signals',
    () {
      final script = File('scripts/ops/collect_im_performance_baseline.ps1');

      expect(script.existsSync(), isTrue);

      final content = script.readAsStringSync();
      expect(content, contains('param('));
      expect(content, contains('RemoteRoot'));
      expect(content, contains('OutputDirectory'));
      expect(content, contains('flutter analyze'));
      expect(content, contains('flutter test'));
      expect(content, contains('flutter build web'));
      expect(content, contains('test/web_pwa_service_worker_test.dart'));
      expect(
        content,
        contains('test/realtime/session/session_runtime_test.dart'),
      );
      expect(
        content,
        contains(
          'test/realtime/telemetry/realtime_rollout_telemetry_test.dart',
        ),
      );
      expect(
        content,
        contains('test/app/navigation/app_push_route_bridge_test.dart'),
      );
      expect(content, contains('test/app/navigation/app_router_test.dart'));
      expect(
        content,
        contains('test/wukong_push/push_service_notification_tap_test.dart'),
      );
      expect(
        content,
        contains('test/wukong_push/foreground_notification_plan_test.dart'),
      );
      expect(content, contains('test/wukong_push/push_payload_test.dart'));
      expect(
        content,
        contains('test/wukong_push/browser_notification_service_test.dart'),
      );
      expect(
        content,
        contains('test/wukong_push/device_badge_service_test.dart'),
      );
      expect(
        content,
        contains(
          'test/wukong_push/browser_notification_click_bridge_test.dart',
        ),
      );
      expect(
        content,
        contains('test/modules/chat/chat_desktop_drop_target_test.dart'),
      );
      expect(
        content,
        contains('test/modules/chat/chat_media_action_service_test.dart'),
      );
      expect(
        content,
        contains('test/modules/chat/chat_image_bytes_loader_io_test.dart'),
      );
      expect(
        content,
        contains('test/modules/chat/chat_file_opening_test.dart'),
      );
      expect(content, contains('test/service/api/file_api_test.dart'));
      expect(content, contains('test/service/im/im_service_test.dart'));
      expect(
        content,
        contains('test/service/im/local_attachment_file_io_test.dart'),
      );
      expect(
        content,
        contains('test/modules/settings/cache_clean_service_test.dart'),
      );
      expect(
        content,
        contains(
          'test/modules/settings/backup_restore_message_service_test.dart',
        ),
      );
      expect(
        content,
        contains('test/widgets/local_media_image_provider_test.dart'),
      );
      expect(
        content,
        contains('test/wukong_base/utils/download_manager_naming_test.dart'),
      );
      expect(
        content,
        contains('test/wukong_base/utils/wk_file_utils_test.dart'),
      );
      expect(
        content,
        contains('test/core/utils/qr_export_file_naming_test.dart'),
      );
      expect(content, contains('test/wukong_scan/scan_webview_page_test.dart'));
      expect(
        content,
        contains('test/wukong_scan/scan_qr_code_image_io_test.dart'),
      );
      expect(
        content,
        contains('test/wukong_scan/scan_qr_code_image_stub_test.dart'),
      );
      expect(content, contains('build/web'));
      expect(content, contains('build/app/outputs/flutter-apk'));
      expect(content, contains('build/windows'));
      expect(content, contains('ssh'));
      expect(content, contains('docker stats'));
      expect(content, contains('nginx -T'));
      expect(content, contains('/varz'));
      expect(content, contains('remote_docker_status'));
      expect(content, contains('remote_nginx_config'));
      expect(content, contains('remote_public_web_smoke'));
      expect(content, contains('wk_pwa_service_worker.js'));
      expect(content, contains('remote_websocket_handshake'));
      expect(content, contains('remote_recent_nginx_log'));
      expect(content, contains('remote_recent_api_log'));
      expect(content, contains('Sec-WebSocket-Key'));
      expect(content, contains('101 Switching Protocols'));
    },
  );
}

String _invokeCaptureBlock(String source, String name) {
  final marker = "Invoke-Capture -Name '$name' -Command {";
  final start = source.indexOf(marker);
  expect(start, isNonNegative, reason: 'missing $name capture block');
  final rest = source.substring(start + marker.length);
  final end = rest.indexOf('\n}');
  expect(end, isNonNegative, reason: 'unterminated $name capture block');
  return rest.substring(0, end);
}

String _functionBlock(String source, String name) {
  final marker = 'function $name';
  final start = source.indexOf(marker);
  expect(start, isNonNegative, reason: 'missing $name function');
  final rest = source.substring(start);
  final end = rest.indexOf('\n}\n');
  expect(end, isNonNegative, reason: 'unterminated $name function');
  return rest.substring(0, end + 2);
}
