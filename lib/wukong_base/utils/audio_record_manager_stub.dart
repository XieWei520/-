import 'dart:async';

enum RecordingState { idle, recording, paused, stopped }

enum RecordingQuality { low, medium, high }

class RecordingConfig {
  const RecordingConfig({
    this.quality = RecordingQuality.medium,
    this.maxDuration = 60,
    this.minDuration = 1,
  });

  final RecordingQuality quality;
  final int maxDuration;
  final int minDuration;

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

class RecordingResult {
  RecordingResult({
    required this.filePath,
    required this.duration,
    required this.fileSize,
    this.error,
  });

  final String filePath;
  final int duration;
  final int fileSize;
  final String? error;

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

abstract class AudioRecorderRuntime {
  Future<void> start({required String path, required RecordingConfig config});
  Future<void> pause();
  Future<void> resume();
  Future<String?> stop();
  Future<void> cancel();
  Future<double> amplitude();
  Future<void> dispose();
}

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
  return AudioPlaybackBackend.audioPlayer;
}

AudioPlaybackRuntime createDefaultAudioPlaybackRuntime() {
  return _UnsupportedAudioPlaybackRuntime();
}

class AudioRecordManager {
  static final AudioRecordManager _instance = AudioRecordManager._internal();

  factory AudioRecordManager() => _instance;

  AudioRecordManager._internal();

  factory AudioRecordManager.test({
    required AudioRecorderRuntime recorderRuntime,
    required RequestMicrophonePermission requestMicrophonePermission,
    required BuildRecordingPath buildRecordingPath,
    Duration progressInterval = const Duration(milliseconds: 100),
  }) {
    return AudioRecordManager._internal();
  }

  final StreamController<RecordingUpdate> _recordingController =
      StreamController<RecordingUpdate>.broadcast();

  Stream<RecordingUpdate> get recordingStream => _recordingController.stream;
  RecordingState get state => RecordingState.idle;
  int get currentDuration => 0;

  void setConfig(RecordingConfig config) {}

  double getAmplitude() => 0.0;

  Future<bool> start() async {
    _notifyRecordingError('Audio recording is unavailable on this platform');
    return false;
  }

  Future<void> pause() async {}

  Future<void> resume() async {}

  Future<RecordingResult> stop() async {
    return RecordingResult(
      filePath: '',
      duration: 0,
      fileSize: 0,
      error: 'Audio recording is unavailable on this platform',
    );
  }

  Future<void> cancel() async {
    if (!_recordingController.isClosed) {
      _recordingController.add(
        RecordingUpdate(type: RecordingUpdateType.cancel),
      );
    }
  }

  void dispose() {
    if (!_recordingController.isClosed) {
      _recordingController.close();
    }
  }

  void _notifyRecordingError(String message) {
    if (!_recordingController.isClosed) {
      _recordingController.add(
        RecordingUpdate(type: RecordingUpdateType.error, error: message),
      );
    }
  }
}

class RecordingUpdate {
  RecordingUpdate({
    required this.type,
    this.duration,
    this.filePath,
    this.error,
    this.amplitude,
  });

  final RecordingUpdateType type;
  final int? duration;
  final String? filePath;
  final String? error;
  final double? amplitude;
}

enum RecordingUpdateType { start, pause, resume, stop, cancel, progress, error }

class AudioPlayManager {
  AudioPlayManager({
    AudioPlaybackRuntime? playbackRuntime,
    AudioPlaybackRuntimeFactory? playbackRuntimeFactory,
    Duration progressInterval = const Duration(milliseconds: 100),
  }) : _playbackRuntime =
           playbackRuntime ??
           playbackRuntimeFactory?.call() ??
           createDefaultAudioPlaybackRuntime();

  factory AudioPlayManager.test({
    required AudioPlaybackRuntime playbackRuntime,
    Duration progressInterval = const Duration(milliseconds: 100),
  }) {
    return AudioPlayManager(playbackRuntime: playbackRuntime);
  }

  final AudioPlaybackRuntime _playbackRuntime;
  final StreamController<PlaybackUpdate> _playbackController =
      StreamController<PlaybackUpdate>.broadcast();
  AudioPlaybackSource? _currentSource;
  bool _isPlaying = false;
  int _currentPosition = 0;
  int _totalDuration = 0;
  bool _disposed = false;

