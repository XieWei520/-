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
}
