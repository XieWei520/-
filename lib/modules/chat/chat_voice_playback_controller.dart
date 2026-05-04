import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:wukong_im_app/service/api/message_api.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_voice_content.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../wk_foundation/logging/app_logger.dart';
import 'chat_audio_session_bridge.dart';
import '../../wukong_base/utils/audio_record_manager.dart';
import 'chat_flame_message_runtime.dart';

enum ChatVoicePlaybackStatus { idle, loading, playing, paused, failed }

abstract class ChatVoiceReadReporter {
  Future<void> markVoiceRead(WKMsg message);
}

class ApiChatVoiceReadReporter implements ChatVoiceReadReporter {
  ApiChatVoiceReadReporter({MessageApi? messageApi})
    : _messageApi = messageApi ?? MessageApi.instance;

  final MessageApi _messageApi;

  @override
  Future<void> markVoiceRead(WKMsg message) {
    final messageId = message.messageID.trim();
    if (messageId.isEmpty) {
      return Future<void>.value();
    }
    return _messageApi.markVoiceRead(
      messageId: messageId,
      messageSeq: message.messageSeq,
      channelId: message.channelID,
      channelType: message.channelType,
    );
  }
}

@immutable
class ChatVoicePlaybackEntry {
  const ChatVoicePlaybackEntry({
    required this.messageId,
    required this.source,
    this.status = ChatVoicePlaybackStatus.idle,
    this.positionMs = 0,
    this.durationMs = 0,
    this.error,
  });

  final String messageId;
  final AudioPlaybackSource source;
  final ChatVoicePlaybackStatus status;
  final int positionMs;
  final int durationMs;
  final String? error;

