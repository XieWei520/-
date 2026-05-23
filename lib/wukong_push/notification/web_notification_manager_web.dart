import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../../service/api/web_push_api.dart';
import 'desktop_message_alert_policy.dart';
import 'message_alert_plan.dart';
import 'web_alert_capability.dart';

class WebNotificationManager {
  WebNotificationManager._internal();

  static final WebNotificationManager instance =
      WebNotificationManager._internal();

  factory WebNotificationManager() => instance;

  final AudioPlayer _foregroundPlayer = AudioPlayer(
    playerId: 'wk_web_notification_foreground',
  );
  final AudioPlayer _messagePlayer = AudioPlayer(
    playerId: 'wk_web_notification_message',
  );
  final AudioPlayer _unlockPlayer = AudioPlayer(
    playerId: 'wk_web_notification_unlock',
  );
  final DesktopMessageAlertPolicy _policy = DesktopMessageAlertPolicy();

  web.HTMLAudioElement? _foregroundElement;
  web.HTMLAudioElement? _messageElement;
  String _foregroundSoundAssetPath = 'audio/im_tick.wav';
  String _messageSoundAssetPath = 'audio/im_message.wav';
  String _unlockSoundAssetPath = 'audio/silence.wav';
  String? _notificationIcon = 'icons/Icon-192.png';
  String _notificationTag = 'wk-im-new-message';
  double _foregroundVolume = 0.35;
  double _messageVolume = 0.65;
  double _unlockVolume = 1.0;
  Duration _foregroundSoundMaxDuration = const Duration(milliseconds: 180);
  final Duration _messageSoundMaxDuration = const Duration(milliseconds: 900);
  Duration _titleBlinkInterval = const Duration(milliseconds: 500);

  Future<void>? _initFuture;
  Timer? _titleBlinkTimer;
  Timer? _foregroundStopTimer;
  Timer? _messageStopTimer;
  Timer? _visibleHeartbeatTimer;
  String? _titleBeforeBlink;
  bool _showBlinkText = true;
  web.EventListener? _visibilityChangeListener;
  web.EventListener? _pageHideListener;
  bool _initialized = false;
  String _notificationPermission = 'default';
  String? _lastWebPushEndpoint;

  bool get isInitialized => _initialized;

  String get notificationPermission => _readNotificationPermission();

  WebAlertCapability get capability => buildWebAlertCapability(
    userAgent: _userAgent(),
    standalone: _isStandaloneDisplay(),
    notificationPermission: _readNotificationPermission(),
    supportsNotification: _supportsNotification(),
    supportsServiceWorker: _supportsServiceWorker(),
    supportsPush: _supportsPush(),
    secureContext: _isSecureContext(),
  );

