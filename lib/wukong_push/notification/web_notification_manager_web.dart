import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class WebNotificationManager {
  WebNotificationManager._internal();

  static final WebNotificationManager instance =
      WebNotificationManager._internal();

  factory WebNotificationManager() => instance;

  final AudioPlayer _foregroundPlayer = AudioPlayer(
    playerId: 'wk_web_notification_foreground',
  );
  final AudioPlayer _backgroundPlayer = AudioPlayer(
    playerId: 'wk_web_notification_background',
  );
  final AudioPlayer _unlockPlayer = AudioPlayer(
    playerId: 'wk_web_notification_unlock',
  );

  String _foregroundSoundAssetPath = 'audio/im_tick.wav';
  String _messageSoundAssetPath = 'audio/im_message.wav';
  String _unlockSoundAssetPath = 'audio/silence.wav';
  String? _notificationIcon = 'icons/Icon-192.png';
  String _notificationTag = 'wk-im-new-message';
  double _foregroundVolume = 0.35;
  double _backgroundVolume = 1.0;
  double _unlockVolume = 1.0;
  Duration _foregroundSoundMaxDuration = const Duration(milliseconds: 180);
  Duration _titleBlinkInterval = const Duration(milliseconds: 500);

  Future<void>? _initFuture;
  Timer? _titleBlinkTimer;
  Timer? _foregroundStopTimer;
  String? _titleBeforeBlink;
  bool _showBlinkText = true;
  web.EventListener? _visibilityChangeListener;
  bool _initialized = false;
  String _notificationPermission = 'default';

  bool get isInitialized => _initialized;

  String get notificationPermission => _notificationPermission;

  /// 初始化 Web 通知能力。
  ///
  /// 重要：
  /// 此方法应在用户产生点击交互时调用，例如登录按钮、进入聊天按钮等。
  /// 浏览器通常只允许“用户手势触发”的代码请求 Notification 权限，
  /// 并且音频自动播放限制也需要在用户手势里通过一次极短播放来解锁。
  ///
  /// 不建议在 main()、initState() 或自动登录流程里首次调用，因为那通常
  /// 不属于浏览器认可的用户手势，可能导致权限弹窗不出现或提示音被静音。
  Future<void> init({
    String foregroundSoundAssetPath = 'audio/im_tick.wav',
    String messageSoundAssetPath = 'audio/im_message.wav',
    String unlockSoundAssetPath = 'audio/silence.wav',
    String? notificationIcon = 'icons/Icon-192.png',
    String notificationTag = 'wk-im-new-message',
    double foregroundVolume = 0.35,
    double backgroundVolume = 1.0,
    double unlockVolume = 1.0,
    Duration foregroundSoundMaxDuration = const Duration(milliseconds: 180),
    Duration titleBlinkInterval = const Duration(milliseconds: 500),
  }) {
    _foregroundSoundAssetPath = foregroundSoundAssetPath;
    _messageSoundAssetPath = messageSoundAssetPath;
    _unlockSoundAssetPath = unlockSoundAssetPath;
    _notificationIcon = notificationIcon;
    _notificationTag = notificationTag;
    _foregroundVolume = _normalizeVolume(foregroundVolume);
    _backgroundVolume = _normalizeVolume(backgroundVolume);
    _unlockVolume = _normalizeVolume(unlockVolume);
    _foregroundSoundMaxDuration = foregroundSoundMaxDuration;
    _titleBlinkInterval = titleBlinkInterval;

    _bindVisibilityChangeListener();
    _initFuture ??= _initialize();
    return _initFuture!;
  }

  bool isPageVisible() {
    try {
      return web.document.visibilityState == 'visible';
    } catch (error, stackTrace) {
      _logError('读取页面可见性失败', error, stackTrace);
      return true;
    }
  }

  void startTitleBlink({String blinkTitle = '【新消息】', String blankTitle = '　'}) {
    try {
      if (isPageVisible() || _titleBlinkTimer?.isActive == true) {
        return;
      }

      _titleBeforeBlink ??= web.document.title;
      _showBlinkText = false;
      web.document.title = blinkTitle;

      _titleBlinkTimer = Timer.periodic(_titleBlinkInterval, (_) {
        try {
          if (isPageVisible()) {
            stopTitleBlink();
            return;
          }
          web.document.title = _showBlinkText ? blinkTitle : blankTitle;
          _showBlinkText = !_showBlinkText;
        } catch (error, stackTrace) {
          _logError('标题闪烁执行失败', error, stackTrace);
          stopTitleBlink();
        }
      });
    } catch (error, stackTrace) {
      _logError('开启标题闪烁失败', error, stackTrace);
    }
  }

  void stopTitleBlink() {
    final originalTitle = _titleBeforeBlink;
    _titleBlinkTimer?.cancel();
    _titleBlinkTimer = null;
    _titleBeforeBlink = null;
    _showBlinkText = true;

    if (originalTitle == null) {
      return;
    }

    try {
      web.document.title = originalTitle;
    } catch (error, stackTrace) {
      _logError('恢复原始标题失败', error, stackTrace);
    }
  }

  Future<void> showNewMessageAlert({
    required String title,
    required String body,
  }) async {
    _bindVisibilityChangeListener();

    try {
      if (isPageVisible()) {
        stopTitleBlink();
        await _playForegroundTick();
        return;
      }

      await _playBackgroundMessageSound();
      _showSystemNotification(title: title, body: body);
      startTitleBlink();
    } catch (error, stackTrace) {
      _logError('处理新消息提醒失败', error, stackTrace);
    }
  }

  Future<void> dispose() async {
    _foregroundStopTimer?.cancel();
    stopTitleBlink();
    final listener = _visibilityChangeListener;
    if (listener != null) {
      try {
        web.document.removeEventListener('visibilitychange', listener);
      } catch (error, stackTrace) {
        _logError('移除 visibilitychange 事件失败', error, stackTrace);
      }
    }
    _visibilityChangeListener = null;

    await Future.wait<void>([
      _foregroundPlayer.dispose(),
      _backgroundPlayer.dispose(),
      _unlockPlayer.dispose(),
    ]);
  }

  Future<void> _initialize() async {
    try {
      final unlockFuture = _unlockAudioForAutoplay();
      final permissionFuture = _requestNotificationPermission();
      unawaited(_configurePlayers());

      await Future.wait<void>([unlockFuture, permissionFuture]);
      await _configurePlayers();
      _initialized = true;
    } catch (error, stackTrace) {
      _logError('WebNotificationManager 初始化失败', error, stackTrace);
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      if (!_supportsNotification()) {
        _notificationPermission = 'unsupported';
        return;
      }

      final currentPermission = web.Notification.permission;
      _notificationPermission = currentPermission;
      if (currentPermission != 'default') {
        return;
      }

      final permission = await web.Notification.requestPermission().toDart;
      _notificationPermission = permission.toDart;
    } catch (error, stackTrace) {
      _logError('请求 Notification 权限失败', error, stackTrace);
    }
  }

  Future<void> _unlockAudioForAutoplay() async {
    try {
      await _unlockPlayer.play(
        AssetSource(_unlockSoundAssetPath),
        volume: _unlockVolume,
        mode: PlayerMode.lowLatency,
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await _safeStop(_unlockPlayer);
    } catch (error, stackTrace) {
      _logError('解锁浏览器音频自动播放失败，请确认 init() 由用户点击触发且音频资源存在', error, stackTrace);
    }
  }

  Future<void> _configurePlayers() async {
    try {
      await Future.wait<void>([
        _foregroundPlayer.setReleaseMode(ReleaseMode.stop),
        _backgroundPlayer.setReleaseMode(ReleaseMode.stop),
        _unlockPlayer.setReleaseMode(ReleaseMode.stop),
      ]);
    } catch (error, stackTrace) {
      _logError('配置音频播放器失败', error, stackTrace);
    }
  }

  Future<void> _playForegroundTick() async {
    try {
      _foregroundStopTimer?.cancel();
      await _safeStop(_foregroundPlayer);
      await _foregroundPlayer.play(
        AssetSource(_foregroundSoundAssetPath),
        volume: _foregroundVolume,
        mode: PlayerMode.lowLatency,
      );

      _foregroundStopTimer = Timer(_foregroundSoundMaxDuration, () {
        unawaited(_safeStop(_foregroundPlayer));
      });
    } catch (error, stackTrace) {
      _logError('播放前台极短提示音失败', error, stackTrace);
    }
  }

  Future<void> _playBackgroundMessageSound() async {
    try {
      await _safeStop(_backgroundPlayer);
      await _backgroundPlayer.play(
        AssetSource(_messageSoundAssetPath),
        volume: _backgroundVolume,
        mode: PlayerMode.lowLatency,
      );
    } catch (error, stackTrace) {
      _logError('播放后台新消息提示音失败', error, stackTrace);
    }
  }

  void _showSystemNotification({required String title, required String body}) {
    try {
      if (!_supportsNotification()) {
        return;
      }

      final permission = web.Notification.permission;
      _notificationPermission = permission;
      if (permission != 'granted') {
        return;
      }

      final notification = web.Notification(
        title,
        _buildNotificationOptions(body),
      );
      notification.onclick = ((web.Event event) {
        try {
          web.window.focus();
          notification.close();
          stopTitleBlink();
        } catch (error, stackTrace) {
          _logError('处理系统通知点击事件失败', error, stackTrace);
        }
      }).toJS;
    } catch (error, stackTrace) {
      _logError('显示系统通知失败', error, stackTrace);
    }
  }

  web.NotificationOptions _buildNotificationOptions(String body) {
    final icon = _notificationIcon?.trim() ?? '';
    if (icon.isEmpty) {
      return web.NotificationOptions(
        body: body,
        tag: _notificationTag,
        renotify: true,
        silent: true,
        requireInteraction: false,
      );
    }

    return web.NotificationOptions(
      body: body,
      tag: _notificationTag,
      icon: icon,
      badge: 'icons/Icon-maskable-192.png',
      renotify: true,
      silent: true,
      requireInteraction: false,
    );
  }

  void _bindVisibilityChangeListener() {
    if (_visibilityChangeListener != null) {
      return;
    }

    try {
      _visibilityChangeListener = ((web.Event event) {
        if (isPageVisible()) {
          stopTitleBlink();
        }
      }).toJS;
      web.document.addEventListener(
        'visibilitychange',
        _visibilityChangeListener,
      );
    } catch (error, stackTrace) {
      _logError('绑定 visibilitychange 事件失败', error, stackTrace);
    }
  }

  bool _supportsNotification() {
    try {
      return globalContext.has('Notification');
    } catch (error, stackTrace) {
      _logError('检测 Notification 支持失败', error, stackTrace);
      return false;
    }
  }

  Future<void> _safeStop(AudioPlayer player) async {
    try {
      await player.stop();
    } catch (error, stackTrace) {
      _logError('停止音频失败', error, stackTrace);
    }
  }

  double _normalizeVolume(double value) {
    return value.clamp(0.0, 1.0).toDouble();
  }

  void _logError(String message, Object error, StackTrace stackTrace) {
    debugPrint('$message: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
