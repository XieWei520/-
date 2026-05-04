// Native audio recording/playback implementation.
import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart' as audioplayers;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

/// Recording state enum
enum RecordingState { idle, recording, paused, stopped }

/// Recording quality enum
enum RecordingQuality {
  low, // 24kbps
  medium, // 32kbps
  high, // 48kbps
}

/// Recording configuration
class RecordingConfig {
  final RecordingQuality quality;
  final int maxDuration; // seconds, 0 = unlimited
  final int minDuration; // seconds

  const RecordingConfig({
    this.quality = RecordingQuality.medium,
    this.maxDuration = 60,
    this.minDuration = 1,
  });

  int get sampleRate {
    switch (quality) {
      case RecordingQuality.low:
        return 12000;
      case RecordingQuality.medium:
        return 16000;
      case RecordingQuality.high:
        return 24000;
    }
  }

  int get bitRate {
    switch (quality) {
      case RecordingQuality.low:
        return 24000;
      case RecordingQuality.medium:
        return 32000;
      case RecordingQuality.high:
        return 48000;
    }
  }
}

/// Recording result
class RecordingResult {
  final String filePath;
  final int duration; // milliseconds
  final int fileSize; // bytes
  final String? error;

  RecordingResult({
    required this.filePath,
    required this.duration,
    required this.fileSize,
    this.error,
  });

  bool get isValid => error == null && duration > 0;
}

typedef RequestMicrophonePermission = Future<bool> Function();
typedef BuildRecordingPath = Future<String> Function();
typedef AudioPlaybackRuntimeFactory = AudioPlaybackRuntime Function();

enum AudioPlaybackSourceKind { file, network }

class AudioPlaybackSource {
  const AudioPlaybackSource._({required this.kind, required this.value});

  const AudioPlaybackSource.file(String filePath)
    : this._(kind: AudioPlaybackSourceKind.file, value: filePath);

  const AudioPlaybackSource.network(String url)
    : this._(kind: AudioPlaybackSourceKind.network, value: url);

  final AudioPlaybackSourceKind kind;
  final String value;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is AudioPlaybackSource &&
        other.kind == kind &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(kind, value);
}

/// Recorder runtime abstraction for testability.
abstract class AudioRecorderRuntime {
  Future<void> start({required String path, required RecordingConfig config});
  Future<void> pause();
  Future<void> resume();
  Future<String?> stop();
  Future<void> cancel();
  Future<double> amplitude();
  Future<void> dispose();
}

/// Player runtime abstraction for testability.
abstract class AudioPlaybackRuntime {
  Future<void> setSource(AudioPlaybackSource source);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<Duration> position();
  Future<Duration> durationValue();
  Future<bool> isPlaying();
  Future<void> dispose();
}

enum AudioPlaybackBackend { videoPlayer, audioPlayer }

AudioPlaybackBackend defaultAudioPlaybackBackend() {
  // `video_player` does not provide a Windows implementation in this app, while
  // `audioplayers_windows` is present in the dependency graph.
  if (Platform.isWindows) {
    return AudioPlaybackBackend.audioPlayer;
  }
  return AudioPlaybackBackend.videoPlayer;
}

AudioPlaybackRuntime createDefaultAudioPlaybackRuntime() {
  switch (defaultAudioPlaybackBackend()) {
    case AudioPlaybackBackend.audioPlayer:
      return _AudioPlayerPlaybackRuntime();
    case AudioPlaybackBackend.videoPlayer:
      return _VideoPlayerAudioPlaybackRuntime();
  }
}

/// Audio recording manager
class AudioRecordManager {
  static final AudioRecordManager _instance = AudioRecordManager._internal();
  factory AudioRecordManager() => _instance;

  AudioRecordManager._internal()
    : _recorderRuntime = _RecordAudioRecorderRuntime(),
      _requestMicrophonePermission = _defaultRequestMicrophonePermission,
      _buildRecordingPath = _defaultBuildRecordingPath,
      _progressInterval = const Duration(milliseconds: 200);

