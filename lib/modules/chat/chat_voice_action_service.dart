import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:wukongimfluttersdk/model/wk_voice_content.dart';

import 'chat_audio_session_bridge.dart';
import 'chat_voice_feedback_service.dart';
import '../../wukong_base/utils/audio_record_manager.dart';

class ChatVoiceContentFactory {
  WKVoiceContent buildVoiceContent({
    required String filePath,
    required int durationMs,
  }) {
    final seconds = ((durationMs <= 0 ? 1000 : durationMs) / 1000).ceil();
    final content = WKVoiceContent(seconds.clamp(1, 60));
    content.localPath = filePath;
    return content;
  }
}

enum ChatVoiceRecordingPhase {
  idle,
  permissionDenied,
  recording,
  cancelCandidate,
  stopping,
  tooShort,
  sendReady,
  sendFailed,
}

class ChatVoiceRecordingState {
  static const Object _unsetErrorMessage = Object();
  static const Object _unsetCountdownSeconds = Object();

  const ChatVoiceRecordingState({
    required this.phase,
    this.duration = Duration.zero,
    this.amplitudeLevel = 0.0,
    this.waveformSamples = const <double>[],
    this.errorMessage,
    this.countdownSeconds,
  });

  const ChatVoiceRecordingState.idle()
    : this(phase: ChatVoiceRecordingPhase.idle);

  final ChatVoiceRecordingPhase phase;
  final Duration duration;
  final double amplitudeLevel;
  final List<double> waveformSamples;
  final String? errorMessage;
  final int? countdownSeconds;

  bool get isVisible =>
      phase == ChatVoiceRecordingPhase.recording ||
      phase == ChatVoiceRecordingPhase.cancelCandidate ||
      phase == ChatVoiceRecordingPhase.stopping ||
      phase == ChatVoiceRecordingPhase.tooShort;

  ChatVoiceRecordingState copyWith({
    ChatVoiceRecordingPhase? phase,
    Duration? duration,
    double? amplitudeLevel,
    List<double>? waveformSamples,
    Object? errorMessage = _unsetErrorMessage,
    Object? countdownSeconds = _unsetCountdownSeconds,
  }) {
    return ChatVoiceRecordingState(
      phase: phase ?? this.phase,
      duration: duration ?? this.duration,
      amplitudeLevel: amplitudeLevel ?? this.amplitudeLevel,
      waveformSamples: waveformSamples ?? this.waveformSamples,
      errorMessage: identical(errorMessage, _unsetErrorMessage)
          ? this.errorMessage
          : errorMessage as String?,
      countdownSeconds: identical(countdownSeconds, _unsetCountdownSeconds)
          ? this.countdownSeconds
          : countdownSeconds as int?,
    );
  }
}

enum ChatVoiceDiscardReason { cancelled, tooShort, permissionDenied }

sealed class ChatVoiceStopResult {
  const ChatVoiceStopResult();
}

class ChatVoiceReadyResult extends ChatVoiceStopResult {
  const ChatVoiceReadyResult({required this.content, required this.duration});

  final WKVoiceContent content;
  final Duration duration;
}

class ChatVoiceDiscardedResult extends ChatVoiceStopResult {
  const ChatVoiceDiscardedResult(this.reason);

  final ChatVoiceDiscardReason reason;
}

class ChatVoiceStopFailure extends ChatVoiceStopResult {
  const ChatVoiceStopFailure(this.message);

  final String message;
}

abstract class ChatVoiceActionService {
  ValueListenable<ChatVoiceRecordingState> get recordingStateListenable;

  Future<bool> startRecording();

  void setCancelCandidate(bool value);

  Future<ChatVoiceStopResult> stopRecording({required bool shouldSend});

  Future<void> cancelRecording();

  void dispose();
}

class PlatformChatVoiceActionService implements ChatVoiceActionService {
  PlatformChatVoiceActionService({
    AudioRecordManager? recordManager,
    ChatVoiceContentFactory? contentFactory,
    ChatVoiceFeedbackService? feedbackService,
    ChatAudioSessionBridge? audioSessionBridge,
  }) : _recordManager = recordManager ?? AudioRecordManager(),
       _contentFactory = contentFactory ?? ChatVoiceContentFactory(),
       _feedbackService = feedbackService ?? ChatVoiceFeedbackService.noop(),
       _audioSessionBridge =
           audioSessionBridge ?? createChatAudioSessionBridge() {
    _recordingSubscription = _recordManager.recordingStream.listen(
      _handleRecordingUpdate,
    );
  }

