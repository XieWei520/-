import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_audio_session_bridge.dart';
import 'package:wukong_im_app/modules/chat/chat_voice_action_service.dart';
import 'package:wukong_im_app/wukong_base/utils/audio_record_manager.dart';
import 'package:wukongimfluttersdk/model/wk_voice_content.dart';

void main() {
  test('ChatVoiceActionService source does not import dart io directly', () {
    final source = File(
      'lib/modules/chat/chat_voice_action_service.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("import 'dart:io'")));
  });

  group('ChatVoiceContentFactory', () {
    test('builds voice content using a rounded-up duration in seconds', () {
      final factory = ChatVoiceContentFactory();

      final content = factory.buildVoiceContent(
        filePath: 'C:/tmp/demo.m4a',
        durationMs: 1500,
      );

      expect(content, isA<WKVoiceContent>());
      expect(content.localPath, 'C:/tmp/demo.m4a');
      expect(content.timeTrad, 2);
    });

    test('clamps extremely short recordings to one second', () {
      final factory = ChatVoiceContentFactory();

      final content = factory.buildVoiceContent(
        filePath: 'C:/tmp/short.m4a',
        durationMs: 120,
      );

      expect(content.timeTrad, 1);
    });
  });

  group('ChatVoiceRecordingState', () {
    test(
      'countdownSeconds defaults to null and can be updated via copyWith',
      () {
        const initial = ChatVoiceRecordingState(
          phase: ChatVoiceRecordingPhase.recording,
        );

        expect(initial.countdownSeconds, isNull);

        final withCountdown = initial.copyWith(countdownSeconds: 7);
        expect(withCountdown.countdownSeconds, 7);

        final clearedCountdown = withCountdown.copyWith(countdownSeconds: null);
        expect(clearedCountdown.countdownSeconds, isNull);
      },
    );
  });

  group('PlatformChatVoiceActionService', () {
    test(
      'startRecording pins medium recording profile for normal flow',
      () async {
        final tempFile = File(
          '${Directory.systemTemp.path}/voice-medium-profile-${DateTime.now().microsecondsSinceEpoch}.m4a',
        );
        addTearDown(() async {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        });

        final fakeRecorder = _FakeAudioRecorderRuntime();
        final recordManager = AudioRecordManager.test(
          recorderRuntime: fakeRecorder,
          requestMicrophonePermission: () async => true,
          buildRecordingPath: () async => tempFile.path,
          progressInterval: const Duration(milliseconds: 20),
        );
        final service = PlatformChatVoiceActionService(
          recordManager: recordManager,
        );
        addTearDown(service.dispose);

        final started = await service.startRecording();

        expect(started, isTrue);
        expect(fakeRecorder.lastStartConfig?.quality, RecordingQuality.medium);
        expect(fakeRecorder.lastStartConfig?.sampleRate, 16000);
        expect(fakeRecorder.lastStartConfig?.bitRate, 32000);
      },
    );

    test(
      'progress countdown appears only within last ten seconds before max duration',
      () async {
        final tempFile = File(
          '${Directory.systemTemp.path}/voice-countdown-window-${DateTime.now().microsecondsSinceEpoch}.m4a',
        );
        addTearDown(() async {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        });

        final recordManager = AudioRecordManager.test(
          recorderRuntime: _FakeAudioRecorderRuntime(),
          requestMicrophonePermission: () async => true,
          buildRecordingPath: () async => tempFile.path,
          progressInterval: const Duration(milliseconds: 20),
        );
        final service = PlatformChatVoiceActionService(
          recordManager: recordManager,
        );
        addTearDown(service.dispose);

        final started = await service.startRecording();
        expect(started, isTrue);

        service.debugHandleRecordingUpdate(
          RecordingUpdate(
            type: RecordingUpdateType.progress,
            duration: 49,
            amplitude: 0.5,
          ),
        );
        expect(service.recordingStateListenable.value.countdownSeconds, isNull);

        service.debugHandleRecordingUpdate(
          RecordingUpdate(
            type: RecordingUpdateType.progress,
            duration: 50,
            amplitude: 0.5,
          ),
        );
        expect(service.recordingStateListenable.value.countdownSeconds, 10);

        service.debugHandleRecordingUpdate(
          RecordingUpdate(
            type: RecordingUpdateType.progress,
            duration: 53,
            amplitude: 0.5,
          ),
        );
        expect(service.recordingStateListenable.value.countdownSeconds, 7);

        service.debugHandleRecordingUpdate(
          RecordingUpdate(
            type: RecordingUpdateType.progress,
            duration: 60,
            amplitude: 0.5,
          ),
        );
        expect(service.recordingStateListenable.value.countdownSeconds, isNull);
      },
    );

    test(
      'cancel intent set during startup is preserved after recording begins',
      () async {
        final tempFile = File(
          '${Directory.systemTemp.path}/voice-cancel-race-${DateTime.now().microsecondsSinceEpoch}.m4a',
        );
        addTearDown(() async {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        });

        final recordManager = AudioRecordManager.test(
          recorderRuntime: _FakeAudioRecorderRuntime(
            startDelay: const Duration(milliseconds: 120),
          ),
          requestMicrophonePermission: () async => true,
          buildRecordingPath: () async => tempFile.path,
          progressInterval: const Duration(milliseconds: 20),
        );
        final service = PlatformChatVoiceActionService(
          recordManager: recordManager,
        );
        addTearDown(service.dispose);

        final startFuture = service.startRecording();
        service.setCancelCandidate(true);

        final started = await startFuture;

        expect(started, isTrue);
        expect(
          service.recordingStateListenable.value.phase,
          ChatVoiceRecordingPhase.cancelCandidate,
        );

        service.setCancelCandidate(false);
        expect(
          service.recordingStateListenable.value.phase,
          ChatVoiceRecordingPhase.recording,
        );
      },
    );

    test(
      'startRecording failure keeps permissionDenied even after async error update',
      () async {
        final recordManager = AudioRecordManager.test(
          recorderRuntime: _FakeAudioRecorderRuntime(),
          requestMicrophonePermission: () async => false,
          buildRecordingPath: () async =>
              '${Directory.systemTemp.path}/voice-start-denied-${DateTime.now().microsecondsSinceEpoch}.m4a',
          progressInterval: const Duration(milliseconds: 20),
        );
        final service = PlatformChatVoiceActionService(
          recordManager: recordManager,
        );
        addTearDown(service.dispose);

        final started = await service.startRecording();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(started, isFalse);
        expect(
          service.recordingStateListenable.value.phase,
          ChatVoiceRecordingPhase.permissionDenied,
        );
      },
    );

    test(
      'startRecording called again while startup is in-flight returns false without changing phase',
      () async {
        final tempFile = File(
          '${Directory.systemTemp.path}/voice-start-inflight-${DateTime.now().microsecondsSinceEpoch}.m4a',
        );
        addTearDown(() async {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        });

        final recordManager = AudioRecordManager.test(
          recorderRuntime: _FakeAudioRecorderRuntime(
            startDelay: const Duration(milliseconds: 120),
          ),
          requestMicrophonePermission: () async => true,
          buildRecordingPath: () async => tempFile.path,
          progressInterval: const Duration(milliseconds: 20),
        );
        final service = PlatformChatVoiceActionService(
          recordManager: recordManager,
        );
        addTearDown(service.dispose);

        final firstStart = service.startRecording();
        final secondStart = await service.startRecording();

        expect(secondStart, isFalse);
        expect(
          service.recordingStateListenable.value.phase,
          ChatVoiceRecordingPhase.idle,
        );

        final firstStarted = await firstStart;
        expect(firstStarted, isTrue);
        expect(
          service.recordingStateListenable.value.phase,
          ChatVoiceRecordingPhase.recording,
        );
      },
    );

    test(
      'startRecording called again during recording keeps current recording phase',
      () async {
        final tempFile = File(
          '${Directory.systemTemp.path}/voice-restart-during-recording-${DateTime.now().microsecondsSinceEpoch}.m4a',
        );
        addTearDown(() async {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        });

        final recordManager = AudioRecordManager.test(
          recorderRuntime: _FakeAudioRecorderRuntime(),
          requestMicrophonePermission: () async => true,
          buildRecordingPath: () async => tempFile.path,
          progressInterval: const Duration(milliseconds: 20),
        );
        final service = PlatformChatVoiceActionService(
          recordManager: recordManager,
        );
        addTearDown(service.dispose);

        final started = await service.startRecording();
        expect(started, isTrue);

        final retryWhileRecording = await service.startRecording();
        expect(retryWhileRecording, isFalse);
        expect(
          service.recordingStateListenable.value.phase,
          ChatVoiceRecordingPhase.recording,
        );

        service.setCancelCandidate(true);
        expect(
          service.recordingStateListenable.value.phase,
          ChatVoiceRecordingPhase.cancelCandidate,
        );

        final retryWhileCancelCandidate = await service.startRecording();
        expect(retryWhileCancelCandidate, isFalse);
        expect(
          service.recordingStateListenable.value.phase,
          ChatVoiceRecordingPhase.cancelCandidate,
        );
      },
    );

    test(
      'startRecording runtime failure maps to sendFailed instead of permissionDenied',
      () async {
        final tempFile = File(
          '${Directory.systemTemp.path}/voice-start-runtime-failure-${DateTime.now().microsecondsSinceEpoch}.m4a',
        );
        addTearDown(() async {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        });

        final recordManager = AudioRecordManager.test(
          recorderRuntime: _FakeAudioRecorderRuntime(
            startError: 'recorder bootstrap failed',
          ),
          requestMicrophonePermission: () async => true,
          buildRecordingPath: () async => tempFile.path,
          progressInterval: const Duration(milliseconds: 20),
        );
        final service = PlatformChatVoiceActionService(
          recordManager: recordManager,
        );
        addTearDown(service.dispose);

        final started = await service.startRecording();

        expect(started, isFalse);
        expect(
          service.recordingStateListenable.value.phase,
          ChatVoiceRecordingPhase.sendFailed,
        );
        expect(
          service.recordingStateListenable.value.phase,
          isNot(ChatVoiceRecordingPhase.permissionDenied),
        );
      },
    );

    test('startRecording failure deactivates record audio session', () async {
      final bridge = _FakeChatAudioSessionBridge();
      final recordManager = AudioRecordManager.test(
        recorderRuntime: _FakeAudioRecorderRuntime(),
        requestMicrophonePermission: () async => false,
        buildRecordingPath: () async =>
            '${Directory.systemTemp.path}/voice-bridge-start-failure-${DateTime.now().microsecondsSinceEpoch}.m4a',
        progressInterval: const Duration(milliseconds: 20),
      );
      final service = PlatformChatVoiceActionService(
        recordManager: recordManager,
        audioSessionBridge: bridge,
      );
      addTearDown(service.dispose);

      final started = await service.startRecording();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(started, isFalse);
      expect(bridge.events, <String>['activate:record', 'deactivate']);
    });

    test(
      'stopRecording shouldSend true returns tooShort discard and exposes tooShort phase',
      () async {
        final tempFile = File(
          '${Directory.systemTemp.path}/voice-too-short-${DateTime.now().microsecondsSinceEpoch}.m4a',
        );
        addTearDown(() async {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        });

        final recordManager = AudioRecordManager.test(
          recorderRuntime: _FakeAudioRecorderRuntime(
            outputBytes: const <int>[1, 2, 3],
          ),
          requestMicrophonePermission: () async => true,
          buildRecordingPath: () async => tempFile.path,
          progressInterval: const Duration(milliseconds: 20),
        );
        final service = PlatformChatVoiceActionService(
          recordManager: recordManager,
        );
        addTearDown(service.dispose);

        final started = await service.startRecording();
        expect(started, isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 120));

        final result = await service.stopRecording(shouldSend: true);

        expect(result, isA<ChatVoiceDiscardedResult>());
        expect(
          (result as ChatVoiceDiscardedResult).reason,
          ChatVoiceDiscardReason.tooShort,
        );
        expect(
          service.recordingStateListenable.value.phase,
          ChatVoiceRecordingPhase.tooShort,
        );
      },
    );

    test(
      'stopRecording shouldSend true returns send-ready result when file is valid',
      () async {
        final tempFile = File(
          '${Directory.systemTemp.path}/voice-send-ready-${DateTime.now().microsecondsSinceEpoch}.m4a',
        );
        addTearDown(() async {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        });

        final recordManager = AudioRecordManager.test(
          recorderRuntime: _FakeAudioRecorderRuntime(
            outputBytes: const <int>[1, 2, 3, 4],
          ),
          requestMicrophonePermission: () async => true,
          buildRecordingPath: () async => tempFile.path,
          progressInterval: const Duration(milliseconds: 20),
        );
        final service = PlatformChatVoiceActionService(
          recordManager: recordManager,
        );
        addTearDown(service.dispose);

        final started = await service.startRecording();
        expect(started, isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 1100));

        final result = await service.stopRecording(shouldSend: true);

        expect(result, isA<ChatVoiceReadyResult>());
        final readyResult = result as ChatVoiceReadyResult;
        expect(readyResult.content.localPath, tempFile.path);
        expect(
          readyResult.duration,
          greaterThanOrEqualTo(const Duration(seconds: 1)),
        );
        expect(
          service.recordingStateListenable.value.phase,
          ChatVoiceRecordingPhase.sendReady,
        );
      },
    );

    test(
      'stopRecording shouldSend true succeeds when recorder already emitted stop before release',
      () async {
        final tempFile = File(
          '${Directory.systemTemp.path}/voice-auto-stop-handoff-${DateTime.now().microsecondsSinceEpoch}.m4a',
        );
        addTearDown(() async {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        });

        final recordManager = AudioRecordManager.test(
          recorderRuntime: _FakeAudioRecorderRuntime(
            outputBytes: const <int>[1, 2, 3, 4],
          ),
          requestMicrophonePermission: () async => true,
          buildRecordingPath: () async => tempFile.path,
          progressInterval: const Duration(milliseconds: 20),
        );
        final service = PlatformChatVoiceActionService(
          recordManager: recordManager,
        );
        addTearDown(service.dispose);

        final started = await service.startRecording();
        expect(started, isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 1100));

        final autoStopResult = await recordManager.stop();
        expect(autoStopResult.error, isNull);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final result = await service.stopRecording(shouldSend: true);

        expect(result, isA<ChatVoiceReadyResult>());
        final readyResult = result as ChatVoiceReadyResult;
        expect(readyResult.content.localPath, tempFile.path);
        expect(
          readyResult.duration,
          greaterThanOrEqualTo(const Duration(seconds: 1)),
        );
        expect(
          service.recordingStateListenable.value.phase,
          ChatVoiceRecordingPhase.sendReady,
        );
      },
    );

    test(
      'stopRecording shouldSend true succeeds when prior stop is still in flight before stop update arrives',
      () async {
        final tempFile = File(
          '${Directory.systemTemp.path}/voice-stop-inflight-handoff-${DateTime.now().microsecondsSinceEpoch}.m4a',
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
        final recordManager = AudioRecordManager.test(
          recorderRuntime: fakeRecorder,
          requestMicrophonePermission: () async => true,
          buildRecordingPath: () async => tempFile.path,
          progressInterval: const Duration(milliseconds: 20),
        );
        final service = PlatformChatVoiceActionService(
          recordManager: recordManager,
        );
        addTearDown(service.dispose);

        final started = await service.startRecording();
        expect(started, isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 1100));

        final firstStopFuture = recordManager.stop();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final result = await service.stopRecording(shouldSend: true);
        final firstStopResult = await firstStopFuture;

        expect(firstStopResult.error, isNull);
        expect(result, isA<ChatVoiceReadyResult>());
        final readyResult = result as ChatVoiceReadyResult;
        expect(readyResult.content.localPath, tempFile.path);
        expect(
          readyResult.duration,
          greaterThanOrEqualTo(const Duration(seconds: 1)),
        );
        expect(fakeRecorder.stopCalls, 1);
      },
    );

    test(
      'stopRecording shouldSend false while startup is in-flight does not leave recorder running',
      () async {
        final tempFile = File(
          '${Directory.systemTemp.path}/voice-stop-false-start-race-${DateTime.now().microsecondsSinceEpoch}.m4a',
        );
        addTearDown(() async {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        });

        final recordManager = AudioRecordManager.test(
          recorderRuntime: _FakeAudioRecorderRuntime(
            startDelay: const Duration(milliseconds: 120),
          ),
          requestMicrophonePermission: () async => true,
          buildRecordingPath: () async => tempFile.path,
          progressInterval: const Duration(milliseconds: 20),
        );
        final service = PlatformChatVoiceActionService(
          recordManager: recordManager,
        );
        addTearDown(service.dispose);

        final startFuture = service.startRecording();
        final stopResult = await service.stopRecording(shouldSend: false);
        await startFuture;
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(stopResult, isA<ChatVoiceDiscardedResult>());
        expect(
          (stopResult as ChatVoiceDiscardedResult).reason,
          ChatVoiceDiscardReason.cancelled,
        );
        expect(
          recordManager.state,
          isNot(anyOf(RecordingState.recording, RecordingState.paused)),
        );
        expect(
          service.recordingStateListenable.value.phase,
          ChatVoiceRecordingPhase.idle,
        );
      },
    );

    test(
      'stopRecording shouldSend true while startup is in-flight resolves to tooShort discard',
      () async {
        final tempFile = File(
          '${Directory.systemTemp.path}/voice-stop-true-start-race-${DateTime.now().microsecondsSinceEpoch}.m4a',
        );
        addTearDown(() async {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        });

        final recordManager = AudioRecordManager.test(
          recorderRuntime: _FakeAudioRecorderRuntime(
            outputBytes: const <int>[1, 2, 3, 4],
            startDelay: const Duration(milliseconds: 120),
          ),
          requestMicrophonePermission: () async => true,
          buildRecordingPath: () async => tempFile.path,
          progressInterval: const Duration(milliseconds: 20),
        );
        final service = PlatformChatVoiceActionService(
          recordManager: recordManager,
        );
        addTearDown(service.dispose);

        final startFuture = service.startRecording();
        final result = await service.stopRecording(shouldSend: true);
        await startFuture;
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(result, isA<ChatVoiceDiscardedResult>());
        expect(
          (result as ChatVoiceDiscardedResult).reason,
          ChatVoiceDiscardReason.tooShort,
        );
        expect(
          recordManager.state,
          isNot(anyOf(RecordingState.recording, RecordingState.paused)),
        );
        expect(
          service.recordingStateListenable.value.phase,
          ChatVoiceRecordingPhase.tooShort,
        );
      },
    );

    test(
      'stopRecording shouldSend true waits for failed startup to resolve and returns permissionDenied discard',
      () async {
        final permissionGate = Completer<void>();
        final recordManager = AudioRecordManager.test(
          recorderRuntime: _FakeAudioRecorderRuntime(),
          requestMicrophonePermission: () async {
            await permissionGate.future;
            return false;
          },
          buildRecordingPath: () async =>
              '${Directory.systemTemp.path}/voice-stop-true-start-denied-${DateTime.now().microsecondsSinceEpoch}.m4a',
          progressInterval: const Duration(milliseconds: 20),
        );
        final service = PlatformChatVoiceActionService(
          recordManager: recordManager,
        );
        addTearDown(service.dispose);

        final startFuture = service.startRecording();
        final stopFuture = service.stopRecording(shouldSend: true);

        await Future<void>.delayed(const Duration(milliseconds: 20));
        permissionGate.complete();

        final started = await startFuture;
        final stopResult = await stopFuture;

        expect(started, isFalse);
        expect(stopResult, isA<ChatVoiceDiscardedResult>());
        expect(
          (stopResult as ChatVoiceDiscardedResult).reason,
          ChatVoiceDiscardReason.permissionDenied,
        );
        expect(
          service.recordingStateListenable.value.phase,
          ChatVoiceRecordingPhase.permissionDenied,
        );
      },
    );

    test(
      'stopRecording shouldSend false returns cancelled discard and goes idle',
      () async {
        final tempFile = File(
          '${Directory.systemTemp.path}/voice-cancel-${DateTime.now().microsecondsSinceEpoch}.m4a',
        );
        addTearDown(() async {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        });

        final recordManager = AudioRecordManager.test(
          recorderRuntime: _FakeAudioRecorderRuntime(),
          requestMicrophonePermission: () async => true,
          buildRecordingPath: () async => tempFile.path,
          progressInterval: const Duration(milliseconds: 20),
        );
        final service = PlatformChatVoiceActionService(
          recordManager: recordManager,
        );
        addTearDown(service.dispose);

        final started = await service.startRecording();
        expect(started, isTrue);

        final result = await service.stopRecording(shouldSend: false);

        expect(result, isA<ChatVoiceDiscardedResult>());
        expect(
          (result as ChatVoiceDiscardedResult).reason,
          ChatVoiceDiscardReason.cancelled,
        );
        expect(
          service.recordingStateListenable.value.phase,
          ChatVoiceRecordingPhase.idle,
        );
      },
    );

    test(
      'stopRecording cancel path deactivates audio session exactly once',
      () async {
        final tempFile = File(
          '${Directory.systemTemp.path}/voice-cancel-single-deactivate-${DateTime.now().microsecondsSinceEpoch}.m4a',
        );
        addTearDown(() async {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        });

        final bridge = _FakeChatAudioSessionBridge();
        final recordManager = AudioRecordManager.test(
          recorderRuntime: _FakeAudioRecorderRuntime(),
          requestMicrophonePermission: () async => true,
          buildRecordingPath: () async => tempFile.path,
          progressInterval: const Duration(milliseconds: 20),
        );
        final service = PlatformChatVoiceActionService(
          recordManager: recordManager,
          audioSessionBridge: bridge,
        );
        addTearDown(service.dispose);

        final started = await service.startRecording();
        expect(started, isTrue);

        final result = await service.stopRecording(shouldSend: false);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(result, isA<ChatVoiceDiscardedResult>());
        expect(bridge.events.where((event) => event == 'deactivate').length, 1);
      },
    );

    test(
      'stopRecording cancel path and cancelRecording are serialized to one runtime cancel',
      () async {
        final tempFile = File(
          '${Directory.systemTemp.path}/voice-cancel-serialize-${DateTime.now().microsecondsSinceEpoch}.m4a',
        );
        addTearDown(() async {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        });

        final bridge = _FakeChatAudioSessionBridge();
        final fakeRecorder = _FakeAudioRecorderRuntime(
          cancelDelay: const Duration(milliseconds: 120),
          failConcurrentCancel: true,
        );
        final recordManager = AudioRecordManager.test(
          recorderRuntime: fakeRecorder,
          requestMicrophonePermission: () async => true,
          buildRecordingPath: () async => tempFile.path,
          progressInterval: const Duration(milliseconds: 20),
        );
        final service = PlatformChatVoiceActionService(
          recordManager: recordManager,
          audioSessionBridge: bridge,
        );
        addTearDown(service.dispose);

        final started = await service.startRecording();
        expect(started, isTrue);

        final discardFuture = service.stopRecording(shouldSend: false);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        final cancelFuture = service.cancelRecording();

        final result = await discardFuture;
        await cancelFuture;
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(result, isA<ChatVoiceDiscardedResult>());
        expect(fakeRecorder.cancelCalls, 1);
        expect(bridge.events.where((event) => event == 'deactivate').length, 1);
        expect(
          service.recordingStateListenable.value.phase,
          ChatVoiceRecordingPhase.idle,
        );
      },
    );

    test('cancelRecording deactivates audio session exactly once', () async {
      final tempFile = File(
        '${Directory.systemTemp.path}/voice-cancel-method-single-deactivate-${DateTime.now().microsecondsSinceEpoch}.m4a',
      );
      addTearDown(() async {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      });

      final bridge = _FakeChatAudioSessionBridge();
      final recordManager = AudioRecordManager.test(
        recorderRuntime: _FakeAudioRecorderRuntime(),
        requestMicrophonePermission: () async => true,
        buildRecordingPath: () async => tempFile.path,
        progressInterval: const Duration(milliseconds: 20),
      );
      final service = PlatformChatVoiceActionService(
        recordManager: recordManager,
        audioSessionBridge: bridge,
      );
      addTearDown(service.dispose);

      final started = await service.startRecording();
      expect(started, isTrue);

      await service.cancelRecording();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bridge.events.where((event) => event == 'deactivate').length, 1);
    });

    test(
      'cancel and immediate restart waits for delayed deactivate before re-activate',
      () async {
        final tempFile = File(
          '${Directory.systemTemp.path}/voice-cancel-restart-deactivate-race-${DateTime.now().microsecondsSinceEpoch}.m4a',
        );
        addTearDown(() async {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        });

        final deactivateGate = Completer<void>();
        final bridge = _FakeChatAudioSessionBridge(
          onDeactivate: () => deactivateGate.future,
        );
        final fakeRecorder = _FakeAudioRecorderRuntime();
        final recordManager = AudioRecordManager.test(
          recorderRuntime: fakeRecorder,
          requestMicrophonePermission: () async => true,
          buildRecordingPath: () async => tempFile.path,
          progressInterval: const Duration(milliseconds: 20),
        );
        final service = PlatformChatVoiceActionService(
          recordManager: recordManager,
          audioSessionBridge: bridge,
        );
        addTearDown(service.dispose);

        final started = await service.startRecording();
        expect(started, isTrue);
        expect(fakeRecorder.startCalls, 1);

        final cancelFuture = service.cancelRecording();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final restartFuture = service.startRecording();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(fakeRecorder.startCalls, 1);

        deactivateGate.complete();
        await cancelFuture;

        final restarted = await restartFuture;
        expect(restarted, isTrue);
        expect(fakeRecorder.startCalls, 2);
      },
    );

    test(
      'stopRecording returns failure when output path exists but file is unavailable',
      () async {
        final tempFile = File(
          '${Directory.systemTemp.path}/voice-unavailable-${DateTime.now().microsecondsSinceEpoch}.m4a',
        );
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

        final recordManager = AudioRecordManager.test(
          recorderRuntime: _FakeAudioRecorderRuntime(writeOutputFile: false),
          requestMicrophonePermission: () async => true,
          buildRecordingPath: () async => tempFile.path,
          progressInterval: const Duration(milliseconds: 20),
        );
        final service = PlatformChatVoiceActionService(
          recordManager: recordManager,
        );
        addTearDown(service.dispose);

        final started = await service.startRecording();
        expect(started, isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 1100));

        final result = await service.stopRecording(shouldSend: true);

        expect(result, isA<ChatVoiceStopFailure>());
        expect(
          service.recordingStateListenable.value.phase,
          ChatVoiceRecordingPhase.sendFailed,
        );
      },
    );
  });
}

