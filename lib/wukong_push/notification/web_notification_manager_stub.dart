import 'dart:async';

class WebNotificationManager {
  WebNotificationManager._internal();

  static final WebNotificationManager instance =
      WebNotificationManager._internal();

  factory WebNotificationManager() => instance;

  bool get isInitialized => false;

  String get notificationPermission => 'unsupported';

  Future<void> init({
    String foregroundSoundAssetPath = 'audio/im_tick.wav',
    String messageSoundAssetPath = 'audio/im_message.wav',
    String unlockSoundAssetPath = 'audio/silence.wav',
    String? notificationIcon,
    String notificationTag = 'wk-im-new-message',
    double foregroundVolume = 0.35,
    double backgroundVolume = 1.0,
    double unlockVolume = 1.0,
    Duration foregroundSoundMaxDuration = const Duration(milliseconds: 180),
    Duration titleBlinkInterval = const Duration(milliseconds: 500),
  }) async {}

  bool isPageVisible() => true;

  void startTitleBlink({
    String blinkTitle = '【新消息】',
    String blankTitle = '　',
  }) {}

  void stopTitleBlink() {}

  Future<void> showNewMessageAlert({
    required String title,
    required String body,
  }) async {}

  Future<void> dispose() async {}
}
