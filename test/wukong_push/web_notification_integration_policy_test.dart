import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'IMService forwards incoming messages to the shared web alert contract',
    () {
      final source = File('lib/service/im/im_service.dart').readAsStringSync();
      final bridgeSource = File(
        'lib/service/im/im_notification_bridge.dart',
      ).readAsStringSync();

      expect(source, contains('im_notification_bridge.dart'));
      expect(source, contains('_notificationBridge.showMessageAlert'));
      expect(source, contains('lifecycleState: _appLifecycleState'));
      expect(bridgeSource, contains('web_notification_manager.dart'));
      expect(bridgeSource, contains('buildMessageAlertPlan'));
      expect(bridgeSource, contains('webNotifications.showNewMessageAlert'));
      expect(bridgeSource, contains('plan: plan'));
    },
  );

  test(
    'login submit initializes the web notification manager from user gesture',
    () {
      final source = File(
        'lib/modules/auth/presentation/pages/auth_login_page.dart',
      ).readAsStringSync();

      expect(source, contains('web_notification_manager.dart'));
      expect(source, contains('WebNotificationManager.instance.init'));
      expect(source, contains('triggeredByAutoLogin'));
    },
  );

  test(
    'web notification implementation uses package web and never dart html',
    () {
      final source = File(
        'lib/wukong_push/notification/web_notification_manager_web.dart',
      ).readAsStringSync();

      expect(source, contains("import 'package:web/web.dart' as web;"));
      expect(source, isNot(contains('dart:html')));
    },
  );

  test('web notifications mirror the desktop alert policy', () {
    final source = File(
      'lib/wukong_push/notification/web_notification_manager_web.dart',
    ).readAsStringSync();

    expect(source, contains('DesktopMessageAlertPolicy'));
    expect(source, contains('MessageAlertPlan'));
    expect(source, contains('messageSoundAssetPath'));
    expect(source, contains('await _playMessageSound();'));
    expect(source, contains('silent: true'));
    expect(source, contains('browserNotification.onclick'));
    expect(source, contains('web.window.focus()'));
    expect(source, isNot(contains('startTitleBlink();')));
    expect(source, isNot(contains('silent: false')));
  });

  test('pubspec declares bundled notification audio assets', () {
    final source = File('pubspec.yaml').readAsStringSync();

    expect(source, contains('- assets/audio/'));
  });
}