  AudioRecordManager._({
    required AudioRecorderRuntime recorderRuntime,
    required RequestMicrophonePermission requestMicrophonePermission,
    required BuildRecordingPath buildRecordingPath,
    required Duration progressInterval,
  }) : _recorderRuntime = recorderRuntime,
       _requestMicrophonePermission = requestMicrophonePermission,
       _buildRecordingPath = buildRecordingPath,
       _progressInterval = progressInterval;

  factory AudioRecordManager.test({
    required AudioRecorderRuntime recorderRuntime,
    required RequestMicrophonePermission requestMicrophonePermission,
    required BuildRecordingPath buildRecordingPath,
    Duration progressInterval = const Duration(milliseconds: 100),
  }) {
    return AudioRecordManager._(
      recorderRuntime: recorderRuntime,
      requestMicrophonePermission: requestMicrophonePermission,
      buildRecordingPath: buildRecordingPath,
      progressInterval: progressInterval,
    );
  }

  final AudioRecorderRuntime _recorderRuntime;
  final RequestMicrophonePermission _requestMicrophonePermission;
  final BuildRecordingPath _buildRecordingPath;
  final Duration _progressInterval;

  RecordingState _state = RecordingState.idle;
  RecordingConfig _config = const RecordingConfig();
  Timer? _durationTimer;
  Duration _elapsed = Duration.zero;
  Stopwatch? _stopwatch;
  String? _activeRecordingPath;
  double _lastAmplitude = 0.0;
  bool _progressInFlight = false;
  Future<RecordingResult>? _stopInFlight;

  final _recordingController = StreamController<RecordingUpdate>.broadcast();

  Stream<RecordingUpdate> get recordingStream => _recordingController.stream;
  RecordingState get state => _state;
  int get currentDuration => _effectiveElapsed().inSeconds;

  void setConfig(RecordingConfig config) {
    _config = config;
  }

  Future<bool> start() async {
    if (_state == RecordingState.recording) {
      return false;
    }

    try {
      final granted = await _requestMicrophonePermission();
      if (!granted) {
        _state = RecordingState.idle;
        _notifyUpdate(
          RecordingUpdate(
            type: RecordingUpdateType.error,
            error: 'microphone permission denied',
          ),
        );
        return false;
      }

      final outputPath = await _buildRecordingPath();
      await File(outputPath).parent.create(recursive: true);
      await _recorderRuntime.start(path: outputPath, config: _config);

      _activeRecordingPath = outputPath;
      _elapsed = Duration.zero;
      _lastAmplitude = 0.0;
      _stopwatch = Stopwatch()..start();
      _state = RecordingState.recording;
      _startTimer();

      _notifyUpdate(RecordingUpdate(type: RecordingUpdateType.start));
      return true;
    } catch (e) {
      _resetTiming();
      _state = RecordingState.idle;
      _activeRecordingPath = null;
      _notifyUpdate(
        RecordingUpdate(type: RecordingUpdateType.error, error: e.toString()),
      );
      return false;
    }
  }

  Future<void> pause() async {
    if (_state != RecordingState.recording) {
      return;
    }

    try {
      await _recorderRuntime.pause();
      _syncElapsed();
      _stopTimer();
      _state = RecordingState.paused;
      _notifyUpdate(
        RecordingUpdate(
          type: RecordingUpdateType.pause,
          duration: _effectiveElapsed().inSeconds,
        ),
      );
    } catch (e) {
      _notifyUpdate(
        RecordingUpdate(type: RecordingUpdateType.error, error: e.toString()),
      );
    }
  }

  Future<void> resume() async {
    if (_state != RecordingState.paused) {
      return;
    }

    try {
      await _recorderRuntime.resume();
      _state = RecordingState.recording;
      _stopwatch = Stopwatch()..start();
      _startTimer();
      _notifyUpdate(
        RecordingUpdate(
          type: RecordingUpdateType.resume,
          duration: _effectiveElapsed().inSeconds,
        ),
      );
    } catch (e) {
      _notifyUpdate(
        RecordingUpdate(type: RecordingUpdateType.error, error: e.toString()),
      );
    }
  }