  ChatVoicePlaybackEntry copyWith({
    AudioPlaybackSource? source,
    ChatVoicePlaybackStatus? status,
    int? positionMs,
    int? durationMs,
    String? error,
    bool clearError = false,
  }) {
    return ChatVoicePlaybackEntry(
      messageId: messageId,
      source: source ?? this.source,
      status: status ?? this.status,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

@immutable
class ChatVoicePlaybackState {
  ChatVoicePlaybackState({
    this.activeMessageId,
    Map<String, ChatVoicePlaybackEntry> entries =
        const <String, ChatVoicePlaybackEntry>{},
  }) : entries = UnmodifiableMapView<String, ChatVoicePlaybackEntry>(
         Map<String, ChatVoicePlaybackEntry>.from(entries),
       );

  final String? activeMessageId;
  final Map<String, ChatVoicePlaybackEntry> entries;

  ChatVoicePlaybackState copyWith({
    String? activeMessageId,
    bool clearActiveMessageId = false,
    Map<String, ChatVoicePlaybackEntry>? entries,
  }) {
    return ChatVoicePlaybackState(
      activeMessageId: clearActiveMessageId
          ? null
          : (activeMessageId ?? this.activeMessageId),
      entries: entries ?? this.entries,
    );
  }
}

class _FallbackPlaybackPlan {
  _FallbackPlaybackPlan({
    required this.primarySource,
    required this.fallbackSource,
  });

  final AudioPlaybackSource primarySource;
  final AudioPlaybackSource fallbackSource;
  bool hasRetried = false;
}

class ChatVoicePlaybackController extends ChangeNotifier {
  static const AppLogger _logger = AppLogger('chat/voice-playback');

  ChatVoicePlaybackController({
    AudioPlayManager? playManager,
    ChatVoiceReadReporter? voiceReadReporter,
    ChatFlameMessageRuntime? flameRuntime,
    ChatAudioSessionBridge? audioSessionBridge,
  }) : _playManager = playManager ?? AudioPlayManager(),
       _voiceReadReporter = voiceReadReporter ?? ApiChatVoiceReadReporter(),
       _flameRuntime = flameRuntime ?? ChatFlameMessageRuntime(),
       _audioSessionBridge =
           audioSessionBridge ?? createChatAudioSessionBridge() {
    _playbackSubscription = _playManager.playbackStream.listen(
      _onPlaybackUpdate,
    );
  }

  final AudioPlayManager _playManager;
  final ChatVoiceReadReporter _voiceReadReporter;
  final ChatFlameMessageRuntime _flameRuntime;
  final ChatAudioSessionBridge _audioSessionBridge;
  late final StreamSubscription<PlaybackUpdate> _playbackSubscription;
  Future<void> _toggleOperationQueue = Future<void>.value();
  final Set<String> _inFlightToggleMessageIds = <String>{};

  ChatVoicePlaybackState _state = ChatVoicePlaybackState();
  String? _pendingStopMessageId;
  final Map<String, _FallbackPlaybackPlan> _fallbackPlans =
      <String, _FallbackPlaybackPlan>{};
  bool _isPlaybackSessionActive = false;
  Future<void>? _playbackSessionDeactivation;
  bool _isDisposed = false;

  ChatVoicePlaybackState get state => _state;

  Future<void> toggle({
    required String messageId,
    required AudioPlaybackSource source,
    AudioPlaybackSource? fallbackSource,
    WKMsg? message,
  }) async {
    if (_isDisposed) {
      return;
    }
    final activeMessageId = _state.activeMessageId;
    final currentEntry = _state.entries[messageId];
    final isSameMessageLoading =
        activeMessageId == messageId &&
        currentEntry?.status == ChatVoicePlaybackStatus.loading;
    if (isSameMessageLoading || _inFlightToggleMessageIds.contains(messageId)) {
      return;
    }
    _inFlightToggleMessageIds.add(messageId);
    final operation = _toggleOperationQueue.then((_) {
      if (_isDisposed) {
        return Future<void>.value();
      }
      return _toggleInternal(
        messageId: messageId,
        source: source,
        fallbackSource: fallbackSource,
        message: message,
      );
    });
    _toggleOperationQueue = operation.catchError((_) {});
    return operation.whenComplete(() {
      _inFlightToggleMessageIds.remove(messageId);
    });
  }

  Future<void> _toggleInternal({
    required String messageId,
    required AudioPlaybackSource source,
    AudioPlaybackSource? fallbackSource,
    WKMsg? message,
  }) async {
    final activeMessageId = _state.activeMessageId;
    final currentEntry = _state.entries[messageId];

    if (activeMessageId == messageId) {
      final currentStatus =
          currentEntry?.status ?? ChatVoicePlaybackStatus.idle;
      if (currentStatus == ChatVoicePlaybackStatus.playing) {
        await _playManager.pause();
        return;
      }
      if (currentStatus == ChatVoicePlaybackStatus.paused) {
        await _activatePlaybackSessionIfNeeded();
        await _playManager.resume();
        return;
      }
    } else if (activeMessageId != null) {
      _pendingStopMessageId = activeMessageId;
      await _playManager.stop();
    }

    await _markVoiceReadIfNeeded(message);
    _registerFallbackPlan(
      messageId: messageId,
      primarySource: source,
      fallbackSource: fallbackSource,
    );

    _setEntry(
      messageId,
      (currentEntry ??
              ChatVoicePlaybackEntry(messageId: messageId, source: source))
          .copyWith(
            source: source,
            status: ChatVoicePlaybackStatus.loading,
            clearError: true,
          ),
      activeMessageId: messageId,
    );

    await _activatePlaybackSessionIfNeeded();
    await _playManager.play(source);
    _markFlameViewedBestEffort(message);
  }

  void _registerFallbackPlan({
    required String messageId,
    required AudioPlaybackSource primarySource,
    AudioPlaybackSource? fallbackSource,
  }) {
    if (fallbackSource == null || fallbackSource == primarySource) {
      _fallbackPlans.remove(messageId);
      return;
    }
    _fallbackPlans[messageId] = _FallbackPlaybackPlan(
      primarySource: primarySource,
      fallbackSource: fallbackSource,
    );
  }

  Future<void> _markVoiceReadIfNeeded(WKMsg? message) async {
    if (message == null || !_shouldMarkVoiceRead(message)) {
      return;
    }
    message.voiceStatus = 1;
    try {
      await _voiceReadReporter.markVoiceRead(message);
    } catch (_) {
      // Android updates local unread state even if the best-effort report fails.
    }
  }

  bool _shouldMarkVoiceRead(WKMsg message) {
    if (message.voiceStatus != 0) {
      return false;
    }
    final fromUid = message.fromUID.trim();
    if (fromUid.isEmpty) {
      return false;
    }
    final currentUid = WKIM.shared.options.uid?.trim() ?? '';
    return currentUid.isEmpty || fromUid != currentUid;
  }

  Future<void> _markFlameViewedIfNeeded(WKMsg? message) async {
    if (message == null || !isFlameMessage(message)) {
      return;
    }
    if (message.viewed == 1 || message.viewedAt > 0) {
      return;
    }
    await _flameRuntime.markViewed(
      message,
      ttlSecondsOverride: _resolveVoiceFlameTtlSeconds(message),
    );
  }

  void _markFlameViewedBestEffort(WKMsg? message) {
    final messageId = message?.messageID.trim() ?? '';
    unawaited(
      _markFlameViewedIfNeeded(message).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        _logger.error(
          'flame viewed persistence failed messageId=$messageId',
          error,
          stackTrace,
        );
        // Playback has already started; keep toggle resilient and non-blocking
        // when flame viewed persistence is slow or fails.
      }),
    );
  }

  int _resolveVoiceFlameTtlSeconds(WKMsg message) {
    final flameSecond = flameSecondsOf(message);
    if (flameSecond <= 0) {
      return flameSecond;
    }
    final content = message.messageContent;
    if (content is! WKVoiceContent) {
      return flameSecond;
    }
    return math.max(content.timeTrad, flameSecond);
  }

  @visibleForTesting
  void replaceState(ChatVoicePlaybackState nextState) {
    _state = nextState;
    notifyListeners();
  }

  void _onPlaybackUpdate(PlaybackUpdate update) {
    switch (update.type) {
      case PlaybackUpdateType.start:
      case PlaybackUpdateType.resume:
      case PlaybackUpdateType.progress:
        _applyPlayingUpdate(update);
        break;
      case PlaybackUpdateType.pause:
        _applyPauseUpdate(update);
        break;
      case PlaybackUpdateType.stop:
        _applyStopUpdate(update);
        break;
      case PlaybackUpdateType.error:
        _applyErrorUpdate(update.error);
        break;
      case PlaybackUpdateType.seek:
        _applySeekUpdate(update);
        break;
    }
  }

  void _applyPlayingUpdate(PlaybackUpdate update) {
    final messageId = _state.activeMessageId;
    if (messageId == null) {
      return;
    }
    final current = _state.entries[messageId];
    if (current == null) {
      return;
    }
    if (!_isUpdateForEntry(update, current)) {
      return;
    }

    _setEntry(
      messageId,
      current.copyWith(
        status: ChatVoicePlaybackStatus.playing,
        positionMs: update.position ?? current.positionMs,
        durationMs: update.duration ?? current.durationMs,
        clearError: true,
      ),
      activeMessageId: messageId,
    );
  }

  void _applyPauseUpdate(PlaybackUpdate update) {
    final messageId = _state.activeMessageId;
    if (messageId == null) {
      return;
    }
    final current = _state.entries[messageId];
    if (current == null) {
      return;
    }
    if (!_isUpdateForEntry(update, current)) {
      return;
    }

    _setEntry(
      messageId,
      current.copyWith(
        status: ChatVoicePlaybackStatus.paused,
        positionMs: update.position ?? current.positionMs,
        durationMs: update.duration ?? current.durationMs,
      ),
      activeMessageId: messageId,
    );
  }

  void _applySeekUpdate(PlaybackUpdate update) {
    final messageId = _state.activeMessageId;
    if (messageId == null) {
      return;
    }
    final current = _state.entries[messageId];
    if (current == null) {
      return;
    }
    if (!_isUpdateForEntry(update, current)) {
      return;
    }

    _setEntry(
      messageId,
      current.copyWith(
        positionMs: update.position ?? current.positionMs,
        durationMs: update.duration ?? current.durationMs,
      ),
    );
  }

  void _applyStopUpdate(PlaybackUpdate update) {
    final messageId = _resolveTerminalEventOwner();
    if (messageId == null) {
      return;
    }
    _fallbackPlans.remove(messageId);
    final current = _state.entries[messageId];
    if (current == null) {
      if (_pendingStopMessageId == messageId) {
        _pendingStopMessageId = null;
      }
      return;
    }
    if (!_isUpdateForEntry(update, current)) {
      if (_pendingStopMessageId == messageId) {
        _pendingStopMessageId = null;
      }
      return;
    }
    _pendingStopMessageId = null;

    _setEntry(
      messageId,
      current.copyWith(
        status: ChatVoicePlaybackStatus.idle,
        positionMs: 0,
        durationMs: 0,
        clearError: true,
      ),
      clearActiveMessageId: _state.activeMessageId == messageId,
    );
    _deactivatePlaybackSessionIfIdle();
  }

  void _applyErrorUpdate(String? error) {
    final messageId = _resolveTerminalEventOwner();
    if (messageId == null) {
      return;
    }
    final current = _state.entries[messageId];
    if (current == null) {
      return;
    }
    final shouldAttemptFallback =
        _pendingStopMessageId == null &&
        current.status == ChatVoicePlaybackStatus.loading;
    if (shouldAttemptFallback) {
      final fallbackPlan = _fallbackPlans[messageId];
      final hasUnusedFallback =
          fallbackPlan != null &&
          !fallbackPlan.hasRetried &&
          fallbackPlan.primarySource == current.source;
      if (hasUnusedFallback) {
        fallbackPlan.hasRetried = true;
        _setEntry(
          messageId,
          current.copyWith(
            source: fallbackPlan.fallbackSource,
            status: ChatVoicePlaybackStatus.loading,
            clearError: true,
          ),
          activeMessageId: messageId,
        );
        unawaited(_playManager.play(fallbackPlan.fallbackSource));
        return;
      }
    }
    _fallbackPlans.remove(messageId);

    _setEntry(
      messageId,
      current.copyWith(status: ChatVoicePlaybackStatus.failed, error: error),
      clearActiveMessageId: _state.activeMessageId == messageId,
    );
    _deactivatePlaybackSessionIfIdle();
  }

  String? _resolveTerminalEventOwner() {
    return _pendingStopMessageId ?? _state.activeMessageId;
  }

  bool _isUpdateForEntry(PlaybackUpdate update, ChatVoicePlaybackEntry entry) {
    final source = update.source;
    if (source == null) {
      return true;
    }
    return source == entry.source;
  }

  void _setEntry(
    String messageId,
    ChatVoicePlaybackEntry entry, {
    String? activeMessageId,
    bool clearActiveMessageId = false,
  }) {
    final nextEntries = <String, ChatVoicePlaybackEntry>{
      ..._state.entries,
      messageId: entry,
    };
    _state = _state.copyWith(
      entries: nextEntries,
      activeMessageId: activeMessageId,
      clearActiveMessageId: clearActiveMessageId,
    );
    notifyListeners();
  }

  bool _hasActivePlaybackDemand() {
    final activeMessageId = _state.activeMessageId;
    if (activeMessageId == null) {
      return false;
    }
    final activeEntry = _state.entries[activeMessageId];
    if (activeEntry == null) {
      return false;
    }
    return activeEntry.status == ChatVoicePlaybackStatus.loading ||
        activeEntry.status == ChatVoicePlaybackStatus.playing ||
        activeEntry.status == ChatVoicePlaybackStatus.paused;
  }

  void _deactivatePlaybackSessionIfIdle() {
    if (_hasActivePlaybackDemand()) {
      return;
    }
    unawaited(_deactivatePlaybackSessionIfNeeded());
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _playbackSubscription.cancel();
    unawaited(_playManager.stop());
    unawaited(_deactivatePlaybackSessionIfNeeded());
    super.dispose();
  }

  Future<void> _activatePlaybackSessionIfNeeded() async {
    final pendingDeactivation = _playbackSessionDeactivation;
    if (pendingDeactivation != null) {
      await pendingDeactivation;
    }
    if (_isPlaybackSessionActive) {
      return;
    }
    try {
      await _audioSessionBridge.activate(ChatAudioSessionUseCase.playback);
      _isPlaybackSessionActive = true;
    } catch (_) {
      // Keep playback flow resilient if bridge integration fails unexpectedly.
      return;
    }
    try {
      await _audioSessionBridge.setSpeakerphone(true);
    } catch (_) {
      // Keep playback flow resilient if route alignment fails unexpectedly.
    }
  }

  Future<void> _deactivatePlaybackSessionIfNeeded() async {
    final pendingDeactivation = _playbackSessionDeactivation;
    if (pendingDeactivation != null) {
      await pendingDeactivation;
      return;
    }
    if (!_isPlaybackSessionActive) {
      return;
    }
    final deactivation = _runPlaybackSessionDeactivation();
    _playbackSessionDeactivation = deactivation;
    await deactivation;
  }

  Future<void> _runPlaybackSessionDeactivation() async {
    try {
      await _audioSessionBridge.deactivate();
    } catch (_) {
      // Keep playback flow resilient if bridge integration fails unexpectedly.
    } finally {
      _isPlaybackSessionActive = false;
      _playbackSessionDeactivation = null;
    }
  }

  @visibleForTesting
  void debugHandlePlaybackUpdate(PlaybackUpdate update) {
    _onPlaybackUpdate(update);
  }

  @visibleForTesting
  void debugSetPendingStopMessageId(String? messageId) {
    _pendingStopMessageId = messageId;
  }
}
