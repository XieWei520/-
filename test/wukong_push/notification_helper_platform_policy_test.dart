import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_push/notification/notification_helper.dart';

void main() {
  group('NotificationHelper platform policy', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test(
      'uses flutter_local_notifications only on supported native targets',
      () {
        expect(
          NotificationHelper.supportsLocalNotificationsForPlatform(
            isWeb: false,
            platform: TargetPlatform.android,
          ),
          isTrue,
        );
        expect(
          NotificationHelper.supportsLocalNotificationsForPlatform(
            isWeb: false,
            platform: TargetPlatform.iOS,
          ),
          isTrue,
        );
        expect(
          NotificationHelper.supportsLocalNotificationsForPlatform(
            isWeb: false,
            platform: TargetPlatform.macOS,
          ),
          isTrue,
        );

        expect(
          NotificationHelper.supportsLocalNotificationsForPlatform(
            isWeb: false,
            platform: TargetPlatform.windows,
          ),
          isFalse,
        );
        expect(
          NotificationHelper.supportsLocalNotificationsForPlatform(
            isWeb: false,
            platform: TargetPlatform.linux,
          ),
          isFalse,
        );
        expect(
          NotificationHelper.supportsLocalNotificationsForPlatform(
            isWeb: true,
            platform: TargetPlatform.android,
          ),
          isFalse,
        );
      },
    );

    test('cancel is a quiet no-op on unsupported Windows desktop', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final previousDebugPrint = debugPrint;
      final messages = <String>[];
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          messages.add(message);
        }
      };
      addTearDown(() {
        debugPrint = previousDebugPrint;
      });

      await NotificationHelper.instance.cancel(2);

      expect(
        messages.join('\n'),
        isNot(contains('NotificationHelper.cancel failed')),
      );
    });
  });
}
