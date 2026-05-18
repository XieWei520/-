import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'IMService forwards Windows incoming messages to desktop alert manager',
    () {
      final source = File('lib/service/im/im_service.dart').readAsStringSync();
      final bridgeSource = File(
        'lib/service/im/im_notification_bridge.dart',
      ).readAsStringSync();

      expect(source, contains('im_notification_bridge.dart'));
      expect(source, contains('_notificationBridge.showMessageAlert'));
      expect(bridgeSource, contains('desktop_message_alert_manager.dart'));
      expect(bridgeSource, contains('message_alert_plan.dart'));
      expect(bridgeSource, contains('desktopAlerts.showNewMessageAlert'));
    },
  );

  test('Windows presenter uses local_notifier and Flutter system sounds', () {
    final source = File(
      'lib/wukong_push/notification/desktop_message_alert_presenter_io.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("import 'package:local_notifier/local_notifier.dart';"),
    );
    expect(source, contains("import 'package:flutter/services.dart';"));
    expect(source, contains('identifier: notification.identifier'));
    expect(source, contains('silent: true'));
    expect(source, contains('SystemSound.play'));
    expect(source, contains('SystemSoundType.click'));
    expect(source, contains('SystemSoundType.alert'));
    expect(source, isNot(contains("package:audioplayers/audioplayers.dart")));
    expect(source, isNot(contains('AudioPlayer(')));
  });

  test('pubspec declares local_notifier dependency', () {
    final source = File('pubspec.yaml').readAsStringSync();

    expect(source, contains('local_notifier: ^0.1.6'));
  });
}
