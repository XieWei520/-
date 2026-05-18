import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/widgets.dart';

import '../../core/utils/storage_utils.dart';
import 'desktop_message_alert_policy.dart';
import 'message_alert_plan.dart';
import 'notification_helper.dart';

const String androidMessageAlertNewMsgNoticeKey =
    'wk_android_message_alert_new_msg_notice';
const String androidMessageAlertShowMessageDetailKey =
    'wk_android_message_alert_show_message_detail';
const String androidMessageAlertVoiceOnKey =
    'wk_android_message_alert_voice_on';
const String androidMessageAlertShockOnKey =
    'wk_android_message_alert_shock_on';

class MessageAlertSettings {
  const MessageAlertSettings({
    this.newMsgNotice = true,
    this.showMessageDetail = true,
    this.voiceOn = true,
    this.shockOn = true,
  });

  final bool newMsgNotice;
  final bool showMessageDetail;
  final bool voiceOn;
  final bool shockOn;
}

abstract class MessageAlertSettingsStore {
  MessageAlertSettings read();
}

class StorageMessageAlertSettingsStore implements MessageAlertSettingsStore {
  const StorageMessageAlertSettingsStore();

  @override
  MessageAlertSettings read() {
    return MessageAlertSettings(
      newMsgNotice:
          StorageUtils.getBool(androidMessageAlertNewMsgNoticeKey) ?? true,
      showMessageDetail:
          StorageUtils.getBool(androidMessageAlertShowMessageDetailKey) ?? true,
      voiceOn: StorageUtils.getBool(androidMessageAlertVoiceOnKey) ?? true,
      shockOn: StorageUtils.getBool(androidMessageAlertShockOnKey) ?? true,
    );
  }
}

Future<void> persistAndroidMessageAlertSettings({
  required bool newMsgNotice,
  required bool showMessageDetail,
  required bool voiceOn,
  required bool shockOn,
}) async {
  if (!StorageUtils.isInitialized) {
    return;
  }
  await StorageUtils.setBool(androidMessageAlertNewMsgNoticeKey, newMsgNotice);
  await StorageUtils.setBool(
    androidMessageAlertShowMessageDetailKey,
    showMessageDetail,
  );
  await StorageUtils.setBool(androidMessageAlertVoiceOnKey, voiceOn);
  await StorageUtils.setBool(androidMessageAlertShockOnKey, shockOn);
}

class AndroidMessageNotification {
  const AndroidMessageNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.groupKey,
    this.payload = '',
    this.onlyAlertOnce = false,
    this.playSound = true,
    this.enableVibration = true,
  });

  final int id;
  final String title;
  final String body;
  final String groupKey;
  final String payload;
  final bool onlyAlertOnce;
  final bool playSound;
  final bool enableVibration;
}

abstract class AndroidMessageAlertPresenter {
  Future<void> initialize();

  Future<void> playForegroundTick();

  Future<void> showNotification(AndroidMessageNotification notification);

  Future<void> dispose();
}

class AndroidMessageAlertManager {
  AndroidMessageAlertManager({
    AndroidMessageAlertPresenter? presenter,
    DesktopMessageAlertPolicy? policy,
    MessageAlertSettingsStore? alertSettingsStore,
    MessageAlertSettings? alertSettings,
    bool Function()? isWeb,
    TargetPlatform Function()? targetPlatform,
  }) : _presenter = presenter ?? AndroidMessageAlertPresenterIo(),
       _policy = policy ?? DesktopMessageAlertPolicy(),
       _alertSettingsStore =
           alertSettingsStore ??
           _FixedMessageAlertSettingsStore(
             alertSettings,
             fallback: const StorageMessageAlertSettingsStore(),
           ),
       _isWeb = isWeb ?? (() => kIsWeb),
       _targetPlatform = targetPlatform ?? (() => defaultTargetPlatform);

  static final AndroidMessageAlertManager instance =
      AndroidMessageAlertManager();

  final AndroidMessageAlertPresenter _presenter;
  final DesktopMessageAlertPolicy _policy;
  final MessageAlertSettingsStore _alertSettingsStore;
  final bool Function() _isWeb;
  final TargetPlatform Function() _targetPlatform;

