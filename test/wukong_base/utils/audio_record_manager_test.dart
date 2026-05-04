import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_base/utils/audio_record_manager.dart';

void main() {
  group('AudioRecordManager', () {
    test('recording quality presets use IM-friendly sample and bit rates', () {
      const low = RecordingConfig(quality: RecordingQuality.low);
      const medium = RecordingConfig(quality: RecordingQuality.medium);
      const high = RecordingConfig(quality: RecordingQuality.high);

      expect(low.sampleRate, 12000);
      expect(low.bitRate, 24000);

      expect(medium.sampleRate, 16000);
      expect(medium.bitRate, 32000);

      expect(high.sampleRate, 24000);
      expect(high.bitRate, 48000);
    });

    test(
      'start forwards each configured quality profile to recorder runtime',
      () async {
        final scenarios =
            <({RecordingQuality quality, int sampleRate, int bitRate})>[
              (
                quality: RecordingQuality.low,
                sampleRate: 12000,
                bitRate: 24000,
              ),
              (
                quality: RecordingQuality.medium,
                sampleRate: 16000,
                bitRate: 32000,
              ),
              (
                quality: RecordingQuality.high,
                sampleRate: 24000,
                bitRate: 48000,
              ),
            ];

        for (final scenario in scenarios) {
          final fakeRecorder = _FakeAudioRecorderRuntime();
          final manager = AudioRecordManager.test(
            recorderRuntime: fakeRecorder,
            requestMicrophonePermission: () async => true,
            buildRecordingPath: () async =>
                '${Directory.systemTemp.path}/config-forwarding-${scenario.quality.name}.m4a',
          );
          addTearDown(manager.dispose);

          manager.setConfig(
            RecordingConfig(
              quality: scenario.quality,
              maxDuration: 60,
              minDuration: 1,
            ),
          );

          final started = await manager.start();

          expect(started, isTrue, reason: scenario.quality.name);
          expect(
            fakeRecorder.lastConfig?.sampleRate,
            scenario.sampleRate,
            reason: scenario.quality.name,
          );
          expect(
            fakeRecorder.lastConfig?.bitRate,
            scenario.bitRate,
            reason: scenario.quality.name,
          );
        }
      },
    );

    test(
      'start returns false and emits error when microphone permission is denied',
      () async {
        final fakeRecorder = _FakeAudioRecorderRuntime();
        final manager = AudioRecordManager.test(
          recorderRuntime: fakeRecorder,
          requestMicrophonePermission: () async => false,
          buildRecordingPath: () async =>
              '${Directory.systemTemp.path}/permission-denied.m4a',
          progressInterval: const Duration(milliseconds: 30),
        );
        final updates = <RecordingUpdate>[];
        final subscription = manager.recordingStream.listen(updates.add);
        addTearDown(subscription.cancel);
        addTearDown(manager.dispose);

        final started = await manager.start();
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(started, isFalse);
        expect(manager.state, RecordingState.idle);
        expect(fakeRecorder.startCalls, 0);
        expect(
          updates.any((update) => update.type == RecordingUpdateType.error),
          isTrue,
        );
        expect(updates.last.error, contains('microphone'));
      },
    );

    test('start failure emits error and keeps manager idle', () async {
      final fakeRecorder = _FakeAudioRecorderRuntime(throwOnStart: true);
      final manager = AudioRecordManager.test(
        recorderRuntime: fakeRecorder,
        requestMicrophonePermission: () async => true,
        buildRecordingPath: () async =>
            '${Directory.systemTemp.path}/start-failure.m4a',
        progressInterval: const Duration(milliseconds: 30),
      );
      final updates = <RecordingUpdate>[];
      final subscription = manager.recordingStream.listen(updates.add);
      addTearDown(subscription.cancel);
      addTearDown(manager.dispose);

      final started = await manager.start();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(started, isFalse);
      expect(manager.state, RecordingState.idle);
      expect(fakeRecorder.startCalls, 1);
      expect(
        updates.any((update) => update.type == RecordingUpdateType.error),
        isTrue,
      );
      expect(updates.last.error, contains('start failed'));
    });

    test(
      'start pause resume stop emits lifecycle updates and file metadata',
      () async {
        final tempFile = File(
          '${Directory.systemTemp.path}/recording-${DateTime.now().microsecondsSinceEpoch}.m4a',
        );
        addTearDown(() async {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        });

        final fakeRecorder = _FakeAudioRecorderRuntime(
          outputBytes: const <int>[1, 2, 3, 4],
        );
        final manager = AudioRecordManager.test(
          recorderRuntime: fakeRecorder,
          requestMicrophonePermission: () async => true,
          buildRecordingPath: () async => tempFile.path,
          progressInterval: const Duration(milliseconds: 20),
        );
        final updates = <RecordingUpdate>[];
        final subscription = manager.recordingStream.listen(updates.add);
        addTearDown(subscription.cancel);
        addTearDown(manager.dispose);

        final started = await manager.start();
        await Future<void>.delayed(const Duration(milliseconds: 70));
        await manager.pause();
        await manager.resume();
        await Future<void>.delayed(const Duration(milliseconds: 70));
        final result = await manager.stop();
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(started, isTrue);
        expect(result.error, isNull);
        expect(result.filePath, tempFile.path);
        expect(result.fileSize, 4);
        expect(result.duration, greaterThan(0));
        expect(fakeRecorder.pauseCalls, 1);
        expect(fakeRecorder.resumeCalls, 1);
        expect(fakeRecorder.stopCalls, 1);

        final eventTypes = updates.map((update) => update.type).toList();
        expect(eventTypes, contains(RecordingUpdateType.start));
        expect(eventTypes, contains(RecordingUpdateType.pause));
        expect(eventTypes, contains(RecordingUpdateType.resume));
        expect(eventTypes, contains(RecordingUpdateType.progress));
        expect(eventTypes, contains(RecordingUpdateType.stop));

        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(manager.state, RecordingState.idle);
      },
    );

    test(
      'stop returns error when recorder reports a path but file is unavailable',
      () async {
        final tempFile = File(
          '${Directory.systemTemp.path}/recording-unavailable-${DateTime.now().microsecondsSinceEpoch}.m4a',
        );
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

        final fakeRecorder = _FakeAudioRecorderRuntime(writeOutputFile: false);
        final manager = AudioRecordManager.test(
          recorderRuntime: fakeRecorder,
          requestMicrophonePermission: () async => true,
          buildRecordingPath: () async => tempFile.path,
          progressInterval: const Duration(milliseconds: 20),
        );
        addTearDown(manager.dispose);

        final started = await manager.start();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final result = await manager.stop();

        expect(started, isTrue);
        expect(result.filePath, tempFile.path);
        expect(result.fileSize, 0);
        expect(result.error, isNotNull);
      },
    );

    test('stop when not recording returns error result', () async {
      final manager = AudioRecordManager.test(
        recorderRuntime: _FakeAudioRecorderRuntime(),
        requestMicrophonePermission: () async => true,
        buildRecordingPath: () async =>
            '${Directory.systemTemp.path}/unused.m4a',
      );
      addTearDown(manager.dispose);

      final result = await manager.stop();

      expect(result.error, isNotNull);
      expect(result.filePath, isEmpty);
      expect(result.fileSize, 0);
      expect(result.duration, 0);
    });

    test('concurrent stop calls share one in-flight stop operation', () async {
      final tempFile = File(
        '${Directory.systemTemp.path}/recording-concurrent-stop-${DateTime.now().microsecondsSinceEpoch}.m4a',
      );
      addTearDown(() async {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      });

      final fakeRecorder = _FakeAudioRecorderRuntime(
        outputBytes: const <int>[1, 2, 3, 4],
        stopDelay: const Duration(milliseconds: 120),
        failConcurrentStop: true,
      );
      final manager = AudioRecordManager.test(
        recorderRuntime: fakeRecorder,
        requestMicrophonePermission: () async => true,
        buildRecordingPath: () async => tempFile.path,
        progressInterval: const Duration(milliseconds: 20),
      );
      addTearDown(manager.dispose);

      final started = await manager.start();
      expect(started, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      final firstStopFuture = manager.stop();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final secondStopFuture = manager.stop();

      final firstResult = await firstStopFuture;
      final secondResult = await secondStopFuture;

      expect(firstResult.error, isNull);
      expect(secondResult.error, isNull);
      expect(firstResult.filePath, tempFile.path);
      expect(secondResult.filePath, tempFile.path);
      expect(fakeRecorder.stopCalls, 1);
    });
  });

  group('AudioPlayManager', () {
    test(
      'windows defaults to audioplayers backend for supported desktop playback',
      () {
        if (Platform.isWindows) {
          expect(
            defaultAudioPlaybackBackend(),
            AudioPlaybackBackend.audioPlayer,
          );
        } else {
          expect(
            defaultAudioPlaybackBackend(),
            AudioPlaybackBackend.videoPlayer,
          );
        }
      },
    );

    test('play pause resume seek stop emits playback transitions', () async {
      final fakeRuntime = _FakeAudioPlaybackRuntime(
        duration: const Duration(seconds: 3),
      );
      final manager = AudioPlayManager.test(
        playbackRuntime: fakeRuntime,
        progressInterval: const Duration(milliseconds: 25),
      );
      final updates = <PlaybackUpdate>[];
      final subscription = manager.playbackStream.listen(updates.add);
      addTearDown(subscription.cancel);
      addTearDown(manager.dispose);
      const source = AudioPlaybackSource.file('/tmp/demo-audio.m4a');

      await manager.play(source);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await manager.pause();
      await manager.seekTo(1200);
      await manager.resume();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await manager.stop();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(fakeRuntime.setSourceCalls, 1);
      expect(fakeRuntime.playCalls, 2);
      expect(fakeRuntime.pauseCalls, 1);
      expect(fakeRuntime.seekCalls, 1);
      expect(fakeRuntime.stopCalls, 1);
      expect(manager.isPlaying, isFalse);
      expect(manager.currentSource, isNull);
      expect(manager.currentPosition, 0);

      final eventTypes = updates.map((update) => update.type).toList();
      expect(eventTypes, contains(PlaybackUpdateType.start));
      expect(eventTypes, contains(PlaybackUpdateType.pause));
      expect(eventTypes, contains(PlaybackUpdateType.seek));
      expect(eventTypes, contains(PlaybackUpdateType.resume));
      expect(eventTypes, contains(PlaybackUpdateType.progress));
      expect(eventTypes, contains(PlaybackUpdateType.stop));
    });

    test(
      'play runtime failure emits error update and keeps manager stopped',
      () async {
        final fakeRuntime = _FakeAudioPlaybackRuntime(throwOnSetSource: true);
        final manager = AudioPlayManager.test(playbackRuntime: fakeRuntime);
        final updates = <PlaybackUpdate>[];
        final subscription = manager.playbackStream.listen(updates.add);
        addTearDown(subscription.cancel);
        addTearDown(manager.dispose);
        const source = AudioPlaybackSource.file('/tmp/failure.m4a');

        await manager.play(source);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(manager.isPlaying, isFalse);
        expect(manager.currentSource, isNull);
        expect(
          updates.any((update) => update.type == PlaybackUpdateType.error),
          isTrue,
        );
        expect(updates.last.error, contains('source failed'));
        expect(fakeRuntime.disposeCalls, 1);
      },
    );

    test(
      'toggle with same source pauses then resumes without reloading source',
      () async {
        final fakeRuntime = _FakeAudioPlaybackRuntime(
          duration: const Duration(seconds: 2),
        );
        final manager = AudioPlayManager.test(playbackRuntime: fakeRuntime);
        addTearDown(manager.dispose);
        const source = AudioPlaybackSource.network(
          'https://example.com/voice-toggle.mp3',
        );

        await manager.play(source);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await manager.toggle(source);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await manager.toggle(source);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(fakeRuntime.setSourceCalls, 1);
        expect(fakeRuntime.pauseCalls, 1);
        expect(fakeRuntime.playCalls, 2);
        expect(manager.currentSource, source);
      },
    );

    test(
      'stop releases runtime resources and manager remains reusable',
      () async {
        final fakeRuntime = _FakeAudioPlaybackRuntime(
          duration: const Duration(seconds: 2),
        );
        final manager = AudioPlayManager.test(
          playbackRuntime: fakeRuntime,
          progressInterval: const Duration(milliseconds: 25),
        );
        addTearDown(manager.dispose);
        const firstSource = AudioPlaybackSource.file('/tmp/reuse-1.m4a');
        const secondSource = AudioPlaybackSource.file('/tmp/reuse-2.m4a');

        await manager.play(firstSource);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await manager.stop();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(fakeRuntime.stopCalls, 1);
        expect(fakeRuntime.disposeCalls, 1);
        expect(manager.currentSource, isNull);

        await manager.play(secondSource);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(fakeRuntime.setSourceCalls, 2);
        expect(manager.currentSource, secondSource);
      },
    );

    test('manager recreates playback runtime after releasing it', () async {
      final runtimes = <_FakeAudioPlaybackRuntime>[
        _FakeAudioPlaybackRuntime(duration: const Duration(seconds: 2)),
        _FakeAudioPlaybackRuntime(duration: const Duration(seconds: 2)),
      ];
      var factoryCalls = 0;
      final manager = AudioPlayManager(
        playbackRuntimeFactory: () => runtimes[factoryCalls++],
      );
      addTearDown(manager.dispose);
      const firstSource = AudioPlaybackSource.file('/tmp/factory-1.m4a');
      const secondSource = AudioPlaybackSource.file('/tmp/factory-2.m4a');

      await manager.play(firstSource);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await manager.stop();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await manager.play(secondSource);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(factoryCalls, 2);
      expect(runtimes[0].setSourceCalls, 1);
      expect(runtimes[0].disposeCalls, 1);
      expect(runtimes[1].setSourceCalls, 1);
      expect(manager.currentSource, secondSource);
    });

    test(
      'in-flight progress started before pause does not emit progress after pause',
      () async {
        final fakeRuntime = _RaceProgressAudioPlaybackRuntime();
        final manager = AudioPlayManager.test(
          playbackRuntime: fakeRuntime,
          progressInterval: const Duration(milliseconds: 10),
        );
        final updates = <PlaybackUpdate>[];
        final subscription = manager.playbackStream.listen(updates.add);
        addTearDown(subscription.cancel);
        addTearDown(manager.dispose);
        const source = AudioPlaybackSource.file('/tmp/pause-race.m4a');

        await manager.play(source);
        await fakeRuntime.progressTickEntered;
        await manager.pause();
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final pauseIndex = updates.lastIndexWhere(
          (update) => update.type == PlaybackUpdateType.pause,
        );
        expect(pauseIndex, greaterThanOrEqualTo(0));

        fakeRuntime.releaseBlockedProgressTick();
        await Future<void>.delayed(const Duration(milliseconds: 30));

        final afterPauseTypes = updates
            .skip(pauseIndex + 1)
            .map((update) => update.type)
            .toList();
        expect(afterPauseTypes, isNot(contains(PlaybackUpdateType.progress)));
      },
    );

    test(
      'natural completion resets manager even when runtime stops slightly before reported duration',
      () async {
        final fakeRuntime = _NearEndCompletionAudioPlaybackRuntime();
        final manager = AudioPlayManager.test(
          playbackRuntime: fakeRuntime,
          progressInterval: const Duration(milliseconds: 10),
        );
        final updates = <PlaybackUpdate>[];
        final subscription = manager.playbackStream.listen(updates.add);
        addTearDown(subscription.cancel);
        addTearDown(manager.dispose);
        const source = AudioPlaybackSource.file('/tmp/natural-complete.m4a');

        await manager.play(source);
        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(fakeRuntime.playCalls, 1);
        expect(manager.isPlaying, isFalse);
        expect(manager.currentSource, isNull);
        expect(
          updates.any((update) => update.type == PlaybackUpdateType.stop),
          isTrue,
        );
      },
    );
  });
}

class _FakeAudioRecorderRuntime implements AudioRecorderRuntime {
  _FakeAudioRecorderRuntime({
    this.throwOnStart = false,
    this.outputBytes = const <int>[0],
    this.writeOutputFile = true,
    this.stopDelay = Duration.zero,
    this.failConcurrentStop = false,
  });

  final bool throwOnStart;
  final List<int> outputBytes;
  final bool writeOutputFile;
  final Duration stopDelay;
  final bool failConcurrentStop;

  int startCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  int amplitudeCalls = 0;
  int disposeCalls = 0;
  RecordingConfig? lastConfig;

  bool _isRecording = false;
  String? _path;
  bool _stopInFlight = false;

  @override
  Future<void> cancel() async {
    cancelCalls++;
    _isRecording = false;
    _path = null;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    _isRecording = false;
  }

  @override
  Future<double> amplitude() async {
    amplitudeCalls++;
    return _isRecording ? 0.5 : 0.0;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    _isRecording = false;
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
    _isRecording = true;
  }

  @override
  Future<void> start({
    required String path,
    required RecordingConfig config,
  }) async {
    startCalls++;
    lastConfig = config;
    if (throwOnStart) {
      throw StateError('start failed');
    }
    _path = path;
    _isRecording = true;
  }

  @override
  Future<String?> stop() async {
    stopCalls++;
    if (_stopInFlight && failConcurrentStop) {
      throw StateError('stop already in flight');
    }
    _stopInFlight = true;
    final targetPath = _path;
    try {
      if (stopDelay > Duration.zero) {
        await Future<void>.delayed(stopDelay);
      }
      _isRecording = false;
      if (targetPath == null) {
        return null;
      }
      if (!writeOutputFile) {
        return targetPath;
      }
      final file = File(targetPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(outputBytes, flush: true);
      return targetPath;
    } finally {
      _stopInFlight = false;
    }
  }
}

class _FakeAudioPlaybackRuntime implements AudioPlaybackRuntime {
  _FakeAudioPlaybackRuntime({
    this.duration = const Duration(seconds: 1),
    this.throwOnSetSource = false,
  });

  final Duration duration;
  final bool throwOnSetSource;

  int setSourceCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;
  int seekCalls = 0;
  int disposeCalls = 0;

  bool _isPlaying = false;
  Duration _position = Duration.zero;

  @override
  Future<void> dispose() async {
    disposeCalls++;
    _isPlaying = false;
  }

  @override
  Future<Duration> durationValue() async => duration;

  @override
  Future<bool> isPlaying() async => _isPlaying;

  @override
  Future<void> pause() async {
    pauseCalls++;
    _isPlaying = false;
  }

  @override
  Future<void> play() async {
    playCalls++;
    _isPlaying = true;
  }

  @override
  Future<Duration> position() async {
    if (_isPlaying) {
      _position += const Duration(milliseconds: 120);
      if (_position >= duration) {
        _position = duration;
        _isPlaying = false;
      }
    }
    return _position;
  }

  @override
  Future<void> seek(Duration position) async {
    seekCalls++;
    _position = position;
  }

  @override
  Future<void> setSource(AudioPlaybackSource source) async {
    setSourceCalls++;
    if (throwOnSetSource) {
      throw StateError('source failed');
    }
    _position = Duration.zero;
    _isPlaying = false;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _isPlaying = false;
    _position = Duration.zero;
  }
}

class _RaceProgressAudioPlaybackRuntime implements AudioPlaybackRuntime {
  final Completer<void> _progressTickEntered = Completer<void>();
  final Completer<void> _releaseProgressTick = Completer<void>();

  int _positionCalls = 0;
  bool _isPlaying = false;
  Duration _position = Duration.zero;

  Future<void> get progressTickEntered => _progressTickEntered.future;

  void releaseBlockedProgressTick() {
    if (!_releaseProgressTick.isCompleted) {
      _releaseProgressTick.complete();
    }
  }

  @override
  Future<void> dispose() async {
    _isPlaying = false;
    releaseBlockedProgressTick();
  }

  @override
  Future<Duration> durationValue() async => const Duration(seconds: 2);

  @override
  Future<bool> isPlaying() async => _isPlaying;

  @override
  Future<void> pause() async {
    _isPlaying = false;
  }

  @override
  Future<void> play() async {
    _isPlaying = true;
  }

  @override
  Future<Duration> position() async {
    _positionCalls += 1;
    if (_positionCalls == 2) {
      if (!_progressTickEntered.isCompleted) {
        _progressTickEntered.complete();
      }
      await _releaseProgressTick.future;
    }
    if (_isPlaying) {
      _position += const Duration(milliseconds: 120);
    }
    return _position;
  }

  @override
  Future<void> seek(Duration position) async {
    _position = position;
  }

  @override
  Future<void> setSource(AudioPlaybackSource source) async {
    _position = Duration.zero;
    _isPlaying = false;
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
    _position = Duration.zero;
  }
}

class _NearEndCompletionAudioPlaybackRuntime implements AudioPlaybackRuntime {
  final Duration _duration = const Duration(milliseconds: 200);
  Duration _position = Duration.zero;
  bool _isPlaying = false;

  int playCalls = 0;

  @override
  Future<void> dispose() async {
    _isPlaying = false;
  }

  @override
  Future<Duration> durationValue() async => _duration;

  @override
  Future<bool> isPlaying() async => _isPlaying;

  @override
  Future<void> pause() async {
    _isPlaying = false;
  }

  @override
  Future<void> play() async {
    playCalls++;
    _isPlaying = true;
  }

  @override
  Future<Duration> position() async {
    if (_isPlaying) {
      _position += const Duration(milliseconds: 80);
      if (_position >= const Duration(milliseconds: 160)) {
        _position = const Duration(milliseconds: 160);
        _isPlaying = false;
      }
    }
    return _position;
  }

  @override
  Future<void> seek(Duration position) async {
    _position = position;
  }

  @override
  Future<void> setSource(AudioPlaybackSource source) async {
    _position = Duration.zero;
    _isPlaying = false;
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
    _position = Duration.zero;
  }
}
