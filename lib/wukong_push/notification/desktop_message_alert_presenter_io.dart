import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';

import '../../core/config/app_config.dart';
import 'desktop_message_alert_policy.dart';
import 'desktop_message_alert_presenter.dart';

DesktopMessageAlertPresenter createDesktopMessageAlertPresenter() {
  return DesktopMessageAlertPresenterIo();
}

class DesktopMessageAlertPresenterIo implements DesktopMessageAlertPresenter {
  DesktopMessageAlertPresenterIo({
    String foregroundSoundAssetPath = 'audio/im_tick.wav',
    String messageSoundAssetPath = 'audio/im_message.wav',
    double foregroundVolume = 0.35,
    double messageVolume = 0.65,
    Duration foregroundSoundMaxDuration = const Duration(milliseconds: 180),
    Duration messageSoundMaxDuration = const Duration(milliseconds: 900),
  }) : _foregroundSoundAssetPath = foregroundSoundAssetPath,
       _messageSoundAssetPath = messageSoundAssetPath,
       _foregroundVolume = foregroundVolume.clamp(0.0, 1.0).toDouble(),
       _messageVolume = messageVolume.clamp(0.0, 1.0).toDouble(),
       _foregroundSoundMaxDuration = foregroundSoundMaxDuration,
       _messageSoundMaxDuration = messageSoundMaxDuration;

  final AudioPlayer _foregroundPlayer = AudioPlayer(
    playerId: 'wk_desktop_notification_foreground',
  );
  final AudioPlayer _messagePlayer = AudioPlayer(
    playerId: 'wk_desktop_notification_message',
  );
  final String _foregroundSoundAssetPath;
  final String _messageSoundAssetPath;
  final double _foregroundVolume;
  final double _messageVolume;
  final Duration _foregroundSoundMaxDuration;
  final Duration _messageSoundMaxDuration;

  bool _initialized = false;
  Timer? _foregroundStopTimer;
  Timer? _messageStopTimer;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    try {
      await localNotifier.setup(
        appName: AppConfig.appName,
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      await Future.wait<void>([
        _foregroundPlayer.setReleaseMode(ReleaseMode.stop),
        _messagePlayer.setReleaseMode(ReleaseMode.stop),
      ]);
      _initialized = true;
    } catch (error, stackTrace) {
      _logError(
        'Desktop notification presenter initialization failed',
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<void> playForegroundTick() async {
    await _play(
      player: _foregroundPlayer,
      assetPath: _foregroundSoundAssetPath,
      volume: _foregroundVolume,
      maxDuration: _foregroundSoundMaxDuration,
      replaceTimer: (timer) => _foregroundStopTimer = timer,
      cancelTimer: () => _foregroundStopTimer?.cancel(),
    );
  }

  @override
  Future<void> playMessageSound() async {
    await _play(
      player: _messagePlayer,
      assetPath: _messageSoundAssetPath,
      volume: _messageVolume,
      maxDuration: _messageSoundMaxDuration,
      replaceTimer: (timer) => _messageStopTimer = timer,
      cancelTimer: () => _messageStopTimer?.cancel(),
    );
  }

  @override
  Future<void> showNotification(DesktopMessageNotification notification) async {
    await initialize();
    try {
      final localNotification = LocalNotification(
        identifier: notification.identifier,
        title: notification.title,
        body: notification.body,
        silent: true,
      );
      await localNotification.show();
    } catch (error, stackTrace) {
      _logError(
        'Showing desktop message notification failed',
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<void> dispose() async {
    _foregroundStopTimer?.cancel();
    _messageStopTimer?.cancel();
    await Future.wait<void>([
      _safeStop(_foregroundPlayer),
      _safeStop(_messagePlayer),
    ]);
    await Future.wait<void>([
      _foregroundPlayer.dispose(),
      _messagePlayer.dispose(),
    ]);
  }

  Future<void> _play({
    required AudioPlayer player,
    required String assetPath,
    required double volume,
    required Duration maxDuration,
    required void Function(Timer timer) replaceTimer,
    required void Function() cancelTimer,
  }) async {
    await initialize();
    try {
      cancelTimer();
      await _safeStop(player);
      await player.play(
        AssetSource(assetPath),
        volume: volume,
        mode: PlayerMode.lowLatency,
      );
      replaceTimer(Timer(maxDuration, () => unawaited(_safeStop(player))));
    } catch (error, stackTrace) {
      _logError(
        'Playing desktop message alert sound failed',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _safeStop(AudioPlayer player) async {
    try {
      await player.stop();
    } catch (error, stackTrace) {
      _logError('Stopping desktop alert sound failed', error, stackTrace);
    }
  }

  void _logError(String message, Object error, StackTrace stackTrace) {
    debugPrint('$message: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