  Future<void> showNewMessageAlert({
    required MessageAlertPlan plan,
    required AppLifecycleState lifecycleState,
  }) async {
    if (_isWeb() || _targetPlatform() != TargetPlatform.android) {
      return;
    }

    final settings = _alertSettingsStore.read();
    if (!settings.newMsgNotice) {
      debugPrint('Android message alert skipped: new message notice disabled.');
      return;
    }

    final decision = _policy.resolve(
      plan: plan,
      lifecycleState: lifecycleState,
    );

    if (decision.playForegroundSound && settings.voiceOn) {
      await _presenter.playForegroundTick();
    }

    final notification = decision.notification;
    if (notification != null) {
      debugPrint(
        'Android message alert notification: lifecycle=$lifecycleState, '
        'channel=${NotificationHelper.messageAlertChannelId}, '
        'sound=${settings.voiceOn}, vibration=${settings.shockOn}, '
        'group=${notification.identifier}',
      );
      await _presenter.showNotification(
        AndroidMessageNotification(
          id: _stablePositiveId(notification.identifier),
          title: notification.title,
          body: settings.showMessageDetail ? notification.body : 'New message',
          groupKey: notification.identifier,
          payload: plan.payload,
          onlyAlertOnce: notification.count > 1,
          playSound: settings.voiceOn,
          enableVibration: settings.shockOn,
        ),
      );
    }
  }

  Future<void> dispose() => _presenter.dispose();
}

class _FixedMessageAlertSettingsStore implements MessageAlertSettingsStore {
  const _FixedMessageAlertSettingsStore(
    this._settings, {
    required MessageAlertSettingsStore fallback,
  }) : _fallback = fallback;

  final MessageAlertSettings? _settings;
  final MessageAlertSettingsStore _fallback;

  @override
  MessageAlertSettings read() => _settings ?? _fallback.read();
}

class AndroidMessageAlertPresenterIo implements AndroidMessageAlertPresenter {
  AndroidMessageAlertPresenterIo({
    String foregroundSoundAssetPath = 'audio/im_tick.wav',
    double foregroundVolume = 0.35,
    Duration foregroundSoundMaxDuration = const Duration(milliseconds: 180),
  }) : _foregroundSoundAssetPath = foregroundSoundAssetPath,
       _foregroundVolume = foregroundVolume.clamp(0.0, 1.0).toDouble(),
       _foregroundSoundMaxDuration = foregroundSoundMaxDuration;

  final AudioPlayer _foregroundPlayer = AudioPlayer(
    playerId: 'wk_android_notification_foreground',
  );
  final String _foregroundSoundAssetPath;
  final double _foregroundVolume;
  final Duration _foregroundSoundMaxDuration;

  bool _initialized = false;
  Timer? _foregroundStopTimer;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    await NotificationHelper.instance.initialize();
    await _foregroundPlayer.setReleaseMode(ReleaseMode.stop);
    _initialized = true;
  }

  @override
  Future<void> playForegroundTick() async {
    await initialize();
    try {
      _foregroundStopTimer?.cancel();
      await _safeStop(_foregroundPlayer);
      await _foregroundPlayer.play(
        AssetSource(_foregroundSoundAssetPath),
        volume: _foregroundVolume,
        mode: PlayerMode.lowLatency,
      );
      _foregroundStopTimer = Timer(
        _foregroundSoundMaxDuration,
        () => unawaited(_safeStop(_foregroundPlayer)),
      );
    } catch (error, stackTrace) {
      debugPrint('Playing Android foreground message alert failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Future<void> showNotification(AndroidMessageNotification notification) async {
    await initialize();
    await NotificationHelper.instance.show(
      id: notification.id,
      title: notification.title,
      body: notification.body,
      payload: notification.payload,
      channelId: NotificationHelper.messageAlertChannelId,
      channelName: NotificationHelper.messageAlertChannelName,
      channelDescription: NotificationHelper.messageAlertChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: notification.playSound,
      sound: notification.playSound
          ? const RawResourceAndroidNotificationSound(
              NotificationHelper.messageSoundResource,
            )
          : null,
      onlyAlertOnce: notification.onlyAlertOnce,
      groupKey: notification.groupKey,
      category: AndroidNotificationCategory.message,
      enableVibration: notification.enableVibration,
      audioAttributesUsage: AudioAttributesUsage.notification,
    );
  }

  @override
  Future<void> dispose() async {
    _foregroundStopTimer?.cancel();
    await _safeStop(_foregroundPlayer);
    await _foregroundPlayer.dispose();
  }

  Future<void> _safeStop(AudioPlayer player) async {
    try {
      await player.stop();
    } catch (error, stackTrace) {
      debugPrint('Stopping Android foreground alert failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

int _stablePositiveId(String value) {
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}
