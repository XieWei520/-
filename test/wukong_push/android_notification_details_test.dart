import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_push/notification/notification_helper.dart';

void main() {
  group('Android message alert notification details', () {
    test('uses a high-priority channel with the classic message sound', () {
      final channel = NotificationHelper.buildAndroidMessageAlertChannel();

      expect(channel.id, NotificationHelper.messageAlertChannelId);
      expect(channel.name, NotificationHelper.messageAlertChannelName);
      expect(channel.importance, Importance.high);
      expect(channel.playSound, isTrue);
      expect(channel.sound, isA<RawResourceAndroidNotificationSound>());
      expect(
        (channel.sound! as RawResourceAndroidNotificationSound).sound,
        NotificationHelper.messageSoundResource,
      );
      expect(channel.audioAttributesUsage, AudioAttributesUsage.notification);
    });

    test('builds heads-up message card details with sound and grouping', () {
      final details = NotificationHelper.buildAndroidMessageAlertDetails(
        groupKey: 'wk-message-1-alice',
        onlyAlertOnce: true,
      );

      expect(details.channelId, NotificationHelper.messageAlertChannelId);
      expect(details.channelName, NotificationHelper.messageAlertChannelName);
      expect(details.importance, Importance.high);
      expect(details.priority, Priority.high);
      expect(details.playSound, isTrue);
      expect(details.sound, isA<RawResourceAndroidNotificationSound>());
      expect(
        (details.sound! as RawResourceAndroidNotificationSound).sound,
        NotificationHelper.messageSoundResource,
      );
      expect(details.category, AndroidNotificationCategory.message);
      expect(details.groupKey, 'wk-message-1-alice');
      expect(details.onlyAlertOnce, isTrue);
      expect(details.audioAttributesUsage, AudioAttributesUsage.notification);
    });

    test('details can follow user sound and vibration switches', () {
      final details = NotificationHelper.buildAndroidMessageAlertDetails(
        playSound: false,
        enableVibration: false,
      );

      expect(details.playSound, isFalse);
      expect(details.sound, isNull);
      expect(details.enableVibration, isFalse);
    });
  });
}