class _FakeAudioRecorderRuntime implements AudioRecorderRuntime {
  _FakeAudioRecorderRuntime({
    this.outputBytes = const <int>[0],
    this.writeOutputFile = true,
    this.startDelay = Duration.zero,
    this.stopDelay = Duration.zero,
    this.cancelDelay = Duration.zero,
    this.failConcurrentStop = false,
    this.failConcurrentCancel = false,
    this.startError,
  });

  final List<int> outputBytes;
  final bool writeOutputFile;
  final Duration startDelay;
  final Duration stopDelay;
  final Duration cancelDelay;
  final bool failConcurrentStop;
  final bool failConcurrentCancel;
  final Object? startError;
  int startCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  RecordingConfig? lastStartConfig;
  String? _path;
  bool _stopInFlight = false;
  bool _cancelInFlight = false;

  @override
  Future<void> cancel() async {
    cancelCalls += 1;
    if (_cancelInFlight && failConcurrentCancel) {
      throw StateError('cancel already in flight');
    }
    _cancelInFlight = true;
    try {
      if (cancelDelay > Duration.zero) {
        await Future<void>.delayed(cancelDelay);
      }
      _path = null;
    } finally {
      _cancelInFlight = false;
    }
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<double> amplitude() async => 0.4;

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> start({
    required String path,
    required RecordingConfig config,
  }) async {
    startCalls += 1;
    lastStartConfig = config;
    if (startDelay > Duration.zero) {
      await Future<void>.delayed(startDelay);
    }
    if (startError != null) {
      throw StateError(startError.toString());
    }
    _path = path;
  }

  @override
  Future<String?> stop() async {
    stopCalls += 1;
    if (_stopInFlight && failConcurrentStop) {
      throw StateError('stop already in flight');
    }
    _stopInFlight = true;
    final targetPath = _path;
    try {
      if (stopDelay > Duration.zero) {
        await Future<void>.delayed(stopDelay);
      }
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

class _FakeChatAudioSessionBridge implements ChatAudioSessionBridge {
  _FakeChatAudioSessionBridge({this.onDeactivate});

  final Future<void> Function()? onDeactivate;

  final List<String> events = <String>[];
  final List<bool> speakerphoneStates = <bool>[];

  @override
  Future<void> activate(ChatAudioSessionUseCase useCase) async {
    events.add('activate:${useCase.name}');
  }

  @override
  Future<void> deactivate() async {
    events.add('deactivate');
    if (onDeactivate != null) {
      await onDeactivate!();
    }
  }

  @override
  Future<void> setSpeakerphone(bool enabled) async {
    speakerphoneStates.add(enabled);
  }
}
