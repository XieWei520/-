import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../wukong_push/notification/notification_helper.dart';

enum NotificationSettingsChannel { message, rtc }

abstract class NotificationChannelSettingsBridge {
  Future<bool> openChannelSettings(NotificationSettingsChannel channel);
}

class DefaultNotificationChannelSettingsBridge
    implements NotificationChannelSettingsBridge {
  const DefaultNotificationChannelSettingsBridge();

  static const MethodChannel _channel = MethodChannel(
    'wukong_im_app/notification_settings',
  );

  @override
  Future<bool> openChannelSettings(NotificationSettingsChannel channel) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final opened = await _channel.invokeMethod<bool>(
          'openNotificationChannelSettings',
          <String, dynamic>{'channelId': _resolveChannelId(channel)},
        );
        if (opened == true) {
          return true;
        }
      } on MissingPluginException {
        // Fall back to the app-level notification settings page below.
      } on PlatformException {
        // Fall back to the app-level notification settings page below.
      }
    }
    return openAppSettings();
  }

  String _resolveChannelId(NotificationSettingsChannel channel) {
    switch (channel) {
      case NotificationSettingsChannel.message:
        return NotificationHelper.messageChannelId;
      case NotificationSettingsChannel.rtc:
        return NotificationHelper.rtcChannelId;
    }
  }
}
