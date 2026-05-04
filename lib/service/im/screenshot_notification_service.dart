import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/model/wk_screenshot_content.dart';
import 'package:wukongimfluttersdk/wkim.dart';

/// Service for sending screenshot notification messages.
///
/// When a screenshot is detected in a private chat, call [sendNotification]
/// to notify the peer. The actual screenshot detection (platform-specific)
/// should be implemented separately and call this service.
class ScreenshotNotificationService {
  ScreenshotNotificationService._();
  static final ScreenshotNotificationService instance =
      ScreenshotNotificationService._();

  /// Send a screenshot notification to a specific channel.
  ///
  /// Typically called for P2P (personal) chats only.
  Future<void> sendNotification({
    required String channelId,
    required int channelType,
  }) async {
    final content = WKScreenshotContent();
    final channel = WKChannel(channelId, channelType);
    await WKIM.shared.messageManager.sendMessage(content, channel);
  }
}