  static const int _maxWaveformSamples = 24;
  static const int _maxDurationSeconds = 60;
  static const int _countdownWarningSeconds = 10;
  static const Duration _minSendDuration = Duration(seconds: 1);

  final AudioRecordManager _recordManager;
  final ChatVoiceContentFactory _contentFactory;
  final ChatVoiceFeedbackService _feedbackService;
  final ChatAudioSessionBridge _audioSessionBridge;
  final ValueNotifier<ChatVoiceRecordingState> _recordingStateNotifier =
      ValueNotifier<ChatVoiceRecordingState>(
        const ChatVoiceRecordingState.idle(),
      );
  final List<double> _waveformRingBuffer = <double>[];

  StreamSubscription<RecordingUpdate>? _recordingSubscription;
  String? _lastRecordingError;
  bool _isStartingRecording = false;
  Completer<void>? _startRecordingCompleter;
  bool _isRecordingSessionActive = false;
  Future<void>? _recordingSessionDeactivation;
  bool _pendingCancelCandidate = false;
  RecordingUpdate? _pendingStoppedUpdate;
  Future<void> _terminalOperationQueue = Future<void>.value();
  bool _isDisposed = false;

  @override
  ValueListenable<ChatVoiceRecordingState> get recordingStateListenable =>
      _recordingStateNotifier;

  @override
  Future<bool> startRecording() async {
    if (_isDisposed) {
      return false;
    }
    final currentPhase = _recordingStateNotifier.value.phase;
    if (_isStartingRecording) {
      return false;
    }
    if (currentPhase == ChatVoiceRecordingPhase.recording ||
        currentPhase == ChatVoiceRecordingPhase.cancelCandidate) {
      return false;
    }

    _clearWaveform();
    _lastRecordingError = null;
    _pendingCancelCandidate = false;
    _pendingStoppedUpdate = null;
    _isStartingRecording = true;
    final startCompleter = Completer<void>();
    _startRecordingCompleter = startCompleter;
    try {
      await _safeActivate(ChatAudioSessionUseCase.record);
      _recordManager.setConfig(
        const RecordingConfig(
          quality: RecordingQuality.medium,
          maxDuration: 60,
          minDuration: 1,
        ),
      );

      var started = false;
      try {
        started = await _recordManager.start();
      } catch (error) {
        _lastRecordingError = error.toString();
      } finally {
        _isStartingRecording = false;
      }

      if (!started) {
        await _safeDeactivate();
        if (_lastRecordingError == null) {
          await Future<void>.delayed(Duration.zero);
        }
        final errorMessage = _lastRecordingError;
        final permissionDenied = _looksLikePermissionDenied(errorMessage);
        final failedMessage = errorMessage?.trim().isNotEmpty == true
            ? errorMessage!.trim()
            : (_recordManager.state == RecordingState.recording ||
                      _recordManager.state == RecordingState.paused
                  ? 'recorder is busy'
                  : 'recording start failed');
        _setState(
          ChatVoiceRecordingState(
            phase: permissionDenied
                ? ChatVoiceRecordingPhase.permissionDenied
                : ChatVoiceRecordingPhase.sendFailed,
            errorMessage: permissionDenied
                ? (failedMessage.isNotEmpty
                      ? failedMessage
                      : 'microphone permission denied')
                : failedMessage,
          ),
        );
        if (!permissionDenied) {
          _emitFeedback(ChatVoiceFeedbackEvent.sendFailed);
        }
        _pendingCancelCandidate = false;
        return false;
      }

      _setState(
        ChatVoiceRecordingState(
          phase: _pendingCancelCandidate
              ? ChatVoiceRecordingPhase.cancelCandidate
              : ChatVoiceRecordingPhase.recording,
        ),
      );
      _emitFeedback(ChatVoiceFeedbackEvent.recordStarted);
      return true;
    } finally {
      if (identical(_startRecordingCompleter, startCompleter)) {
        _startRecordingCompleter = null;
      }
      if (!startCompleter.isCompleted) {
        startCompleter.complete();
      }
    }
  }

