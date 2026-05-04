import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
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
      expect(content, contains('remote_public_web_smoke'));
      expect(content, contains('wk_pwa_service_worker.js'));
      expect(content, contains('remote_websocket_handshake'));
      expect(content, contains('Sec-WebSocket-Key'));
      expect(content, contains('101 Switching Protocols'));
    },
  );
}
