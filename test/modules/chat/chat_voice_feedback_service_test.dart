import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_voice_action_service.dart';
import 'package:wukong_im_app/modules/chat/chat_voice_feedback_service.dart';
import 'package:wukong_im_app/modules/chat/widgets/chat_voice_press_hold_button.dart';
import 'package:wukong_im_app/wukong_base/utils/audio_record_manager.dart';

void main() {
  group('ChatVoiceFeedbackService', () {
    test('maps recordStarted to lightImpact', () async {
      final driver = _FakeChatVoiceFeedbackDriver();
      final service = ChatVoiceFeedbackService(driver: driver);

      await service.handle(ChatVoiceFeedbackEvent.recordStarted);

      expect(driver.calls, <String>['lightImpact']);
    });

    test('maps cancel-zone events to selectionClick', () async {
      final driver = _FakeChatVoiceFeedbackDriver();
      final service = ChatVoiceFeedbackService(driver: driver);

      await service.handle(ChatVoiceFeedbackEvent.enterCancelZone);
      await service.handle(ChatVoiceFeedbackEvent.leaveCancelZone);

      expect(driver.calls, <String>['selectionClick', 'selectionClick']);
    });

    test('maps sendReady to playSendCue', () async {
      final driver = _FakeChatVoiceFeedbackDriver();
      final service = ChatVoiceFeedbackService(driver: driver);

      await service.handle(ChatVoiceFeedbackEvent.sendReady);

      expect(driver.calls, <String>['playSendCue']);
    });

    test('maps tooShort and sendFailed to playErrorCue', () async {
      final driver = _FakeChatVoiceFeedbackDriver();
      final service = ChatVoiceFeedbackService(driver: driver);

      await service.handle(ChatVoiceFeedbackEvent.tooShort);
      await service.handle(ChatVoiceFeedbackEvent.sendFailed);

      expect(driver.calls, <String>['playErrorCue', 'playErrorCue']);
    });
  });

  group('PlatformChatVoiceActionService feedback hooks', () {
    test('emits recordStarted feedback when recording begins', () async {
      final tempFile = File(
        '${Directory.systemTemp.path}/voice-feedback-start-${DateTime.now().microsecondsSinceEpoch}.m4a',
      );
      addTearDown(() async {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      });

      final driver = _FakeChatVoiceFeedbackDriver();
      final recordManager = AudioRecordManager.test(
        recorderRuntime: _FakeAudioRecorderRuntime(),
        requestMicrophonePermission: () async => true,
        buildRecordingPath: () async => tempFile.path,
      );
      final service = PlatformChatVoiceActionService(
        recordManager: recordManager,
        feedbackService: ChatVoiceFeedbackService(driver: driver),
      );
      addTearDown(service.dispose);

      final started = await service.startRecording();

      expect(started, isTrue);
      expect(driver.calls, <String>['lightImpact']);
    });

    test('emits error feedback when stop resolves as tooShort', () async {
      final tempFile = File(
        '${Directory.systemTemp.path}/voice-feedback-too-short-${DateTime.now().microsecondsSinceEpoch}.m4a',
      );
      addTearDown(() async {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      });

      final driver = _FakeChatVoiceFeedbackDriver();
      final recordManager = AudioRecordManager.test(
        recorderRuntime: _FakeAudioRecorderRuntime(),
        requestMicrophonePermission: () async => true,
        buildRecordingPath: () async => tempFile.path,
        progressInterval: const Duration(milliseconds: 20),
      );
      final service = PlatformChatVoiceActionService(
        recordManager: recordManager,
        feedbackService: ChatVoiceFeedbackService(driver: driver),
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
      expect(driver.calls, <String>['lightImpact', 'playErrorCue']);
    });

    test(
      'thrown start still returns failed result and allows retry start',
      () async {
        final recordManager = _ThrowingStartAudioRecordManager();
        final service = PlatformChatVoiceActionService(
          recordManager: recordManager,
          feedbackService: ChatVoiceFeedbackService.noop(),
        );
        addTearDown(service.dispose);

        final firstStarted = await service.startRecording();
        final firstState = service.recordingStateListenable.value;

        expect(firstStarted, isFalse);
        expect(firstState.phase, ChatVoiceRecordingPhase.sendFailed);
        expect(firstState.errorMessage, contains('synthetic start throw'));

        final secondStarted = await service.startRecording();

        expect(secondStarted, isTrue);
        expect(recordManager.startCalls, 2);
      },
    );

    test('sync feedback failures do not bubble out of startRecording', () async {
      final tempFile = File(
        '${Directory.systemTemp.path}/voice-feedback-sync-failure-${DateTime.now().microsecondsSinceEpoch}.m4a',
      );
      addTearDown(() async {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      });

      final driver = _ConfigurableFeedbackDriver(throwSyncOnLightImpact: true);
      final recordManager = AudioRecordManager.test(
        recorderRuntime: _FakeAudioRecorderRuntime(),
        requestMicrophonePermission: () async => true,
        buildRecordingPath: () async => tempFile.path,
      );
      final service = PlatformChatVoiceActionService(
        recordManager: recordManager,
        feedbackService: ChatVoiceFeedbackService(driver: driver),
      );
      addTearDown(service.dispose);

      final started = await service.startRecording();

      expect(started, isTrue);
      expect(
        service.recordingStateListenable.value.phase,
        ChatVoiceRecordingPhase.recording,
      );
    });

    test(
      'async feedback failures do not bubble out of tooShort stop flow',
      () async {
        final tempFile = File(
          '${Directory.systemTemp.path}/voice-feedback-async-failure-${DateTime.now().microsecondsSinceEpoch}.m4a',
        );
        addTearDown(() async {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        });

        final driver = _ConfigurableFeedbackDriver(failAsyncOnErrorCue: true);
        final recordManager = AudioRecordManager.test(
          recorderRuntime: _FakeAudioRecorderRuntime(),
          requestMicrophonePermission: () async => true,
          buildRecordingPath: () async => tempFile.path,
          progressInterval: const Duration(milliseconds: 20),
        );
        final service = PlatformChatVoiceActionService(
          recordManager: recordManager,
          feedbackService: ChatVoiceFeedbackService(driver: driver),
        );
        addTearDown(service.dispose);

        final started = await service.startRecording();
        expect(started, isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 120));

        final result = await service.stopRecording(shouldSend: true);
        await Future<void>.delayed(Duration.zero);

        expect(result, isA<ChatVoiceDiscardedResult>());
        expect(
          (result as ChatVoiceDiscardedResult).reason,
          ChatVoiceDiscardReason.tooShort,
        );
      },
    );
  });

  group('ChatVoicePressHoldButton feedback boundary semantics', () {
    testWidgets(
      'release reset does not emit leaveCancelZone without move exit',
      (tester) async {
        final feedbackEvents = <ChatVoiceFeedbackEvent>[];
        final zoneChanges = <bool>[];
        bool? releasedInCancelZone;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatVoicePressHoldButton(
                isRecording: true,
                cancelTriggerDistance: 48,
                onHoldStart: () async {},
                onCancelZoneChanged: zoneChanges.add,
                onFeedbackEvent: feedbackEvents.add,
                onHoldRelease: (isInCancelZone) async {
                  releasedInCancelZone = isInCancelZone;
                },
                onHoldAbort: () async {},
              ),
            ),
          ),
        );

        final gesture = await _startLongPressOnButton(tester);
        await gesture.moveBy(const Offset(0, -80));
        await tester.pump();

        await gesture.up();
        await tester.pump();

        expect(releasedInCancelZone, isTrue);
        expect(zoneChanges, <bool>[true]);
        expect(feedbackEvents, <ChatVoiceFeedbackEvent>[
          ChatVoiceFeedbackEvent.enterCancelZone,
        ]);
      },
    );

    testWidgets('abort reset does not emit leaveCancelZone without move exit', (
      tester,
    ) async {
      final feedbackEvents = <ChatVoiceFeedbackEvent>[];
      final zoneChanges = <bool>[];
      var abortCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatVoicePressHoldButton(
              isRecording: true,
              cancelTriggerDistance: 48,
              onHoldStart: () async {},
              onCancelZoneChanged: zoneChanges.add,
              onFeedbackEvent: feedbackEvents.add,
              onHoldRelease: (_) async {},
              onHoldAbort: () async {
                abortCount += 1;
              },
            ),
          ),
        ),
      );

      final gesture = await _startLongPressOnButton(tester);
      await gesture.moveBy(const Offset(0, -80));
      await tester.pump();

      await gesture.cancel();
      await tester.pump();

      expect(abortCount, 1);
      expect(zoneChanges, <bool>[true]);
      expect(feedbackEvents, <ChatVoiceFeedbackEvent>[
        ChatVoiceFeedbackEvent.enterCancelZone,
      ]);
    });

    testWidgets('move exit emits leaveCancelZone once', (tester) async {
      final feedbackEvents = <ChatVoiceFeedbackEvent>[];
      final zoneChanges = <bool>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatVoicePressHoldButton(
              isRecording: true,
              cancelTriggerDistance: 48,
              onHoldStart: () async {},
              onCancelZoneChanged: zoneChanges.add,
              onFeedbackEvent: feedbackEvents.add,
              onHoldRelease: (_) async {},
              onHoldAbort: () async {},
            ),
          ),
        ),
      );

      final gesture = await _startLongPressOnButton(tester);
      await gesture.moveBy(const Offset(0, -80));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 100));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(zoneChanges, <bool>[true, false]);
      expect(feedbackEvents, <ChatVoiceFeedbackEvent>[
        ChatVoiceFeedbackEvent.enterCancelZone,
        ChatVoiceFeedbackEvent.leaveCancelZone,
      ]);
    });
  });
}

