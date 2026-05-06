import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_push/notification/notification_helper.dart';

void main() {
  test('IMService wires Android local message alerts without FCM', () {
    final source = File('lib/service/im/im_service.dart').readAsStringSync();

    expect(source, contains('android_message_alert_manager.dart'));
    expect(source, contains('_scheduleAndroidMessageAlert'));
    expect(source, contains('TargetPlatform.android'));
    expect(
      source,
      contains('AndroidMessageAlertManager.instance.showNewMessageAlert'),
    );
  });

  test('PushService does not enable FCM unless explicitly opted in', () {
    final source = File('lib/wukong_push/push_service.dart').readAsStringSync();

    expect(source, contains('WK_ENABLE_FCM_PUSH'));
    expect(source, contains('defaultValue: false'));
  });

  test('Android resources include the raw message sound', () {
    expect(
      File(
        'android/app/src/main/res/raw/'
        '${NotificationHelper.messageSoundResource}.wav',
      ).existsSync(),
      isTrue,
    );
  });
}
