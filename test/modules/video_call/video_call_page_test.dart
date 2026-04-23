import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/call.dart';
import 'package:wukong_im_app/modules/video_call/video_call_page.dart';
import 'package:wukong_im_app/modules/video_call/video_call_service.dart';

void main() {
  test(
    'resolves a safe fallback title and avatar label for empty peer info',
    () {
      final title = resolveCallDisplayTitle(channelId: '', channelName: '  ');

      expect(title, 'Unknown');
      expect(resolveCallAvatarLabel(''), '?');
    },
  );

  test('does not render video views before rtc renderers are initialized', () {
    expect(
      shouldRenderRemoteVideo(
        callType: CallType.video,
        callState: CallState.connected,
        renderersInitialized: false,
      ),
      isFalse,
    );
    expect(
      shouldRenderLocalPreview(
        callType: CallType.video,
        showIncomingActions: false,
        renderersInitialized: false,
      ),
      isFalse,
    );
    expect(
      shouldRenderLocalPreview(
        callType: CallType.video,
        showIncomingActions: false,
        renderersInitialized: true,
      ),
      isTrue,
    );
  });

  test(
    'shows a local camera placeholder when video preview is unavailable',
    () {
      expect(
        shouldShowLocalCameraPlaceholder(
          isCameraOff: false,
          localVideoAvailable: false,
        ),
        isTrue,
      );
      expect(
        shouldShowLocalCameraPlaceholder(
          isCameraOff: true,
          localVideoAvailable: true,
        ),
        isTrue,
      );
      expect(
        shouldShowLocalCameraPlaceholder(
          isCameraOff: false,
          localVideoAvailable: true,
        ),
        isFalse,
      );
    },
  );

  test('app startup and im service do not import web call stubs', () {
    final appSource = File('lib/app/app.dart').readAsStringSync();
    final imServiceSource = File(
      'lib/service/im/im_service.dart',
    ).readAsStringSync();

    expect(appSource, isNot(contains('call_coordinator_stub.dart')));
    expect(imServiceSource, isNot(contains('call_coordinator_stub.dart')));
    expect(imServiceSource, isNot(contains('video_call_service_stub.dart')));
  });
}