class _FakeChatVoiceFeedbackDriver implements ChatVoiceFeedbackDriver {
  final List<String> calls = <String>[];

  @override
  Future<void> lightImpact() async {
    calls.add('lightImpact');
  }

  @override
  Future<void> playErrorCue() async {
    calls.add('playErrorCue');
  }

  @override
  Future<void> playSendCue() async {
    calls.add('playSendCue');
  }

  @override
  Future<void> selectionClick() async {
    calls.add('selectionClick');
  }
}

class _ConfigurableFeedbackDriver implements ChatVoiceFeedbackDriver {
  _ConfigurableFeedbackDriver({
    this.throwSyncOnLightImpact = false,
    this.failAsyncOnErrorCue = false,
  });

  final bool throwSyncOnLightImpact;
  final bool failAsyncOnErrorCue;

  @override
  Future<void> lightImpact() {
    if (throwSyncOnLightImpact) {
      throw StateError('sync lightImpact failure');
    }
    return Future<void>.value();
  }

  @override
  Future<void> playErrorCue() {
    if (failAsyncOnErrorCue) {
      return Future<void>.error(StateError('async playErrorCue failure'));
    }
    return Future<void>.value();
  }

  @override
  Future<void> playSendCue() => Future<void>.value();

  @override
  Future<void> selectionClick() => Future<void>.value();
}

