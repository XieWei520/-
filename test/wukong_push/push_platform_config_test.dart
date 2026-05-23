import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android manifest declares local alert and keep-alive permissions',
    () async {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
      expect(manifest, contains('android.permission.VIBRATE'));
      expect(manifest, contains('android.permission.FOREGROUND_SERVICE'));
      expect(
        manifest,
        contains('android.permission.FOREGROUND_SERVICE_REMOTE_MESSAGING'),
      );
      expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
      expect(
        manifest,
        contains('android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'),
      );
      expect(manifest, contains('AndroidKeepAliveForegroundService'));
      expect(manifest, contains('AndroidKeepAliveBootReceiver'));
      expect(manifest, contains('android:foregroundServiceType="remoteMessaging"'));
    },
  );

  test('iOS Info.plist enables remote notification background mode', () async {
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(infoPlist, contains('<key>UIBackgroundModes</key>'));
    expect(infoPlist, contains('<string>remote-notification</string>'));
  });

  test('iOS Runner target links push entitlements', () async {
    final entitlements = File('ios/Runner/Runner.entitlements');
    final projectFile = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(entitlements.existsSync(), isTrue);
    expect(
      projectFile,
      contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'),
    );
  });

  test('PushService source does not import dart io directly', () {
    final source = File('lib/wukong_push/push_service.dart').readAsStringSync();

    expect(source, isNot(contains("import 'dart:io'")));
  });

  test(
    'Android keep-alive user guidance states local IM limits without remote push',
    () {
      final source = File(
        'lib/wukong_push/android_keep_alive_service.dart',
      ).readAsStringSync();
      final nativeService = File(
        'android/app/src/main/kotlin/com/im/wukong_im_app/'
        'AndroidKeepAliveForegroundService.kt',
      ).readAsStringSync();

      expect(source, contains('本机后台提醒增强'));
      expect(source, contains('没有厂商推送时'));
      expect(source, contains('不等同于离线推送'));
      expect(nativeService, contains('本机后台提醒运行中'));
    },
  );

  test(
    'Android keep-alive diagnostics expose notification battery and service state',
    () {
      final dartSource = File(
        'lib/wukong_push/android_keep_alive_service.dart',
      ).readAsStringSync();
      final activitySource = File(
        'android/app/src/main/kotlin/com/im/wukong_im_app/MainActivity.kt',
      ).readAsStringSync();
      final serviceSource = File(
        'android/app/src/main/kotlin/com/im/wukong_im_app/'
        'AndroidKeepAliveForegroundService.kt',
      ).readAsStringSync();

      expect(dartSource, contains('AndroidKeepAliveStatus'));
      expect(dartSource, contains('getStatus'));
      expect(dartSource, contains('openNotificationSettings'));
      expect(dartSource, contains('通知权限'));
      expect(dartSource, contains('电池优化'));
      expect(dartSource, contains('保活服务'));
      expect(dartSource, contains('通知设置'));
      expect(dartSource, contains('后台设置'));
      expect(activitySource, contains('getKeepAliveStatus'));
      expect(activitySource, contains('openNotificationSettings'));
      expect(activitySource, contains('ACTION_APP_NOTIFICATION_SETTINGS'));
      expect(activitySource, contains('NotificationManagerCompat'));
      expect(activitySource, contains('isIgnoringBatteryOptimizations'));
      expect(serviceSource, contains('isRunning'));
    },
  );
}
