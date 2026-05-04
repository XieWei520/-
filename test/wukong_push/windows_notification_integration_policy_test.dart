import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('IMService forwards Windows incoming messages to desktop alert manager', () {
    final source = File('lib/service/im/im_service.dart').readAsStringSync();

    expect(source, contains('desktop_message_alert_manager.dart'));
    expect(source, contains('message_alert_plan.dart'));
    expect(source, contains('_scheduleDesktopMessageAlert'));
    expect(source, contains('TargetPlatform.windows'));
    expect(
      source,
      contains('DesktopMessageAlertManager.instance.showNewMessageAlert'),
    );
  });

  test('Windows presenter uses local_notifier and bundled audio assets', () {
    final source = File(
      'lib/wukong_push/notification/desktop_message_alert_presenter_io.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("import 'package:local_notifier/local_notifier.dart';"),
    );
    expect(source, contains('identifier: notification.identifier'));
    expect(source, contains('silent: true'));
    expect(source, contains('audio/im_tick.wav'));
    expect(source, contains('audio/im_message.wav'));
  });

  test('pubspec declares local_notifier dependency', () {
    final source = File('pubspec.yaml').readAsStringSync();

    expect(source, contains('local_notifier: ^0.1.6'));
  });
}