  @override
  void setCancelCandidate(bool value) {
    if (_isDisposed) {
      return;
    }
    if (_isStartingRecording) {
      _pendingCancelCandidate = value;
      return;
    }

    final current = _recordingStateNotifier.value;
    if (current.phase != ChatVoiceRecordingPhase.recording &&
        current.phase != ChatVoiceRecordingPhase.cancelCandidate) {
      return;
    }
    _pendingCancelCandidate = value;

    final nextPhase = value
        ? ChatVoiceRecordingPhase.cancelCandidate
        : ChatVoiceRecordingPhase.recording;
    if (current.phase == nextPhase) {
      return;
    }
    _setState(current.copyWith(phase: nextPhase));
  }

  @override
  Future<ChatVoiceStopResult> stopRecording({required bool shouldSend}) async {
    return _enqueueTerminalOperation<ChatVoiceStopResult>(
      () => _stopRecordingInternal(shouldSend: shouldSend),
    );
  }

  Future<ChatVoiceStopResult> _stopRecordingInternal({
    required bool shouldSend,
  }) async {
    await _awaitPendingStart();
    if (_isDisposed) {
      return const ChatVoiceStopFailure('recording service is disposed');
    }

    if (!shouldSend) {
      await _recordManager.cancel();
      _clearWaveform();
      _pendingCancelCandidate = false;
      _pendingStoppedUpdate = null;
      _setState(const ChatVoiceRecordingState.idle());
      await _safeDeactivate();
      return const ChatVoiceDiscardedResult(ChatVoiceDiscardReason.cancelled);
    }

    final current = _recordingStateNotifier.value;
    if (current.phase == ChatVoiceRecordingPhase.permissionDenied) {
      await _safeDeactivate();
      return const ChatVoiceDiscardedResult(
        ChatVoiceDiscardReason.permissionDenied,
      );
    }

    _setState(
      current.copyWith(
        phase: ChatVoiceRecordingPhase.stopping,
        errorMessage: null,
        countdownSeconds: null,
      ),
    );

    final result =
        await _consumePendingStopUpdateResult() ?? await _recordManager.stop();
    _pendingStoppedUpdate = null;
    final filePath = result.filePath.trim();

    if (filePath.isEmpty || result.error != null) {
      final message = result.error ?? 'recording stop failed';
      _setState(
        _recordingStateNotifier.value.copyWith(
          phase: ChatVoiceRecordingPhase.sendFailed,
          errorMessage: message,
          countdownSeconds: null,
        ),
      );
      _emitFeedback(ChatVoiceFeedbackEvent.sendFailed);
      await _safeDeactivate();
      return ChatVoiceStopFailure(message);
    }

    final duration = Duration(milliseconds: result.duration);
    if (duration < _minSendDuration) {
      _setState(
        _recordingStateNotifier.value.copyWith(
          phase: ChatVoiceRecordingPhase.tooShort,
          duration: duration,
          errorMessage: null,
          countdownSeconds: null,
        ),
      );
      _emitFeedback(ChatVoiceFeedbackEvent.tooShort);
      await _safeDeactivate();
      return const ChatVoiceDiscardedResult(ChatVoiceDiscardReason.tooShort);
    }

    final content = _contentFactory.buildVoiceContent(
      filePath: filePath,
      durationMs: result.duration,
    );
    _setState(
      _recordingStateNotifier.value.copyWith(
        phase: ChatVoiceRecordingPhase.sendReady,
        duration: duration,
        errorMessage: null,
        countdownSeconds: null,
      ),
    );
    _emitFeedback(ChatVoiceFeedbackEvent.sendReady);
    await _safeDeactivate();
    return ChatVoiceReadyResult(content: content, duration: duration);
  }

  @override
  Future<void> cancelRecording() async {
    return _enqueueTerminalOperation<void>(_cancelRecordingInternal);
  }

  Future<void> _cancelRecordingInternal() async {
    await _awaitPendingStart();
    if (_isDisposed || !_hasLiveRecordingOperation()) {
      return;
    }
    await _recordManager.cancel();
    _clearWaveform();
    _pendingCancelCandidate = false;
    _pendingStoppedUpdate = null;
    _setState(const ChatVoiceRecordingState.idle());
    await _safeDeactivate();
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;

    unawaited(_recordingSubscription?.cancel());
    _recordingSubscription = null;

    if (_recordManager.state == RecordingState.recording ||
        _recordManager.state == RecordingState.paused) {
      unawaited(_recordManager.cancel());
    }
    unawaited(_safeDeactivate());

    _recordingStateNotifier.dispose();
  }

