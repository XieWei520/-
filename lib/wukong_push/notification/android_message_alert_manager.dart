import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/widgets.dart';

import 'desktop_message_alert_policy.dart';
import 'message_alert_plan.dart';
import 'notification_helper.dart';

class AndroidMessageNotification {
  const AndroidMessageNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.groupKey,
    this.payload = '',
    this.onlyAlertOnce = false,
  });

  final int id;
  final String title;
  final String body;
  final String groupKey;
  final String payload;
  final bool onlyAlertOnce;
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
    bool Function()? isWeb,
    TargetPlatform Function()? targetPlatform,
  }) : _presenter = presenter ?? AndroidMessageAlertPresenterIo(),
       _policy = policy ?? DesktopMessageAlertPolicy(),
       _isWeb = isWeb ?? (() => kIsWeb),
       _targetPlatform = targetPlatform ?? (() => defaultTargetPlatform);

  static final AndroidMessageAlertManager instance =
      AndroidMessageAlertManager();

  final AndroidMessageAlertPresenter _presenter;
  final DesktopMessageAlertPolicy _policy;
  final bool Function() _isWeb;
  final TargetPlatform Function() _targetPlatform;

  Future<void> showNewMessageAlert({
    required MessageAlertPlan plan,
    required AppLifecycleState lifecycleState,
  }) async {
    if (_isWeb() || _targetPlatform() != TargetPlatform.android) {
      return;
    }

    final decision = _policy.resolve(
      plan: plan,
      lifecycleState: lifecycleState,
    );

    if (decision.playForegroundSound) {
      await _presenter.playForegroundTick();
    }

    final notification = decision.notification;
    if (notification != null) {
      await _presenter.showNotification(
        AndroidMessageNotification(
          id: _stablePositiveId(notification.identifier),
          title: notification.title,
          body: notification.body,
          groupKey: notification.identifier,
          payload: plan.payload,
          onlyAlertOnce: notification.count > 1,
        ),
      );
    }
  }

  Future<void> dispose() => _presenter.dispose();
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
      playSound: true,
      sound: const RawResourceAndroidNotificationSound(
        NotificationHelper.messageSoundResource,
      ),
      onlyAlertOnce: notification.onlyAlertOnce,
      groupKey: notification.groupKey,
      category: AndroidNotificationCategory.message,
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