  Future<RecordingResult> stop() async {
    final pendingStop = _stopInFlight;
    if (pendingStop != null) {
      return pendingStop;
    }

    if (_state != RecordingState.recording && _state != RecordingState.paused) {
      return RecordingResult(
        filePath: '',
        duration: 0,
        fileSize: 0,
        error: 'Not recording',
      );
    }

    late final Future<RecordingResult> stopFuture;
    stopFuture = _performStop().whenComplete(() {
      if (identical(_stopInFlight, stopFuture)) {
        _stopInFlight = null;
      }
    });
    _stopInFlight = stopFuture;
    return stopFuture;
  }

  Future<RecordingResult> _performStop() async {
    _stopTimer();
    _syncElapsed();
    final elapsed = _effectiveElapsed();
    final elapsedMs = elapsed.inMilliseconds;
    final elapsedSeconds = elapsed.inSeconds;

    try {
      final runtimePath = await _recorderRuntime.stop();
      final filePath = runtimePath?.trim().isNotEmpty == true
          ? runtimePath!.trim()
          : (_activeRecordingPath ?? '');

      final file = File(filePath);
      final fileExists = filePath.isNotEmpty && await file.exists();
      final fileSize = fileExists ? await file.length() : 0;
      final pathError = filePath.isEmpty
          ? 'Recording file path unavailable'
          : (!fileExists || fileSize <= 0)
          ? 'Recording file unavailable'
          : null;

      _state = RecordingState.stopped;
      _notifyUpdate(
        RecordingUpdate(
          type: RecordingUpdateType.stop,
          duration: elapsedSeconds,
          filePath: filePath,
        ),
      );
      _scheduleResetToIdle();

      return RecordingResult(
        filePath: filePath,
        duration: elapsedMs,
        fileSize: fileSize,
        error: pathError,
      );
    } catch (e) {
      _state = RecordingState.idle;
      _activeRecordingPath = null;
      _resetTiming();
      _notifyUpdate(
        RecordingUpdate(type: RecordingUpdateType.error, error: e.toString()),
      );
      return RecordingResult(
        filePath: '',
        duration: elapsedMs,
        fileSize: 0,
        error: e.toString(),
      );
    }
  }

  Future<void> cancel() async {
    _stopTimer();
    try {
      if (_state == RecordingState.recording ||
          _state == RecordingState.paused) {
        await _recorderRuntime.cancel();
      }
    } catch (e) {
      _notifyUpdate(
        RecordingUpdate(type: RecordingUpdateType.error, error: e.toString()),
      );
    } finally {
      _state = RecordingState.idle;
      _activeRecordingPath = null;
      _resetTiming();
      _notifyUpdate(RecordingUpdate(type: RecordingUpdateType.cancel));
    }
  }

  double getAmplitude() {
    if (_state != RecordingState.recording) {
      return 0.0;
    }
    return _lastAmplitude;
  }

  void _startTimer() {
    _stopTimer();
    _durationTimer = Timer.periodic(_progressInterval, (_) {
      unawaited(_emitProgress());
    });
  }

  Future<void> _emitProgress() async {
    if (_state != RecordingState.recording || _progressInFlight) {
      return;
    }
    _progressInFlight = true;
    try {
      _lastAmplitude = await _safeAmplitude();
      final elapsed = _effectiveElapsed();
      _notifyUpdate(
        RecordingUpdate(
          type: RecordingUpdateType.progress,
          duration: elapsed.inSeconds,
          amplitude: _lastAmplitude,
        ),
      );

      if (_config.maxDuration > 0 && elapsed.inSeconds >= _config.maxDuration) {
        await stop();
      }
    } finally {
      _progressInFlight = false;
    }
  }

  Future<double> _safeAmplitude() async {
    try {
      final amplitude = await _recorderRuntime.amplitude();
      return _clamp01(amplitude);
    } catch (_) {
      return 0.0;
    }
  }

  void _stopTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  Duration _effectiveElapsed() {
    final stopwatch = _stopwatch;
    if (stopwatch == null) {
      return _elapsed;
    }
    return _elapsed + stopwatch.elapsed;
  }

  void _syncElapsed() {
    final stopwatch = _stopwatch;
    if (stopwatch == null) {
      return;
    }
    _elapsed += stopwatch.elapsed;
    stopwatch.stop();
    _stopwatch = null;
  }