  void _handleRecordingUpdate(RecordingUpdate update) {
    if (_isDisposed) {
      return;
    }

    switch (update.type) {
      case RecordingUpdateType.start:
      case RecordingUpdateType.resume:
        final elapsedSeconds = update.duration ?? 0;
        final shouldCancel = _pendingCancelCandidate;
        _setState(
          ChatVoiceRecordingState(
            phase: shouldCancel
                ? ChatVoiceRecordingPhase.cancelCandidate
                : ChatVoiceRecordingPhase.recording,
            duration: Duration(seconds: elapsedSeconds),
            amplitudeLevel: 0.0,
            waveformSamples: List<double>.unmodifiable(_waveformRingBuffer),
            countdownSeconds: _resolveCountdownSeconds(elapsedSeconds),
          ),
        );
        return;
      case RecordingUpdateType.progress:
        final current = _recordingStateNotifier.value;
        if (current.phase != ChatVoiceRecordingPhase.recording &&
            current.phase != ChatVoiceRecordingPhase.cancelCandidate) {
          return;
        }
        final elapsedSeconds = update.duration ?? 0;
        final amplitude = _normalizeAmplitude(update.amplitude);
        final waveformSamples = _appendWaveformSample(amplitude);
        _setState(
          current.copyWith(
            duration: Duration(seconds: elapsedSeconds),
            amplitudeLevel: amplitude,
            waveformSamples: waveformSamples,
            errorMessage: null,
            countdownSeconds: _resolveCountdownSeconds(elapsedSeconds),
          ),
        );
        return;
      case RecordingUpdateType.error:
        _lastRecordingError = update.error;
        final current = _recordingStateNotifier.value;
        if (current.phase == ChatVoiceRecordingPhase.stopping ||
            current.phase == ChatVoiceRecordingPhase.permissionDenied) {
          return;
        }
        if (_looksLikePermissionDenied(update.error) &&
            (_isStartingRecording ||
                current.phase == ChatVoiceRecordingPhase.sendFailed ||
                current.phase == ChatVoiceRecordingPhase.recording ||
                current.phase == ChatVoiceRecordingPhase.cancelCandidate)) {
          _setState(
            current.copyWith(
              phase: ChatVoiceRecordingPhase.permissionDenied,
              errorMessage: update.error ?? 'microphone permission denied',
              countdownSeconds: null,
            ),
          );
          unawaited(_safeDeactivate());
          return;
        }
        if (current.phase == ChatVoiceRecordingPhase.idle) {
          return;
        }
        if (current.phase != ChatVoiceRecordingPhase.sendFailed) {
          _emitFeedback(ChatVoiceFeedbackEvent.sendFailed);
        }
        _setState(
          current.copyWith(
            phase: ChatVoiceRecordingPhase.sendFailed,
            errorMessage: update.error ?? 'recording failed',
            countdownSeconds: null,
          ),
        );
        unawaited(_safeDeactivate());
        return;
      case RecordingUpdateType.cancel:
        _clearWaveform();
        _pendingCancelCandidate = false;
        _pendingStoppedUpdate = null;
        if (_recordingStateNotifier.value.phase !=
            ChatVoiceRecordingPhase.tooShort) {
          _setState(const ChatVoiceRecordingState.idle());
        }
        unawaited(_safeDeactivate());
        return;
      case RecordingUpdateType.pause:
        return;
      case RecordingUpdateType.stop:
        _pendingStoppedUpdate = update;
        return;
    }
  }

  void _setState(ChatVoiceRecordingState nextState) {
    if (_isDisposed) {
      return;
    }
    _recordingStateNotifier.value = nextState;
  }

  void _clearWaveform() {
    _waveformRingBuffer.clear();
  }

  List<double> _appendWaveformSample(double amplitude) {
    _waveformRingBuffer.add(amplitude);
    while (_waveformRingBuffer.length > _maxWaveformSamples) {
      _waveformRingBuffer.removeAt(0);
    }
    return List<double>.unmodifiable(_waveformRingBuffer);
  }

