import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_push/notification/notification_helper.dart';

void main() {
  test('IMService wires Android local message alerts without FCM', () {
    final source = File('lib/service/im/im_service.dart').readAsStringSync();
    final bridgeSource = File(
      'lib/service/im/im_notification_bridge.dart',
    ).readAsStringSync();

    expect(source, contains('im_notification_bridge.dart'));
    expect(source, contains('_notificationBridge.showMessageAlert'));
    expect(bridgeSource, contains('android_message_alert_manager.dart'));
    expect(bridgeSource, contains('_shouldRequireRedDot'));
    expect(bridgeSource, contains('androidAlerts.showNewMessageAlert'));
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

  test('Android release resources keep notification sound and icon', () {
    final keepXml = File(
      'android/app/src/main/res/raw/keep.xml',
    ).readAsStringSync();

    expect(
      keepXml,
      contains('@raw/${NotificationHelper.messageSoundResource}'),
    );
    expect(keepXml, contains('@mipmap/ic_launcher'));
  });

  test('Android release keeps local notification Gson metadata signatures', () {
    final buildGradle = File('android/app/build.gradle.kts').readAsStringSync();
    final proguardRules = File(
      'android/app/proguard-rules.pro',
    ).readAsStringSync();

    expect(buildGradle, contains('proguard-rules.pro'));
    expect(proguardRules, contains('-keepattributes Signature'));
    expect(proguardRules, contains('com.google.gson.reflect.TypeToken'));
    expect(
      proguardRules,
      contains('@com.google.gson.annotations.SerializedName'),
    );
  });
}