  Stream<PlaybackUpdate> get playbackStream => _playbackController.stream;
  bool get isPlaying => _isPlaying;
  AudioPlaybackSource? get currentSource => _currentSource;
  String? get currentPath => _currentSource?.value;
  int get currentPosition => _currentPosition;
  int get totalDuration => _totalDuration;

  Future<void> play(AudioPlaybackSource source) async {
    if (_disposed) {
      return;
    }
    _currentSource = source;
    _isPlaying = false;
    try {
      await _playbackRuntime.setSource(source);
      await _playbackRuntime.play();
      _isPlaying = await _playbackRuntime.isPlaying();
      _currentPosition = (await _playbackRuntime.position()).inMilliseconds;
      _totalDuration = (await _playbackRuntime.durationValue()).inMilliseconds;
      _notifyPlayback(
        PlaybackUpdate(
          type: PlaybackUpdateType.start,
          source: source,
          filePath: source.value,
          position: _currentPosition,
          duration: _totalDuration,
        ),
      );
    } catch (error) {
      _isPlaying = false;
      _notifyPlayback(
        PlaybackUpdate(type: PlaybackUpdateType.error, error: error.toString()),
      );
    }
  }

  Future<void> pause() async {
    if (_disposed) {
      return;
    }
    await _playbackRuntime.pause();
    _isPlaying = false;
    _notifyPlayback(
      PlaybackUpdate(
        type: PlaybackUpdateType.pause,
        source: _currentSource,
        filePath: _currentSource?.value,
        position: _currentPosition,
        duration: _totalDuration,
      ),
    );
  }

  Future<void> resume() async {
    if (_disposed || _currentSource == null) {
      return;
    }
    await _playbackRuntime.play();
    _isPlaying = await _playbackRuntime.isPlaying();
    _notifyPlayback(
      PlaybackUpdate(
        type: PlaybackUpdateType.resume,
        source: _currentSource,
        filePath: _currentSource?.value,
        position: _currentPosition,
        duration: _totalDuration,
      ),
    );
  }

  Future<void> stop() async {
    if (_disposed) {
      return;
    }
    await _playbackRuntime.stop();
    final stoppedSource = _currentSource;
    _currentSource = null;
    _isPlaying = false;
    _currentPosition = 0;
    _totalDuration = 0;
    _notifyPlayback(
      PlaybackUpdate(
        type: PlaybackUpdateType.stop,
        source: stoppedSource,
        filePath: stoppedSource?.value,
        position: 0,
        duration: 0,
      ),
    );
  }

  Future<void> seekTo(int position) async {
    if (_disposed) {
      return;
    }
    final target = Duration(milliseconds: position.clamp(0, 1 << 31));
    await _playbackRuntime.seek(target);
    _currentPosition = target.inMilliseconds;
    _notifyPlayback(
      PlaybackUpdate(
        type: PlaybackUpdateType.seek,
        source: _currentSource,
        filePath: _currentSource?.value,
        position: _currentPosition,
        duration: _totalDuration,
      ),
    );
  }

  Future<void> toggle(AudioPlaybackSource source) {
    if (_currentSource == source && _isPlaying) {
      return pause();
    }
    if (_currentSource == source && !_isPlaying) {
      return resume();
    }
    return play(source);
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    unawaited(_playbackRuntime.dispose());
    if (!_playbackController.isClosed) {
      _playbackController.close();
    }
  }

  void _notifyPlayback(PlaybackUpdate update) {
    if (!_playbackController.isClosed) {
      _playbackController.add(update);
    }
  }
}

class PlaybackUpdate {
  PlaybackUpdate({
    required this.type,
    this.source,
    this.filePath,
    this.position,
    this.duration,
    this.error,
  });

  final PlaybackUpdateType type;
  final AudioPlaybackSource? source;
  final String? filePath;
  final int? position;
  final int? duration;
  final String? error;
}

enum PlaybackUpdateType { start, pause, resume, stop, seek, progress, error }

class _UnsupportedAudioPlaybackRuntime implements AudioPlaybackRuntime {
  @override
  Future<Duration> durationValue() async => Duration.zero;

  @override
  Future<bool> isPlaying() async => false;

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {
    throw UnsupportedError('Audio playback is unavailable on this platform');
  }

  @override
  Future<Duration> position() async => Duration.zero;

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setSource(AudioPlaybackSource source) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