  void _resetTiming() {
    _stopwatch?.stop();
    _stopwatch = null;
    _elapsed = Duration.zero;
    _lastAmplitude = 0.0;
  }

  void _scheduleResetToIdle() {
    Future<void>.delayed(const Duration(milliseconds: 100), () {
      if (_state == RecordingState.stopped) {
        _state = RecordingState.idle;
        _activeRecordingPath = null;
        _resetTiming();
      }
    });
  }

  void _notifyUpdate(RecordingUpdate update) {
    if (!_recordingController.isClosed) {
      _recordingController.add(update);
    }
  }

  void dispose() {
    _stopTimer();
    _resetTiming();
    _activeRecordingPath = null;
    unawaited(_recorderRuntime.dispose());
    if (!_recordingController.isClosed) {
      _recordingController.close();
    }
  }

  static Future<bool> _defaultRequestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  static Future<String> _defaultBuildRecordingPath() async {
    final tempDir = await getTemporaryDirectory();
    final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    return path.join(tempDir.path, fileName);
  }
}

/// Recording update event
class RecordingUpdate {
  final RecordingUpdateType type;
  final int? duration;
  final String? filePath;
  final String? error;
  final double? amplitude;

  RecordingUpdate({
    required this.type,
    this.duration,
    this.filePath,
    this.error,
    this.amplitude,
  });
}

/// Recording update type
enum RecordingUpdateType { start, pause, resume, stop, cancel, progress, error }

/// Audio playback manager
class AudioPlayManager {
  AudioPlayManager({
    AudioPlaybackRuntime? playbackRuntime,
    AudioPlaybackRuntimeFactory? playbackRuntimeFactory,
    Duration progressInterval = const Duration(milliseconds: 100),
  }) : _playbackRuntimeFactory =
           playbackRuntimeFactory ??
           (() => playbackRuntime ?? createDefaultAudioPlaybackRuntime()),
       _progressInterval = progressInterval;

  factory AudioPlayManager.test({
    required AudioPlaybackRuntime playbackRuntime,
    Duration progressInterval = const Duration(milliseconds: 100),
  }) {
    return AudioPlayManager(
      playbackRuntime: playbackRuntime,
      progressInterval: progressInterval,
    );
  }

  final AudioPlaybackRuntimeFactory _playbackRuntimeFactory;
  final Duration _progressInterval;
  AudioPlaybackRuntime? _playbackRuntime;

  AudioPlaybackSource? _currentSource;
  bool _isPlaying = false;
  int _currentPosition = 0;
  int _totalDuration = 0;
  Timer? _progressTimer;
  bool _progressInFlight = false;
  bool _hasObservedPlaybackProgress = false;
  Future<void> _operationQueue = Future<void>.value();
  int _playbackEpoch = 0;
  bool _disposed = false;

  final _playbackController = StreamController<PlaybackUpdate>.broadcast();

  Stream<PlaybackUpdate> get playbackStream => _playbackController.stream;
  bool get isPlaying => _isPlaying;
  AudioPlaybackSource? get currentSource => _currentSource;
  String? get currentPath => _currentSource?.value;
  int get currentPosition => _currentPosition;
  int get totalDuration => _totalDuration;

  Future<void> play(AudioPlaybackSource source) {
    return _enqueue(() => _playInternal(source));
  }

  Future<void> pause() {
    return _enqueue(_pauseInternal);
  }

  Future<void> resume() {
    return _enqueue(_resumeInternal);
  }

  Future<void> stop() {
    return _enqueue(() => _stopInternal(emitUpdate: true));
  }

  Future<void> seekTo(int position) {
    return _enqueue(() => _seekInternal(position));
  }

  Future<void> toggle(AudioPlaybackSource source) {
    return _enqueue(() async {
      if (_currentSource == source && _isPlaying) {
        await _pauseInternal();
      } else if (_currentSource == source && !_isPlaying) {
        await _resumeInternal();
      } else {
        await _playInternal(source);
      }
    });
  }

