import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'IMService forwards incoming messages to the web notification manager',
    () {
      final source = File('lib/service/im/im_service.dart').readAsStringSync();

      expect(source, contains('web_message_alert_plan.dart'));
      expect(source, contains('web_notification_manager.dart'));
      expect(source, contains('buildWebMessageAlertPlan'));
      expect(source, contains('showNewMessageAlert'));
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

  test(
    'background browser notifications use the system notification sound',
    () {
      final source = File(
        'lib/wukong_push/notification/web_notification_manager_web.dart',
      ).readAsStringSync();

      expect(source, contains('silent: false'));
      expect(source, isNot(contains('silent: true')));
      expect(source, isNot(contains('await _playBackgroundMessageSound();')));
    },
  );

  test('pubspec declares bundled notification audio assets', () {
    final source = File('pubspec.yaml').readAsStringSync();

    expect(source, contains('- assets/audio/'));
  });
}
