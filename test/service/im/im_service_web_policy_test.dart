import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/im/im_service.dart';

void main() {
  test('web IM initialization does not require local sqflite persistence', () {
    expect(shouldUseImLocalPersistence(isWeb: true, sdkAppMode: true), isFalse);
  });

  test('native app IM initialization keeps local sqflite persistence', () {
    expect(shouldUseImLocalPersistence(isWeb: false, sdkAppMode: true), isTrue);
  });

  test('web IM initialization does not start native session runtime', () {
    expect(shouldStartNativeSessionRuntime(isWeb: true), isFalse);
  });

  test('web IM keeps websocket alive while page is backgrounded', () {
    expect(
      shouldDisconnectForBackgroundLifecycle(
        isWeb: true,
        hasActiveCallOrPendingSetup: false,
      ),
      isFalse,
    );
  });

  test('native IM may disconnect in background when no call is active', () {
    expect(
      shouldDisconnectForBackgroundLifecycle(
        isWeb: false,
        hasActiveCallOrPendingSetup: false,
      ),
      isTrue,
    );
    expect(
      shouldDisconnectForBackgroundLifecycle(
        isWeb: false,
        hasActiveCallOrPendingSetup: true,
      ),
      isFalse,
    );
  });

  test('IMService source does not import dart io directly', () {
    final source = File('lib/service/im/im_service.dart').readAsStringSync();

    expect(source, isNot(contains("import 'dart:io'")));
  });
}