  double _normalizeAmplitude(double? value) {
    final raw = value ?? 0.0;
    if (raw.isNaN || raw.isInfinite) {
      return 0.0;
    }
    if (raw < 0) {
      return 0.0;
    }
    if (raw > 1) {
      return 1.0;
    }
    return raw;
  }

  bool _looksLikePermissionDenied(String? message) {
    if (message == null) {
      return false;
    }
    final normalized = message.toLowerCase();
    return normalized.contains('permission') && normalized.contains('denied');
  }

  void _emitFeedback(ChatVoiceFeedbackEvent event) {
    final feedbackTask = Future<void>.sync(
      () => _feedbackService.handle(event),
    ).catchError((Object error, StackTrace stackTrace) {});
    unawaited(feedbackTask);
  }

  Future<void> _awaitPendingStart() async {
    final startCompleter = _startRecordingCompleter;
    if (startCompleter == null) {
      return;
    }
    await startCompleter.future;
  }

  Future<T> _enqueueTerminalOperation<T>(Future<T> Function() operation) {
    final next = _terminalOperationQueue.then((_) => operation());
    _terminalOperationQueue = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return next;
  }

  bool _hasLiveRecordingOperation() {
    if (_recordManager.state == RecordingState.recording ||
        _recordManager.state == RecordingState.paused) {
      return true;
    }
    final phase = _recordingStateNotifier.value.phase;
    return phase == ChatVoiceRecordingPhase.recording ||
        phase == ChatVoiceRecordingPhase.cancelCandidate ||
        phase == ChatVoiceRecordingPhase.stopping;
  }

  Future<RecordingResult?> _consumePendingStopUpdateResult() async {
    final pendingStop = _pendingStoppedUpdate;
    if (pendingStop == null) {
      return null;
    }
    if (_recordManager.state == RecordingState.recording ||
        _recordManager.state == RecordingState.paused) {
      return null;
    }

    _pendingStoppedUpdate = null;
    final filePath = pendingStop.filePath?.trim() ?? '';
    final fileExists = filePath.isNotEmpty && await File(filePath).exists();
    final fileSize = fileExists ? await File(filePath).length() : 0;
    final pathError = filePath.isEmpty
        ? 'Recording file path unavailable'
        : (!fileExists || fileSize <= 0)
        ? 'Recording file unavailable'
        : null;
    return RecordingResult(
      filePath: filePath,
      duration: (pendingStop.duration ?? 0) * 1000,
      fileSize: fileSize,
      error: pendingStop.error ?? pathError,
    );
  }

  Future<void> _safeActivate(ChatAudioSessionUseCase useCase) async {
    final pendingDeactivation = _recordingSessionDeactivation;
    if (pendingDeactivation != null) {
      await pendingDeactivation;
    }
    if (_isRecordingSessionActive) {
      return;
    }
    try {
      await _audioSessionBridge.activate(useCase);
      _isRecordingSessionActive = true;
    } catch (_) {
      // Keep recording flow resilient if bridge integration fails unexpectedly.
    }
  }

  Future<void> _safeDeactivate() async {
    final pendingDeactivation = _recordingSessionDeactivation;
    if (pendingDeactivation != null) {
      await pendingDeactivation;
      return;
    }
    if (!_isRecordingSessionActive) {
      return;
    }
    final deactivation = _runRecordingSessionDeactivation();
    _recordingSessionDeactivation = deactivation;
    await deactivation;
  }

  Future<void> _runRecordingSessionDeactivation() async {
    try {
      await _audioSessionBridge.deactivate();
    } catch (_) {
      // Keep recording flow resilient if bridge integration fails unexpectedly.
    } finally {
      _isRecordingSessionActive = false;
      _recordingSessionDeactivation = null;
    }
  }

  @visibleForTesting
  void debugHandleRecordingUpdate(RecordingUpdate update) {
    _handleRecordingUpdate(update);
  }

  int? _resolveCountdownSeconds(int elapsedSeconds) {
    final remainingSeconds = _maxDurationSeconds - elapsedSeconds;
    if (remainingSeconds <= 0 || remainingSeconds > _countdownWarningSeconds) {
      return null;
    }
    return remainingSeconds;
  }
}
