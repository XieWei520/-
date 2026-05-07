import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'performance baseline script includes current client regression gates',
    () {
      final source = File(
        'scripts/ops/collect_im_performance_baseline.ps1',
      ).readAsStringSync();

      const requiredTests = <String>[
        'test/web_dependency_wasm_policy_test.dart',
        'test/platform_geolocator_boundary_test.dart',
        'test/modules/chat/chat_viewport_controller_test.dart',
        'test/modules/chat/chat_scroll_pagination_test.dart',
        'test/modules/conversation/conversation_metadata_resolver_test.dart',
        'test/core/cache/media_cache_manager_test.dart',
        'test/core/utils/platform_utils_test.dart',
        'test/modules/video_call/livekit_call_media_engine_test.dart',
        'test/modules/video_call/call_session_service_test.dart',
        'test/modules/video_call/call_bootstrap_api_test.dart',
        'test/modules/video_call/call_realtime_client_test.dart',
        'test/scripts/ops/flutter_web_release_prune_test.dart',
      ];

      for (final testPath in requiredTests) {
        expect(source, contains(testPath));
      }
      expect(source, contains('flutter build web --wasm --release'));
      expect(source, contains('prune_flutter_web_release.ps1'));
      expect(source, contains('-DryRun'));
    },
  );
}