  Future<void> _playInternal(AudioPlaybackSource source) async {
    if (_disposed) {
      return;
    }
    _playbackEpoch += 1;
    try {
      debugPrint('[voice/play] setSource ${source.kind.name}:${source.value}');
      if (_isPlaying || _currentSource != null) {
        await _stopRuntimeAndRelease();
      }

      final runtime = _ensurePlaybackRuntime();
      await runtime.setSource(source);
      await runtime.play();
      final duration = await runtime.durationValue();
      final position = await runtime.position();

      _currentSource = source;
      _isPlaying = true;
      _currentPosition = position.inMilliseconds;
      _totalDuration = duration.inMilliseconds;
      _hasObservedPlaybackProgress = _currentPosition > 0;

      _notifyUpdate(
        PlaybackUpdate(
          type: PlaybackUpdateType.start,
          source: source,
          filePath: source.value,
          position: _currentPosition,
          duration: _totalDuration,
        ),
      );
      debugPrint(
        '[voice/play] started ${source.kind.name}:${source.value} duration=${_totalDuration}ms',
      );
      _startProgress();
    } catch (e) {
      await _safeDisposeRuntime();
      _resetPlaybackState();
      _stopProgress();
      debugPrint(
        '[voice/play] failed ${source.kind.name}:${source.value} error=$e',
      );
      _notifyUpdate(
        PlaybackUpdate(type: PlaybackUpdateType.error, error: e.toString()),
      );
    }
  }

  Future<void> _pauseInternal() async {
    if (_disposed) {
      return;
    }
    if (!_isPlaying) {
      return;
    }

    try {
      final runtime = _playbackRuntime;
      if (runtime == null) {
        return;
      }
      await runtime.pause();
      final position = await runtime.position();
      _playbackEpoch += 1;
      _isPlaying = false;
      _currentPosition = position.inMilliseconds;
      _stopProgress();
      _notifyUpdate(
        PlaybackUpdate(
          type: PlaybackUpdateType.pause,
          source: _currentSource,
          filePath: _currentSource?.value,
          position: _currentPosition,
          duration: _totalDuration,
        ),
      );
    } catch (e) {
      _notifyUpdate(
        PlaybackUpdate(type: PlaybackUpdateType.error, error: e.toString()),
      );
    }
  }

  Future<void> _resumeInternal() async {
    if (_disposed) {
      return;
    }
    if (_isPlaying || _currentSource == null) {
      return;
    }

    try {
      final runtime = _playbackRuntime;
      if (runtime == null) {
        return;
      }
      await runtime.play();
      _isPlaying = true;
      _startProgress();
      _notifyUpdate(
        PlaybackUpdate(
          type: PlaybackUpdateType.resume,
          source: _currentSource,
          filePath: _currentSource?.value,
          position: _currentPosition,
          duration: _totalDuration,
        ),
      );
    } catch (e) {
      _notifyUpdate(
        PlaybackUpdate(type: PlaybackUpdateType.error, error: e.toString()),
      );
    }
  }

  Future<void> _stopInternal({required bool emitUpdate}) async {
    if (_disposed) {
      return;
    }
    final stoppingSource = _currentSource;
    try {
      final runtime = _playbackRuntime;
      if (runtime != null) {
        await runtime.stop();
      }
    } catch (e) {
      if (emitUpdate) {
        _notifyUpdate(
          PlaybackUpdate(type: PlaybackUpdateType.error, error: e.toString()),
        );
      }
    } finally {
      await _safeDisposeRuntime();
      _resetPlaybackState();
      _stopProgress();
      if (emitUpdate) {
        _notifyUpdate(
          PlaybackUpdate(
            type: PlaybackUpdateType.stop,
            source: stoppingSource,
            filePath: stoppingSource?.value,
            position: 0,
            duration: 0,
          ),
        );
      }
    }
  }