  /// Initializes browser notifications from a user gesture.
  ///
  /// Call this from login or another explicit click path so the browser can
  /// request Notification permission and unlock audio playback.
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
    _messageVolume = _normalizeVolume(backgroundVolume);
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
    required MessageAlertPlan plan,
    required AppLifecycleState lifecycleState,
  }) async {
    _bindVisibilityChangeListener();

    try {
      final decision = _policy.resolve(
        plan: plan,
        lifecycleState: lifecycleState,
      );

      if (decision.playForegroundSound) {
        stopTitleBlink();
        await _playForegroundTick();
        return;
      }

      if (decision.playMessageSound) {
        stopTitleBlink();
        await _playMessageSound();
      }

      final notification = decision.notification;
      if (notification == null) {
        return;
      }

      await _showBrowserNotification(notification);
    } catch (error, stackTrace) {
      _logError('处理新消息提醒失败', error, stackTrace);
    }
  }

  Future<void> refreshBackgroundDeliveryState({
    String? visibilityOverride,
  }) async {
    _bindVisibilityChangeListener();
    await _ensureWebPushSubscription();
    await _reportWebPushClientState(visibilityOverride: visibilityOverride);
  }

  Future<void> dispose() async {
    _foregroundStopTimer?.cancel();
    _messageStopTimer?.cancel();
    _stopVisibleHeartbeat();
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
    final pageHideListener = _pageHideListener;
    if (pageHideListener != null) {
      try {
        web.window.removeEventListener('pagehide', pageHideListener);
      } catch (error, stackTrace) {
        _logError('移除 pagehide 事件失败', error, stackTrace);
      }
    }
    _pageHideListener = null;

    await Future.wait<void>([
      _foregroundPlayer.dispose(),
      _messagePlayer.dispose(),
      _unlockPlayer.dispose(),
    ]);
    _releaseHtmlAudioElements();
  }

  Future<void> _initialize() async {
    try {
      final unlockFuture = _unlockAudioForAutoplay();
      final elementUnlockFuture = _unlockHtmlAudioElementsForIos();
      final permissionFuture = _requestNotificationPermission();
      unawaited(_configurePlayers());

      await Future.wait<void>([
        unlockFuture,
        elementUnlockFuture,
        permissionFuture,
      ]);
      unawaited(_ensureWebPushSubscription());
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

      final currentPermission = _readNotificationPermission();
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

  String _readNotificationPermission() {
    try {
      if (!_supportsNotification()) {
        _notificationPermission = 'unsupported';
        return _notificationPermission;
      }
      _notificationPermission = web.Notification.permission;
      return _notificationPermission;
    } catch (error, stackTrace) {
      _logError('读取 Notification 权限失败', error, stackTrace);
      return _notificationPermission;
    }
  }

  Future<void> _ensureWebPushSubscription() async {
    try {
      if (_readNotificationPermission() != 'granted') {
        return;
      }
      if (!_supportsServiceWorker() ||
          !_supportsPush() ||
          !_isSecureContext()) {
        return;
      }

      final config = await WebPushApi.instance.getWebPushConfig();
      if (!config.canSubscribe) {
        return;
      }

      final registration =
          await web.window.navigator.serviceWorker.ready.toDart;
      final pushManager = registration.pushManager;
      var subscription = await pushManager.getSubscription().toDart;
      if (subscription == null) {
        final applicationServerKey = _decodeVapidPublicKey(config.publicKey);
        subscription = await _subscribeWebPush(
          pushManager,
          applicationServerKey,
        );
      }

      final payload = _toWebPushSubscription(subscription);
      if (!payload.isValid) {
        return;
      }
      _lastWebPushEndpoint = payload.endpoint;
      await WebPushApi.instance.registerWebPushSubscription(payload);
      unawaited(_reportWebPushClientState());
    } catch (error, stackTrace) {
      _logError('注册 Web Push 订阅失败', error, stackTrace);
    }
  }

  WebPushSubscription _toWebPushSubscription(
    web.PushSubscription subscription,
  ) {
    return WebPushSubscription(
      endpoint: subscription.endpoint,
      expirationTime: subscription.expirationTime,
      p256dh: _encodePushKey(subscription.getKey('p256dh')),
      auth: _encodePushKey(subscription.getKey('auth')),
    );
  }

  Future<web.PushSubscription> _subscribeWebPush(
    web.PushManager pushManager,
    Uint8List applicationServerKey,
  ) {
    // Keep this as a direct pushManager.subscribe call; Dart web interop disallows tear-offs.
    return pushManager
        .subscribe(
          web.PushSubscriptionOptionsInit(
            userVisibleOnly: true,
            applicationServerKey: applicationServerKey.toJS,
          ),
        )
        .toDart;
  }

  Uint8List _decodeVapidPublicKey(String publicKey) {
    final normalized = publicKey.trim();
    if (normalized.isEmpty) {
      return Uint8List(0);
    }
    return Uint8List.fromList(
      base64Url.decode(base64Url.normalize(normalized)),
    );
  }

  String _encodePushKey(JSArrayBuffer? key) {
    if (key == null) {
      return '';
    }
    final bytes = Uint8List.view(key.toDart);
    return base64UrlEncode(bytes).replaceAll('=', '');
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

  Future<void> _unlockHtmlAudioElementsForIos() async {
    try {
      if (!_isAppleMobile()) {
        return;
      }
      final foreground = _foregroundElement ??= _createHtmlAudioElement(
        _assetUrl(_foregroundSoundAssetPath),
      );
      final message = _messageElement ??= _createHtmlAudioElement(
        _assetUrl(_messageSoundAssetPath),
      );
      await _primeHtmlAudioElement(foreground);
      await _primeHtmlAudioElement(message);
    } catch (error, stackTrace) {
      _logError('iOS Web 音频预热失败，请确认 init() 由用户点击触发且提示音资源存在', error, stackTrace);
    }
  }

  Future<void> _configurePlayers() async {
    try {
      await Future.wait<void>([
        _foregroundPlayer.setReleaseMode(ReleaseMode.stop),
        _messagePlayer.setReleaseMode(ReleaseMode.stop),
        _unlockPlayer.setReleaseMode(ReleaseMode.stop),
      ]);
    } catch (error, stackTrace) {
      _logError('配置音频播放器失败', error, stackTrace);
    }
  }

  Future<void> _playForegroundTick() async {
    try {
      _foregroundStopTimer?.cancel();
      if (await _playHtmlAudioElement(
        _foregroundElement,
        volume: _foregroundVolume,
        stopAfter: _foregroundSoundMaxDuration,
      )) {
        return;
      }
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

  Future<void> _playMessageSound() async {
    try {
      _messageStopTimer?.cancel();
      if (await _playHtmlAudioElement(
        _messageElement,
        volume: _messageVolume,
        stopAfter: _messageSoundMaxDuration,
      )) {
        return;
      }
      await _safeStop(_messagePlayer);
      await _messagePlayer.play(
        AssetSource(_messageSoundAssetPath),
        volume: _messageVolume,
        mode: PlayerMode.lowLatency,
      );

      _messageStopTimer = Timer(_messageSoundMaxDuration, () {
        unawaited(_safeStop(_messagePlayer));
      });
    } catch (error, stackTrace) {
      _logError('播放消息提示音失败', error, stackTrace);
    }
  }

  Future<void> _showBrowserNotification(
    DesktopMessageNotification notification,
  ) async {
    try {
      if (!_supportsNotification()) {
        return;
      }

      final permission = web.Notification.permission;
      _notificationPermission = permission;
      if (permission != 'granted') {
        return;
      }

      final browserNotification = web.Notification(
        notification.title,
        _buildNotificationOptions(notification),
      );
      browserNotification.onclick = ((web.Event event) {
        try {
          final payload = notification.payload.trim();
          if (payload.isNotEmpty) {
            web.window.postMessage(
              <String, Object>{
                'type': 'wk.notification.click',
                'payload': payload,
              }.jsify(),
              web.window.location.origin.toJS,
            );
          }
          web.window.focus();
          browserNotification.close();
        } catch (error, stackTrace) {
          _logError('处理系统通知点击事件失败', error, stackTrace);
        }
      }).toJS;
    } catch (error, stackTrace) {
      _logError('显示系统通知失败', error, stackTrace);
    }
  }

  web.NotificationOptions _buildNotificationOptions(
    DesktopMessageNotification notification,
  ) {
    final icon = _notificationIcon?.trim() ?? '';
    final tag = _notificationTagFor(notification);
    if (icon.isEmpty) {
      return web.NotificationOptions(
        body: notification.body,
        tag: tag,
        renotify: true,
        silent: false,
        requireInteraction: false,
        data: notification.payload.toJS,
      );
    }

    return web.NotificationOptions(
      body: notification.body,
      tag: tag,
      icon: icon,
      badge: 'icons/Icon-maskable-192.png',
      renotify: true,
      silent: false,
      requireInteraction: false,
      data: notification.payload.toJS,
    );
  }

  String _notificationTagFor(DesktopMessageNotification notification) {
    final identifier = notification.identifier.trim();
    if (identifier.isNotEmpty) {
      return identifier;
    }
    return _notificationTag;
  }

  void _bindVisibilityChangeListener() {
    if (_visibilityChangeListener == null) {
      try {
        _visibilityChangeListener = ((web.Event event) {
          if (isPageVisible()) {
            stopTitleBlink();
            _startVisibleHeartbeat();
            unawaited(_ensureWebPushSubscription());
          } else {
            _stopVisibleHeartbeat();
          }
          unawaited(_reportWebPushClientState());
        }).toJS;
        web.document.addEventListener(
          'visibilitychange',
          _visibilityChangeListener,
        );
      } catch (error, stackTrace) {
        _logError('绑定 visibilitychange 事件失败', error, stackTrace);
      }
    }

    if (_pageHideListener == null) {
      try {
        _pageHideListener = ((web.Event event) {
          unawaited(_reportWebPushClientState(visibilityOverride: 'unloaded'));
        }).toJS;
        web.window.addEventListener('pagehide', _pageHideListener);
      } catch (error, stackTrace) {
        _logError('绑定 pagehide 事件失败', error, stackTrace);
      }
    }

    if (isPageVisible()) {
      _startVisibleHeartbeat();
    }
  }

  void _startVisibleHeartbeat() {
    if (_visibleHeartbeatTimer?.isActive == true) {
      return;
    }
    _visibleHeartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!isPageVisible()) {
        _stopVisibleHeartbeat();
        return;
      }
      unawaited(_reportWebPushClientState(visibilityOverride: 'visible'));
    });
  }

  void _stopVisibleHeartbeat() {
    _visibleHeartbeatTimer?.cancel();
    _visibleHeartbeatTimer = null;
  }

  Future<void> _reportWebPushClientState({String? visibilityOverride}) async {
    try {
      final permission = _readNotificationPermission();
      if (permission != 'granted') {
        return;
      }
      final endpoint = await _currentWebPushEndpoint();
      if (endpoint.isEmpty) {
        return;
      }
      await WebPushApi.instance.updateWebPushClientState(
        WebPushClientState(
          endpoint: endpoint,
          visibility: visibilityOverride ?? _pageVisibilityForReport(),
          permission: permission,
          standalone: _isStandaloneDisplay(),
          userAgent: _userAgent(),
        ),
      );
    } catch (error, stackTrace) {
      _logError('上报 Web Push 客户端状态失败', error, stackTrace);
    }
  }

  Future<String> _currentWebPushEndpoint() async {
    final cachedEndpoint = _lastWebPushEndpoint?.trim() ?? '';
    if (cachedEndpoint.isNotEmpty) {
      return cachedEndpoint;
    }
    if (!_supportsServiceWorker() || !_supportsPush() || !_isSecureContext()) {
      return '';
    }
    final registration = await web.window.navigator.serviceWorker.ready.toDart;
    final subscription = await registration.pushManager
        .getSubscription()
        .toDart;
    final endpoint = subscription?.endpoint.trim() ?? '';
    if (endpoint.isNotEmpty) {
      _lastWebPushEndpoint = endpoint;
    }
    return endpoint;
  }

  String _pageVisibilityForReport() {
    try {
      final visibility = web.document.visibilityState.trim();
      return visibility.isEmpty ? 'unknown' : visibility;
    } catch (error, stackTrace) {
      _logError('读取页面状态用于 Web Push 上报失败', error, stackTrace);
      return 'unknown';
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

  bool _supportsServiceWorker() {
    try {
      return web.window.navigator.has('serviceWorker');
    } catch (error, stackTrace) {
      _logError('检测 Service Worker 支持失败', error, stackTrace);
      return false;
    }
  }

  bool _supportsPush() {
    try {
      return globalContext.has('PushManager');
    } catch (error, stackTrace) {
      _logError('检测 Push API 支持失败', error, stackTrace);
      return false;
    }
  }

  bool _isSecureContext() {
    try {
      final value = globalContext.getProperty('isSecureContext'.toJS);
      return value.dartify() == true;
    } catch (error, stackTrace) {
      _logError('检测安全上下文失败', error, stackTrace);
      return false;
    }
  }

  bool _isStandaloneDisplay() {
    try {
      final standalone = web.window.navigator.getProperty('standalone'.toJS);
      if (standalone.dartify() == true) {
        return true;
      }
      final mediaQuery = web.window.matchMedia('(display-mode: standalone)');
      return mediaQuery.matches;
    } catch (error, stackTrace) {
      _logError('检测 PWA standalone 模式失败', error, stackTrace);
      return false;
    }
  }

  String _userAgent() {
    try {
      return web.window.navigator.userAgent;
    } catch (error, stackTrace) {
      _logError('读取浏览器 userAgent 失败', error, stackTrace);
      return '';
    }
  }

  Future<void> _safeStop(AudioPlayer player) async {
    try {
      await player.stop();
    } catch (error, stackTrace) {
      _logError('停止音频失败', error, stackTrace);
    }
  }

  web.HTMLAudioElement _createHtmlAudioElement(String source) {
    final element = web.HTMLAudioElement()
      ..src = source
      ..preload = 'auto'
      ..muted = false
      ..volume = 1.0;
    return element;
  }

  Future<void> _primeHtmlAudioElement(web.HTMLAudioElement element) async {
    element.muted = true;
    element.volume = 0;
    try {
      await element.play().toDart;
    } finally {
      element.pause();
      _resetHtmlAudioElement(element);
      element.muted = false;
    }
  }

  Future<bool> _playHtmlAudioElement(
    web.HTMLAudioElement? element, {
    required double volume,
    required Duration stopAfter,
  }) async {
    if (element == null) {
      return false;
    }
    try {
      element.muted = false;
      element.volume = volume;
      _resetHtmlAudioElement(element);
      await element.play().toDart;
      Timer(stopAfter, () {
        try {
          element.pause();
          _resetHtmlAudioElement(element);
        } catch (_) {}
      });
      return true;
    } catch (error, stackTrace) {
      _logError('iOS Web HTMLAudioElement 播放提示音失败', error, stackTrace);
      return false;
    }
  }

  void _resetHtmlAudioElement(web.HTMLAudioElement element) {
    try {
      element.currentTime = 0;
    } catch (_) {}
  }

  void _releaseHtmlAudioElements() {
    _foregroundElement?.pause();
    _messageElement?.pause();
    _foregroundElement = null;
    _messageElement = null;
  }

  String _assetUrl(String assetPath) {
    final normalized = assetPath.trim().replaceAll(RegExp(r'^/+'), '');
    if (normalized.startsWith('assets/')) {
      return normalized;
    }
    return 'assets/assets/$normalized';
  }

  bool _isAppleMobile() {
    final ua = _userAgent().toLowerCase();
    return ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
  }

  double _normalizeVolume(double value) {
    return value.clamp(0.0, 1.0).toDouble();
  }

  void _logError(String message, Object error, StackTrace stackTrace) {
    debugPrint('$message: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