class _FakeAudioRecorderRuntime implements AudioRecorderRuntime {
  _FakeAudioRecorderRuntime();

  String? _path;

  @override
  Future<void> cancel() async {
    _path = null;
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
    _path = path;
  }

  @override
  Future<String?> stop() async {
    final targetPath = _path;
    if (targetPath == null) {
      return null;
    }
    final file = File(targetPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(const <int>[0], flush: true);
    return targetPath;
  }
}

class _ThrowingStartAudioRecordManager implements AudioRecordManager {
  _ThrowingStartAudioRecordManager();

  final StreamController<RecordingUpdate> _recordingController =
      StreamController<RecordingUpdate>.broadcast();
  RecordingState _state = RecordingState.idle;
  int startCalls = 0;

  @override
  int get currentDuration => 0;

  @override
  Stream<RecordingUpdate> get recordingStream => _recordingController.stream;

  @override
  RecordingState get state => _state;

  @override
  Future<void> cancel() async {
    _state = RecordingState.idle;
    _recordingController.add(RecordingUpdate(type: RecordingUpdateType.cancel));
  }

  @override
  void dispose() {
    if (!_recordingController.isClosed) {
      _recordingController.close();
    }
  }

  @override
  double getAmplitude() => 0.0;

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  void setConfig(RecordingConfig config) {}

  @override
  Future<bool> start() async {
    startCalls += 1;
    if (startCalls == 1) {
      throw StateError('synthetic start throw');
    }
    _state = RecordingState.recording;
    _recordingController.add(RecordingUpdate(type: RecordingUpdateType.start));
    return true;
  }

  @override
  Future<RecordingResult> stop() async {
    _state = RecordingState.idle;
    return RecordingResult(
      filePath: '',
      duration: 0,
      fileSize: 0,
      error: 'Not recording',
    );
  }
}

Future<TestGesture> _startLongPressOnButton(WidgetTester tester) async {
  final finder = find.byType(ChatVoicePressHoldButton);
  final center = tester.getCenter(finder);
  final gesture = await tester.startGesture(center);
  await tester.pump(const Duration(milliseconds: 700));
  return gesture;
}