  Future<void> _seekInternal(int position) async {
    if (_disposed) {
      return;
    }
    if (_currentSource == null) {
      return;
    }

    try {
      final target = Duration(milliseconds: position.clamp(0, 1 << 31));
      final runtime = _playbackRuntime;
      if (runtime == null) {
        return;
      }
      await runtime.seek(target);
      final actual = await runtime.position();
      _currentPosition = actual.inMilliseconds;
      _notifyUpdate(
        PlaybackUpdate(
          type: PlaybackUpdateType.seek,
          source: _currentSource,
          filePath: _currentSource?.value,
          position: _currentPosition,
          duration: _totalDuration,
        ),
      );
    } catch (e) {
      _notifyUpdate(
        PlaybackUpdate(type: PlaybackUpdateType.error, error: e.toString()),
      );
    }
  }

  Future<void> _enqueue(Future<void> Function() action) {
    if (_disposed) {
      return Future<void>.value();
    }
    final future = _operationQueue.then((_) => action());
    _operationQueue = future.catchError((_) {});
    return future;
  }

  void _startProgress() {
    _stopProgress();
    _progressTimer = Timer.periodic(_progressInterval, (_) {
      unawaited(_emitPlaybackProgress());
    });
  }

  Future<void> _emitPlaybackProgress() async {
    final sourceAtStart = _currentSource;
    final epochAtStart = _playbackEpoch;
    if (sourceAtStart == null || !_isPlaying || _progressInFlight) {
      return;
    }

    _progressInFlight = true;
    try {
      final runtime = _playbackRuntime;
      if (runtime == null) {
        return;
      }
      final position = await runtime.position();
      final duration = await runtime.durationValue();
      final playing = await runtime.isPlaying();

      if (_disposed ||
          !_isPlaying ||
          _playbackEpoch != epochAtStart ||
          _currentSource != sourceAtStart) {
        return;
      }

      _currentPosition = position.inMilliseconds;
      _totalDuration = duration.inMilliseconds;
      if (_currentPosition > 0) {
        _hasObservedPlaybackProgress = true;
      }

      final hasReachedEnd =
          _totalDuration > 0 && _currentPosition >= _totalDuration;
      final hasCompletedPlayback =
          !playing && (_hasObservedPlaybackProgress || hasReachedEnd);
      if (hasCompletedPlayback) {
        _isPlaying = false;
        await stop();
        return;
      }

      _notifyUpdate(
        PlaybackUpdate(
          type: PlaybackUpdateType.progress,
          source: sourceAtStart,
          filePath: sourceAtStart.value,
          position: _currentPosition,
          duration: _totalDuration,
        ),
      );
    } catch (e) {
      _notifyUpdate(
        PlaybackUpdate(type: PlaybackUpdateType.error, error: e.toString()),
      );
    } finally {
      _progressInFlight = false;
    }
  }

  Future<void> _stopRuntimeAndRelease() async {
    try {
      final runtime = _playbackRuntime;
      if (runtime != null) {
        await runtime.stop();
      }
    } catch (_) {
      // Best-effort cleanup before loading a new source.
    }
    await _safeDisposeRuntime();
    _resetPlaybackState();
    _stopProgress();
  }

  Future<void> _safeDisposeRuntime() async {
    final runtime = _playbackRuntime;
    _playbackRuntime = null;
    if (runtime == null) {
      return;
    }
    try {
      await runtime.dispose();
    } catch (_) {
      // Keep manager state recoverable even when runtime disposal fails.
    }
  }

  AudioPlaybackRuntime _ensurePlaybackRuntime() {
    return _playbackRuntime ??= _playbackRuntimeFactory();
  }

  void _resetPlaybackState() {
    _isPlaying = false;
    _currentSource = null;
    _currentPosition = 0;
    _totalDuration = 0;
    _hasObservedPlaybackProgress = false;
    _playbackEpoch += 1;
  }

  void _stopProgress() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  void _notifyUpdate(PlaybackUpdate update) {
    if (!_playbackController.isClosed) {
      _playbackController.add(update);
    }
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _stopProgress();
    unawaited(_stopRuntimeAndRelease());
    if (!_playbackController.isClosed) {
      _playbackController.close();
    }
  }
}

/// Playback update event
class PlaybackUpdate {
  final PlaybackUpdateType type;
  final AudioPlaybackSource? source;
  final String? filePath;
  final int? position;
  final int? duration;
  final String? error;

  PlaybackUpdate({
    required this.type,
    this.source,
    this.filePath,
    this.position,
    this.duration,
    this.error,
  });
}

/// Playback update type
enum PlaybackUpdateType { start, pause, resume, stop, seek, progress, error }

class _RecordAudioRecorderRuntime implements AudioRecorderRuntime {
  final AudioRecorder _recorder = AudioRecorder();

  @override
  Future<void> start({
    required String path,
    required RecordingConfig config,
  }) async {
    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: config.sampleRate,
        bitRate: config.bitRate,
      ),
      path: path,
    );
  }

  @override
  Future<void> pause() => _recorder.pause();

  @override
  Future<void> resume() => _recorder.resume();

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<double> amplitude() async {
    final amplitude = await _recorder.getAmplitude();
    final currentDb = amplitude.current;
    if (currentDb.isNaN || currentDb.isInfinite) {
      return 0.0;
    }
    // Convert decibel-like values into [0, 1] for UI usage.
    return _clamp01((currentDb + 60.0) / 60.0);
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}

class _VideoPlayerAudioPlaybackRuntime implements AudioPlaybackRuntime {
  VideoPlayerController? _controller;

  @override
  Future<void> setSource(AudioPlaybackSource source) async {
    await _disposeController();
    final VideoPlayerController controller;
    switch (source.kind) {
      case AudioPlaybackSourceKind.file:
        controller = VideoPlayerController.file(File(source.value));
        break;
      case AudioPlaybackSourceKind.network:
        controller = VideoPlayerController.networkUrl(Uri.parse(source.value));
        break;
    }
    try {
      await controller.initialize();
      await controller.setLooping(false);
    } catch (_) {
      await controller.dispose();
      rethrow;
    }
    _controller = controller;
  }

  @override
  Future<void> play() async {
    final controller = _controller;
    if (controller == null) {
      throw StateError('No audio source loaded');
    }
    await controller.play();
  }

  @override
  Future<void> pause() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    await controller.pause();
  }

  @override
  Future<void> stop() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    await controller.pause();
    await controller.seekTo(Duration.zero);
  }

  @override
  Future<void> seek(Duration position) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    await controller.seekTo(position);
  }

  @override
  Future<Duration> position() async {
    return _controller?.value.position ?? Duration.zero;
  }

  @override
  Future<Duration> durationValue() async {
    return _controller?.value.duration ?? Duration.zero;
  }

  @override
  Future<bool> isPlaying() async {
    return _controller?.value.isPlaying ?? false;
  }

  @override
  Future<void> dispose() async {
    await _disposeController();
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      await controller.dispose();
    }
  }
}

class _AudioPlayerPlaybackRuntime implements AudioPlaybackRuntime {
  _AudioPlayerPlaybackRuntime() {
    _stateSubscription = _player.onPlayerStateChanged.listen((state) {
      _state = state;
    });
  }

  final audioplayers.AudioPlayer _player = audioplayers.AudioPlayer();
  late final StreamSubscription<audioplayers.PlayerState> _stateSubscription;
  audioplayers.PlayerState _state = audioplayers.PlayerState.stopped;

  @override
  Future<void> setSource(AudioPlaybackSource source) async {
    await _player.stop();
    await _player.setReleaseMode(audioplayers.ReleaseMode.stop);
    switch (source.kind) {
      case AudioPlaybackSourceKind.file:
        await _player.setSourceDeviceFile(source.value);
        break;
      case AudioPlaybackSourceKind.network:
        await _player.setSourceUrl(source.value);
        break;
    }
  }

  @override
  Future<void> play() => _player.resume();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<Duration> position() async {
    return await _player.getCurrentPosition() ?? Duration.zero;
  }

  @override
  Future<Duration> durationValue() async {
    return await _player.getDuration() ?? Duration.zero;
  }

  @override
  Future<bool> isPlaying() async {
    return _state == audioplayers.PlayerState.playing;
  }

  @override
  Future<void> dispose() async {
    await _stateSubscription.cancel();
    await _player.dispose();
  }
}

double _clamp01(double value) {
  if (value < 0) {
    return 0.0;
  }
  if (value > 1) {
    return 1.0;
  }
  return value;
}
