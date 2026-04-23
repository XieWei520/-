import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_flame_message_runtime.dart';
import 'package:wukong_im_app/modules/chat/chat_audio_session_bridge.dart';
import 'package:wukong_im_app/modules/chat/chat_voice_playback_controller.dart';
import 'package:wukong_im_app/wukong_base/utils/audio_record_manager.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_voice_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('ChatVoicePlaybackController', () {
    test(
      'toggle enforces single active message and pauses/resumes same message',
      () async {
        final runtime = _FakeAudioPlaybackRuntime(
          duration: const Duration(seconds: 5),
        );
        final playManager = AudioPlayManager.test(
          playbackRuntime: runtime,
          progressInterval: const Duration(milliseconds: 100),
        );
        final controller = ChatVoicePlaybackController(
          playManager: playManager,
        );
        addTearDown(controller.dispose);
        addTearDown(playManager.dispose);

        const firstSource = AudioPlaybackSource.file('/tmp/voice-1.m4a');
        const secondSource = AudioPlaybackSource.file('/tmp/voice-2.m4a');

        await controller.toggle(messageId: 'm1', source: firstSource);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(controller.state.activeMessageId, 'm1');
        expect(
          controller.state.entries['m1']?.status,
          ChatVoicePlaybackStatus.playing,
        );

        await controller.toggle(messageId: 'm1', source: firstSource);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(controller.state.activeMessageId, 'm1');
        expect(
          controller.state.entries['m1']?.status,
          ChatVoicePlaybackStatus.paused,
        );
        expect(runtime.pauseCalls, 1);

        await controller.toggle(messageId: 'm1', source: firstSource);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(controller.state.activeMessageId, 'm1');
        expect(
          controller.state.entries['m1']?.status,
          ChatVoicePlaybackStatus.playing,
        );
        expect(runtime.setSourceCalls, 1);

        await controller.toggle(messageId: 'm2', source: secondSource);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(runtime.stopCalls, 1);
        expect(runtime.setSourceCalls, 2);
        expect(controller.state.activeMessageId, 'm2');
        expect(
          controller.state.entries['m1']?.status,
          ChatVoicePlaybackStatus.idle,
        );
        expect(controller.state.entries['m1']?.positionMs, 0);
        expect(
          controller.state.entries['m2']?.status,
          ChatVoicePlaybackStatus.playing,
        );
      },
    );

    test(
      'toggle waits for playback audio session activation before play starts',
      () async {
        final activationGate = Completer<void>();
        final bridge = _FakeChatAudioSessionBridge(
          onActivate: (ChatAudioSessionUseCase useCase) {
            if (useCase != ChatAudioSessionUseCase.playback) {
              return Future<void>.value();
            }
            return activationGate.future;
          },
        );
        final runtime = _FakeAudioPlaybackRuntime(
          duration: const Duration(seconds: 5),
        );
        final playManager = AudioPlayManager.test(playbackRuntime: runtime);
        final controller = ChatVoicePlaybackController(
          playManager: playManager,
          audioSessionBridge: bridge,
        );
        addTearDown(controller.dispose);
        addTearDown(playManager.dispose);

        const source = AudioPlaybackSource.file('/tmp/voice-activation.m4a');
        final toggleFuture = controller.toggle(
          messageId: 'm_activation',
          source: source,
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(bridge.events, <String>['activate:playback']);
        expect(runtime.setSourceCalls, 0);

        activationGate.complete();
        await toggleFuture;
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(runtime.setSourceCalls, 1);
        expect(
          controller.state.entries['m_activation']?.status,
          ChatVoicePlaybackStatus.playing,
        );
      },
    );

    test('playback stop deactivates audio session', () async {
      final bridge = _FakeChatAudioSessionBridge();
      final runtime = _FakeAudioPlaybackRuntime(
        duration: const Duration(seconds: 5),
      );
      final playManager = AudioPlayManager.test(playbackRuntime: runtime);
      final controller = ChatVoicePlaybackController(
        playManager: playManager,
        audioSessionBridge: bridge,
      );
      addTearDown(controller.dispose);
      addTearDown(playManager.dispose);

      const source = AudioPlaybackSource.file('/tmp/voice-stop.m4a');
      await controller.toggle(messageId: 'm_stop', source: source);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await playManager.stop();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        bridge.events,
        containsAllInOrder(<String>['activate:playback', 'deactivate']),
      );
    });

    test('playback error deactivates audio session', () async {
      final bridge = _FakeChatAudioSessionBridge();
      final runtime = _FakeAudioPlaybackRuntime(
        duration: const Duration(seconds: 5),
        failSetSourceCount: 1,
      );
      final playManager = AudioPlayManager.test(playbackRuntime: runtime);
      final controller = ChatVoicePlaybackController(
        playManager: playManager,
        audioSessionBridge: bridge,
      );
      addTearDown(controller.dispose);
      addTearDown(playManager.dispose);

      const source = AudioPlaybackSource.file('/tmp/voice-error.m4a');
      await controller.toggle(messageId: 'm_error', source: source);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        bridge.events,
        containsAllInOrder(<String>['activate:playback', 'deactivate']),
      );
      expect(
        controller.state.entries['m_error']?.status,
        ChatVoicePlaybackStatus.failed,
      );
    });

    test('dispose deactivates active playback audio session', () async {
      final bridge = _FakeChatAudioSessionBridge();
      final runtime = _FakeAudioPlaybackRuntime(
        duration: const Duration(seconds: 5),
      );
      final playManager = AudioPlayManager.test(playbackRuntime: runtime);
      final controller = ChatVoicePlaybackController(
        playManager: playManager,
        audioSessionBridge: bridge,
      );
      addTearDown(playManager.dispose);

      const source = AudioPlaybackSource.file('/tmp/voice-dispose.m4a');
      await controller.toggle(messageId: 'm_dispose_bridge', source: source);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      controller.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        bridge.events,
        containsAllInOrder(<String>['activate:playback', 'deactivate']),
      );
    });

    test(
      'stale old terminal playback events do not deactivate current active session',
      () async {
        final bridge = _FakeChatAudioSessionBridge();
        final runtime = _FakeAudioPlaybackRuntime(
          duration: const Duration(seconds: 5),
        );
        final playManager = AudioPlayManager.test(playbackRuntime: runtime);
        final controller = ChatVoicePlaybackController(
          playManager: playManager,
          audioSessionBridge: bridge,
        );
        addTearDown(controller.dispose);
        addTearDown(playManager.dispose);

        const newSource = AudioPlaybackSource.file('/tmp/voice-current.m4a');
        const oldSource = AudioPlaybackSource.file('/tmp/voice-stale.m4a');
        await controller.toggle(messageId: 'm_current', source: newSource);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        controller.replaceState(
          ChatVoicePlaybackState(
            activeMessageId: 'm_current',
            entries: <String, ChatVoicePlaybackEntry>{
              ...controller.state.entries,
              'm_stale': const ChatVoicePlaybackEntry(
                messageId: 'm_stale',
                source: oldSource,
                status: ChatVoicePlaybackStatus.playing,
                positionMs: 800,
                durationMs: 5000,
              ),
            },
          ),
        );

        controller.debugSetPendingStopMessageId('m_stale');
        controller.debugHandlePlaybackUpdate(
          PlaybackUpdate(
            type: PlaybackUpdateType.stop,
            source: oldSource,
            filePath: oldSource.value,
            position: 0,
            duration: 0,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        controller.debugSetPendingStopMessageId('m_stale');
        controller.debugHandlePlaybackUpdate(
          PlaybackUpdate(
            type: PlaybackUpdateType.error,
            source: oldSource,
            error: 'stale stop failed',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(controller.state.activeMessageId, 'm_current');
        expect(
          controller.state.entries['m_current']?.status,
          ChatVoicePlaybackStatus.playing,
        );
        expect(bridge.events.where((event) => event == 'deactivate'), isEmpty);
      },
    );

    test(
      'activate success with speakerphone failure still deactivates on stop',
      () async {
        final bridge = _FakeChatAudioSessionBridge(
          onSetSpeakerphone: (bool enabled) async {
            throw StateError('speaker route unavailable');
          },
        );
        final runtime = _FakeAudioPlaybackRuntime(
          duration: const Duration(seconds: 5),
        );
        final playManager = AudioPlayManager.test(playbackRuntime: runtime);
        final controller = ChatVoicePlaybackController(
          playManager: playManager,
          audioSessionBridge: bridge,
        );
        addTearDown(controller.dispose);
        addTearDown(playManager.dispose);

        const source = AudioPlaybackSource.file('/tmp/voice-route-fail.m4a');
        await controller.toggle(messageId: 'm_route_fail', source: source);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        await playManager.stop();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(
          bridge.events,
          containsAllInOrder(<String>['activate:playback', 'deactivate']),
        );
      },
    );

    test(
      'delayed deactivate during switch does not drop immediate next toggle session',
      () async {
        final deactivateGate = Completer<void>();
        final bridge = _FakeChatAudioSessionBridge(
          onDeactivate: () => deactivateGate.future,
        );
        final runtime = _FakeAudioPlaybackRuntime(
          duration: const Duration(seconds: 5),
        );
        final playManager = AudioPlayManager.test(playbackRuntime: runtime);
        final controller = ChatVoicePlaybackController(
          playManager: playManager,
          audioSessionBridge: bridge,
        );
        addTearDown(controller.dispose);
        addTearDown(playManager.dispose);

        const first = AudioPlaybackSource.file('/tmp/voice-delay-1.m4a');
        const second = AudioPlaybackSource.file('/tmp/voice-delay-2.m4a');
        const third = AudioPlaybackSource.file('/tmp/voice-delay-3.m4a');

        await controller.toggle(messageId: 'm_delay_1', source: first);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(runtime.setSourceCalls, 1);

        final secondToggle = controller.toggle(
          messageId: 'm_delay_2',
          source: second,
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(runtime.setSourceCalls, 1);

        final thirdToggle = controller.toggle(
          messageId: 'm_delay_3',
          source: third,
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(runtime.setSourceCalls, 1);

        deactivateGate.complete();
        await Future.wait(<Future<void>>[secondToggle, thirdToggle]);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(runtime.setSourceCalls, 3);
        expect(controller.state.activeMessageId, 'm_delay_3');
        expect(
          controller.state.entries['m_delay_3']?.status,
          ChatVoicePlaybackStatus.playing,
        );
      },
    );

    test(
      'toggle marks foreign unread voice as read once before playback',
      () async {
        final runtime = _FakeAudioPlaybackRuntime(
          duration: const Duration(seconds: 5),
        );
        final playManager = AudioPlayManager.test(playbackRuntime: runtime);
        final voiceReadReporter = _FakeChatVoiceReadReporter();
        final controller = ChatVoicePlaybackController(
          playManager: playManager,
          voiceReadReporter: voiceReadReporter,
        );
        addTearDown(controller.dispose);
        addTearDown(playManager.dispose);
        final message = WKMsg()
          ..messageID = 'mid-voice-read'
          ..clientMsgNO = 'client-voice-read'
          ..channelID = 'u_other'
          ..channelType = WKChannelType.personal
          ..fromUID = 'u_other'
          ..contentType = WkMessageContentType.voice
          ..voiceStatus = 0
          ..messageContent = (WKVoiceContent(5)..url = 'media/voice-read.amr');

        await controller.toggle(
          messageId: 'mid-voice-read',
          source: const AudioPlaybackSource.network(
            'https://example.com/media/voice-read.amr',
          ),
          message: message,
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(message.voiceStatus, 1);
        expect(voiceReadReporter.calls, <String>[
          'mid-voice-read|client-voice-read',
        ]);

        await controller.toggle(
          messageId: 'mid-voice-read',
          source: const AudioPlaybackSource.network(
            'https://example.com/media/voice-read.amr',
          ),
          message: message,
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(voiceReadReporter.calls, <String>[
          'mid-voice-read|client-voice-read',
        ]);
      },
    );

    test(
      'toggle marks flame voice viewed once and keeps ttl at least voice duration',
      () async {
        final runtime = _FakeAudioPlaybackRuntime(
          duration: const Duration(seconds: 8),
        );
        final playManager = AudioPlayManager.test(playbackRuntime: runtime);
        final flameStore = _FakeFlameMessageStore();
        final scheduledDeletes = <Duration>[];
        final keepAliveTimers = <Timer>[];
        final flameRuntime = ChatFlameMessageRuntime(
          store: flameStore,
          now: () => DateTime.fromMillisecondsSinceEpoch(5_000),
          createTimer: (duration, callback) {
            scheduledDeletes.add(duration);
            final timer = Timer(const Duration(days: 1), () {});
            keepAliveTimers.add(timer);
            return timer;
          },
        );
        final controller = ChatVoicePlaybackController(
          playManager: playManager,
          flameRuntime: flameRuntime,
        );
        addTearDown(() {
          for (final timer in keepAliveTimers) {
            timer.cancel();
          }
        });
        addTearDown(controller.dispose);
        addTearDown(playManager.dispose);

        final message = WKMsg()
          ..messageID = 'mid-flame-voice'
          ..clientMsgNO = 'client-flame-voice'
          ..channelID = 'u_other'
          ..channelType = WKChannelType.personal
          ..fromUID = 'u_other'
          ..contentType = WkMessageContentType.voice
          ..flame = 1
          ..flameSecond = 5
          ..messageContent = (WKVoiceContent(8)..url = 'media/flame-voice.amr');
        flameStore.seed(message);

        await controller.toggle(
          messageId: 'mid-flame-voice',
          source: const AudioPlaybackSource.network(
            'https://example.com/media/flame-voice.amr',
          ),
          message: message,
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(message.viewed, 1);
        expect(message.viewedAt, 5_000);
        expect(flameStore.updatedViewedAt, <String, int>{
          'client-flame-voice': 5_000,
        });
        expect(scheduledDeletes, const <Duration>[Duration(seconds: 8)]);

        await controller.toggle(
          messageId: 'mid-flame-voice',
          source: const AudioPlaybackSource.network(
            'https://example.com/media/flame-voice.amr',
          ),
          message: message,
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(flameStore.updatedViewedAt, <String, int>{
          'client-flame-voice': 5_000,
        });
      },
    );

    test(
      'toggle ignores flame viewed persistence failure after playback starts',
      () async {
        final printed = <String>[];
        final originalDebugPrint = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) {
          if (message != null) {
            printed.add(message);
          }
        };
        addTearDown(() {
          debugPrint = originalDebugPrint;
        });
        final runtime = _FakeAudioPlaybackRuntime(
          duration: const Duration(seconds: 8),
        );
        final playManager = AudioPlayManager.test(playbackRuntime: runtime);
        final flameStore = _FakeFlameMessageStore(throwOnUpdateViewedAt: true);
        final flameRuntime = ChatFlameMessageRuntime(
          store: flameStore,
          now: () => DateTime.fromMillisecondsSinceEpoch(5_000),
        );
        final controller = ChatVoicePlaybackController(
          playManager: playManager,
          flameRuntime: flameRuntime,
        );
        addTearDown(controller.dispose);
        addTearDown(playManager.dispose);

        final message = WKMsg()
          ..messageID = 'mid-flame-voice-persist-fail'
          ..clientMsgNO = 'client-flame-voice-persist-fail'
          ..channelID = 'u_other'
          ..channelType = WKChannelType.personal
          ..fromUID = 'u_other'
          ..contentType = WkMessageContentType.voice
          ..flame = 1
          ..flameSecond = 5
          ..messageContent = (WKVoiceContent(8)
            ..url = 'media/flame-voice-fail.amr');
        flameStore.seed(message);

        await expectLater(
          controller.toggle(
            messageId: 'mid-flame-voice-persist-fail',
            source: const AudioPlaybackSource.network(
              'https://example.com/media/flame-voice-fail.amr',
            ),
            message: message,
          ),
          completes,
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(flameStore.updateViewedAtCalls, 1);
        expect(runtime.setSourceCalls, 1);
        expect(
          controller.state.activeMessageId,
          'mid-flame-voice-persist-fail',
        );
        expect(
          controller.state.entries['mid-flame-voice-persist-fail']?.status,
          ChatVoicePlaybackStatus.playing,
        );
        expect(
          printed.any(
            (message) => message.contains(
              'flame viewed persistence failed messageId=mid-flame-voice-persist-fail',
            ),
          ),
          isTrue,
        );
      },
    );

    test(
      'slow flame viewed persistence does not block subsequent toggles after playback starts',
      () async {
        final persistGate = Completer<void>();
        final runtime = _FakeAudioPlaybackRuntime(
          duration: const Duration(seconds: 8),
        );
        final playManager = AudioPlayManager.test(playbackRuntime: runtime);
        final flameStore = _FakeFlameMessageStore(
          onUpdateViewedAt: () => persistGate.future,
        );
        final flameRuntime = ChatFlameMessageRuntime(
          store: flameStore,
          now: () => DateTime.fromMillisecondsSinceEpoch(8_000),
        );
        final controller = ChatVoicePlaybackController(
          playManager: playManager,
          flameRuntime: flameRuntime,
        );
        addTearDown(controller.dispose);
        addTearDown(playManager.dispose);
        addTearDown(() {
          if (!persistGate.isCompleted) {
            persistGate.complete();
          }
        });

        final flameMessage = WKMsg()
          ..messageID = 'mid-flame-voice-slow'
          ..clientMsgNO = 'client-flame-voice-slow'
          ..channelID = 'u_other'
          ..channelType = WKChannelType.personal
          ..fromUID = 'u_other'
          ..contentType = WkMessageContentType.voice
          ..flame = 1
          ..flameSecond = 5
          ..messageContent = (WKVoiceContent(8)
            ..url = 'media/flame-voice-slow.amr');
        flameStore.seed(flameMessage);

        final firstToggle = controller.toggle(
          messageId: 'mid-flame-voice-slow',
          source: const AudioPlaybackSource.network(
            'https://example.com/media/flame-voice-slow.amr',
          ),
          message: flameMessage,
        );
        var attempts = 0;
        while (flameStore.updateViewedAtCalls == 0 && attempts < 40) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          attempts += 1;
        }
        expect(flameStore.updateViewedAtCalls, 1);

        final secondToggle = controller.toggle(
          messageId: 'm_after_slow_flame',
          source: const AudioPlaybackSource.file('/tmp/voice-next.m4a'),
        );

        await expectLater(
          secondToggle.timeout(const Duration(milliseconds: 300)),
          completes,
        );
        persistGate.complete();
        await firstToggle;
        await secondToggle;
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(controller.state.activeMessageId, 'm_after_slow_flame');
        expect(
          controller.state.entries['m_after_slow_flame']?.status,
          ChatVoicePlaybackStatus.playing,
        );
      },
    );

    test(
      'playback failure leaves the message retryable instead of stuck loading',
      () async {
        final runtime = _FakeAudioPlaybackRuntime(
          failSetSourceCount: 1,
          duration: const Duration(seconds: 2),
        );
        final playManager = AudioPlayManager.test(playbackRuntime: runtime);
        final controller = ChatVoicePlaybackController(
          playManager: playManager,
        );
        addTearDown(controller.dispose);
        addTearDown(playManager.dispose);

        const source = AudioPlaybackSource.network(
          'https://example.com/voice/retryable.mp3',
        );

        await controller.toggle(messageId: 'm_fail', source: source);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(controller.state.activeMessageId, isNull);
        expect(
          controller.state.entries['m_fail']?.status,
          ChatVoicePlaybackStatus.failed,
        );
        expect(runtime.setSourceCalls, 1);

        await controller.toggle(messageId: 'm_fail', source: source);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(runtime.setSourceCalls, 2);
        expect(controller.state.activeMessageId, 'm_fail');
        expect(
          controller.state.entries['m_fail']?.status,
          ChatVoicePlaybackStatus.playing,
        );
      },
    );

    test(
      'toggle retries with fallback source when primary source fails',
      () async {
        const primarySource = AudioPlaybackSource.file('/tmp/local-first.m4a');
        const fallbackSource = AudioPlaybackSource.network(
          'https://example.com/voice/local-first-fallback.mp3',
        );
        final runtime = _FakeAudioPlaybackRuntime(
          duration: const Duration(seconds: 2),
          delayedSourceFailures: <String>{primarySource.value},
        );
        final playManager = AudioPlayManager.test(playbackRuntime: runtime);
        final controller = ChatVoicePlaybackController(
          playManager: playManager,
        );
        addTearDown(controller.dispose);
        addTearDown(playManager.dispose);

        await controller.toggle(
          messageId: 'm_fallback_success',
          source: primarySource,
          fallbackSource: fallbackSource,
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(runtime.setSourceCalls, 2);
        expect(controller.state.activeMessageId, 'm_fallback_success');
        expect(
          controller.state.entries['m_fallback_success']?.status,
          ChatVoicePlaybackStatus.playing,
        );
        expect(
          controller.state.entries['m_fallback_success']?.source,
          fallbackSource,
        );
      },
    );

    test(
      'toggle marks failed when both primary and fallback sources fail',
      () async {
        const primarySource = AudioPlaybackSource.file('/tmp/local-first.m4a');
        const fallbackSource = AudioPlaybackSource.network(
          'https://example.com/voice/local-first-fallback.mp3',
        );
        final runtime = _FakeAudioPlaybackRuntime(
          duration: const Duration(seconds: 2),
          delayedSourceFailures: <String>{
            primarySource.value,
            fallbackSource.value,
          },
        );
        final playManager = AudioPlayManager.test(playbackRuntime: runtime);
        final controller = ChatVoicePlaybackController(
          playManager: playManager,
        );
        addTearDown(controller.dispose);
        addTearDown(playManager.dispose);

        await controller.toggle(
          messageId: 'm_fallback_fail',
          source: primarySource,
          fallbackSource: fallbackSource,
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(runtime.setSourceCalls, 2);
        expect(controller.state.activeMessageId, isNull);
        expect(
          controller.state.entries['m_fallback_fail']?.status,
          ChatVoicePlaybackStatus.failed,
        );
      },
    );

    test(
      'active ownership stays on latest message when two messages share same source',
      () async {
        final runtime = _FakeAudioPlaybackRuntime(
          duration: const Duration(seconds: 4),
        );
        final playManager = AudioPlayManager.test(
          playbackRuntime: runtime,
          progressInterval: const Duration(milliseconds: 100),
        );
        final controller = ChatVoicePlaybackController(
          playManager: playManager,
        );
        addTearDown(controller.dispose);
        addTearDown(playManager.dispose);

        const sharedSource = AudioPlaybackSource.network(
          'https://example.com/shared-voice.mp3',
        );

        await controller.toggle(messageId: 'm1', source: sharedSource);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(controller.state.activeMessageId, 'm1');
        expect(
          controller.state.entries['m1']?.status,
          ChatVoicePlaybackStatus.playing,
        );

        await controller.toggle(messageId: 'm2', source: sharedSource);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(controller.state.activeMessageId, 'm2');
        expect(
          controller.state.entries['m2']?.status,
          ChatVoicePlaybackStatus.playing,
        );
        expect(
          controller.state.entries['m1']?.status,
          ChatVoicePlaybackStatus.idle,
        );
      },
    );

    test(
      'late stop error from previous owner does not mark new active message as failed',
      () async {
        final runtime = _FakeAudioPlaybackRuntime(
          duration: const Duration(seconds: 4),
          failStopCount: 1,
        );
        final playManager = AudioPlayManager.test(
          playbackRuntime: runtime,
          progressInterval: const Duration(milliseconds: 100),
        );
        final controller = ChatVoicePlaybackController(
          playManager: playManager,
        );
        addTearDown(controller.dispose);
        addTearDown(playManager.dispose);

        const firstSource = AudioPlaybackSource.file('/tmp/voice-switch-1.m4a');
        const secondSource = AudioPlaybackSource.file(
          '/tmp/voice-switch-2.m4a',
        );

        await controller.toggle(messageId: 'm1', source: firstSource);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await controller.toggle(messageId: 'm2', source: secondSource);
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(runtime.stopCalls, 1);
        expect(controller.state.activeMessageId, 'm2');
        expect(
          controller.state.entries['m2']?.status,
          ChatVoicePlaybackStatus.playing,
        );
        expect(
          controller.state.entries['m1']?.status,
          ChatVoicePlaybackStatus.idle,
        );
      },
    );

    test('dispose while playing stops underlying playback runtime', () async {
      final runtime = _FakeAudioPlaybackRuntime(
        duration: const Duration(seconds: 4),
      );
      final playManager = AudioPlayManager.test(
        playbackRuntime: runtime,
        progressInterval: const Duration(milliseconds: 100),
      );
      final controller = ChatVoicePlaybackController(playManager: playManager);
      addTearDown(playManager.dispose);

      const source = AudioPlaybackSource.file('/tmp/dispose-stop.m4a');
      await controller.toggle(messageId: 'm_dispose', source: source);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.state.activeMessageId, 'm_dispose');
      expect(runtime.stopCalls, 0);

      controller.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(runtime.stopCalls, greaterThanOrEqualTo(1));
    });

    test(
      'rapid switch ignores stale play failure from previous message operation',
      () async {
        final runtime = _FakeAudioPlaybackRuntime(
          duration: const Duration(seconds: 4),
          delayedSourceFailures: <String>{'/tmp/race-old.m4a'},
          setSourceDelays: <String, Duration>{
            '/tmp/race-old.m4a': const Duration(milliseconds: 80),
          },
        );
        final playManager = AudioPlayManager.test(
          playbackRuntime: runtime,
          progressInterval: const Duration(milliseconds: 100),
        );
        final controller = ChatVoicePlaybackController(
          playManager: playManager,
        );
        addTearDown(controller.dispose);
        addTearDown(playManager.dispose);

        const firstSource = AudioPlaybackSource.file('/tmp/race-old.m4a');
        const secondSource = AudioPlaybackSource.file('/tmp/race-new.m4a');

        final firstToggle = controller.toggle(
          messageId: 'm_old',
          source: firstSource,
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await controller.toggle(messageId: 'm_new', source: secondSource);
        await firstToggle;
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(controller.state.activeMessageId, 'm_new');
        expect(
          controller.state.entries['m_new']?.status,
          ChatVoicePlaybackStatus.playing,
        );
      },
    );

    test('three overlapping toggles keep the newest message active', () async {
      final runtime = _FakeAudioPlaybackRuntime(
        duration: const Duration(seconds: 4),
        setSourceDelays: <String, Duration>{
          '/tmp/overlap-1.m4a': const Duration(milliseconds: 80),
          '/tmp/overlap-2.m4a': const Duration(milliseconds: 80),
        },
      );
      final playManager = AudioPlayManager.test(
        playbackRuntime: runtime,
        progressInterval: const Duration(milliseconds: 100),
      );
      final controller = ChatVoicePlaybackController(playManager: playManager);
      addTearDown(controller.dispose);
      addTearDown(playManager.dispose);

      const firstSource = AudioPlaybackSource.file('/tmp/overlap-1.m4a');
      const secondSource = AudioPlaybackSource.file('/tmp/overlap-2.m4a');
      const thirdSource = AudioPlaybackSource.file('/tmp/overlap-3.m4a');

      final firstToggle = controller.toggle(
        messageId: 'm_overlap_1',
        source: firstSource,
      );
      final secondToggle = controller.toggle(
        messageId: 'm_overlap_2',
        source: secondSource,
      );
      final thirdToggle = controller.toggle(
        messageId: 'm_overlap_3',
        source: thirdSource,
      );
      await Future.wait(<Future<void>>[firstToggle, secondToggle, thirdToggle]);
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(controller.state.activeMessageId, 'm_overlap_3');
      expect(
        controller.state.entries['m_overlap_1']?.status,
        ChatVoicePlaybackStatus.idle,
      );
      expect(
        controller.state.entries['m_overlap_2']?.status,
        ChatVoicePlaybackStatus.idle,
      );
      expect(
        controller.state.entries['m_overlap_3']?.status,
        ChatVoicePlaybackStatus.playing,
      );
    });

    test(
      'same-message double tap while loading does not duplicate play',
      () async {
        const source = AudioPlaybackSource.file('/tmp/loading-guard.m4a');
        final runtime = _FakeAudioPlaybackRuntime(
          duration: const Duration(seconds: 4),
          setSourceDelays: <String, Duration>{
            source.value: const Duration(milliseconds: 80),
          },
        );
        final playManager = AudioPlayManager.test(
          playbackRuntime: runtime,
          progressInterval: const Duration(milliseconds: 100),
        );
        final controller = ChatVoicePlaybackController(
          playManager: playManager,
        );
        addTearDown(controller.dispose);
        addTearDown(playManager.dispose);

        final firstToggle = controller.toggle(
          messageId: 'm_loading',
          source: source,
        );
        final secondToggle = controller.toggle(
          messageId: 'm_loading',
          source: source,
        );
        await Future.wait(<Future<void>>[firstToggle, secondToggle]);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(runtime.setSourceCalls, 1);
        expect(controller.state.activeMessageId, 'm_loading');
        expect(
          controller.state.entries['m_loading']?.status,
          ChatVoicePlaybackStatus.playing,
        );
      },
    );

    test(
      'older fallback error cannot mark newer active message as failed',
      () async {
        const oldPrimary = AudioPlaybackSource.file('/tmp/old-primary.m4a');
        const oldFallback = AudioPlaybackSource.file('/tmp/old-fallback.m4a');
        const newSource = AudioPlaybackSource.file('/tmp/new-active.m4a');
        final runtime = _FakeAudioPlaybackRuntime(
          duration: const Duration(seconds: 4),
          setSourceDelays: <String, Duration>{
            oldPrimary.value: const Duration(milliseconds: 60),
            oldFallback.value: const Duration(milliseconds: 60),
          },
          delayedSourceFailures: <String>{oldPrimary.value, oldFallback.value},
        );
        final playManager = AudioPlayManager.test(
          playbackRuntime: runtime,
          progressInterval: const Duration(milliseconds: 100),
        );
        final controller = ChatVoicePlaybackController(
          playManager: playManager,
        );
        addTearDown(controller.dispose);
        addTearDown(playManager.dispose);

        final observedNewStatuses = <ChatVoicePlaybackStatus>[];
        void listener() {
          final status = controller.state.entries['m_new_active']?.status;
          if (status != null) {
            observedNewStatuses.add(status);
          }
        }

        controller.addListener(listener);
        addTearDown(() => controller.removeListener(listener));

        final firstToggle = controller.toggle(
          messageId: 'm_old_fallback',
          source: oldPrimary,
          fallbackSource: oldFallback,
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));
        final secondToggle = controller.toggle(
          messageId: 'm_new_active',
          source: newSource,
        );

        await Future.wait(<Future<void>>[firstToggle, secondToggle]);
        await Future<void>.delayed(const Duration(milliseconds: 140));

        expect(controller.state.activeMessageId, 'm_new_active');
        expect(
          controller.state.entries['m_new_active']?.status,
          ChatVoicePlaybackStatus.playing,
        );
        expect(
          observedNewStatuses,
          isNot(contains(ChatVoicePlaybackStatus.failed)),
        );
      },
    );

    test(
      'disposing one default controller does not stop another session ownership',
      () async {
        final firstController = ChatVoicePlaybackController();
        final secondController = ChatVoicePlaybackController();
        addTearDown(secondController.dispose);

        const source = AudioPlaybackSource.file('/tmp/session-2-active.m4a');
        secondController.replaceState(
          ChatVoicePlaybackState(
            activeMessageId: 'm_session_2',
            entries: <String, ChatVoicePlaybackEntry>{
              'm_session_2': const ChatVoicePlaybackEntry(
                messageId: 'm_session_2',
                source: source,
                status: ChatVoicePlaybackStatus.playing,
                positionMs: 500,
                durationMs: 2000,
              ),
            },
          ),
        );

        firstController.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(secondController.state.activeMessageId, 'm_session_2');
        expect(
          secondController.state.entries['m_session_2']?.status,
          ChatVoicePlaybackStatus.playing,
        );
      },
    );
  });
}

class _FakeAudioPlaybackRuntime implements AudioPlaybackRuntime {
  _FakeAudioPlaybackRuntime({
    this.duration = const Duration(seconds: 1),
    this.failSetSourceCount = 0,
    this.failStopCount = 0,
    this.setSourceDelays = const <String, Duration>{},
    this.delayedSourceFailures = const <String>{},
  }) : _remainingSetSourceFailures = failSetSourceCount,
       _remainingStopFailures = failStopCount;

  final Duration duration;
  final int failSetSourceCount;
  final int failStopCount;
  final Map<String, Duration> setSourceDelays;
  final Set<String> delayedSourceFailures;

  int setSourceCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;
  int seekCalls = 0;
  int disposeCalls = 0;

  int _remainingSetSourceFailures;
  int _remainingStopFailures;
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
    final delay = setSourceDelays[source.value];
    if (delay != null && delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (_remainingSetSourceFailures > 0) {
      _remainingSetSourceFailures -= 1;
      throw StateError('source failed');
    }
    if (delayedSourceFailures.contains(source.value)) {
      throw StateError('source failed');
    }
    _position = Duration.zero;
    _isPlaying = false;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    if (_remainingStopFailures > 0) {
      _remainingStopFailures -= 1;
      throw StateError('stop failed');
    }
    _isPlaying = false;
    _position = Duration.zero;
  }
}

class _FakeChatVoiceReadReporter implements ChatVoiceReadReporter {
  final List<String> calls = <String>[];

  @override
  Future<void> markVoiceRead(WKMsg message) async {
    calls.add('${message.messageID}|${message.clientMsgNO}');
  }
}

class _FakeFlameMessageStore implements ChatFlameMessageStore {
  _FakeFlameMessageStore({
    this.throwOnUpdateViewedAt = false,
    this.onUpdateViewedAt,
  });

  final Map<String, WKMsg> _messages = <String, WKMsg>{};
  final Map<String, int> updatedViewedAt = <String, int>{};
  final bool throwOnUpdateViewedAt;
  final Future<void> Function()? onUpdateViewedAt;
  int updateViewedAtCalls = 0;

  void seed(WKMsg message) {
    _messages[message.clientMsgNO] = message;
  }

  @override
  Future<void> deleteWithClientMsgNo(String clientMsgNo) async {
    _messages.remove(clientMsgNo);
  }

  @override
  WKMsg? findByClientMsgNo(String clientMsgNo) {
    return _messages[clientMsgNo];
  }

  @override
  Future<List<WKMsg>> getWithFlame() async {
    return _messages.values
        .where((message) => isFlameMessage(message))
        .toList(growable: false);
  }

  @override
  Future<void> updateViewedAt(String clientMsgNo, int viewedAtMs) async {
    updateViewedAtCalls += 1;
    if (onUpdateViewedAt != null) {
      await onUpdateViewedAt!();
    }
    if (throwOnUpdateViewedAt) {
      throw StateError('persist viewedAt failed');
    }
    updatedViewedAt[clientMsgNo] = viewedAtMs;
    final message = _messages[clientMsgNo];
    if (message == null) {
      return;
    }
    message
      ..viewed = 1
      ..viewedAt = viewedAtMs;
  }
}

class _FakeChatAudioSessionBridge implements ChatAudioSessionBridge {
  _FakeChatAudioSessionBridge({
    this.onActivate,
    this.onDeactivate,
    this.onSetSpeakerphone,
  });

  final Future<void> Function(ChatAudioSessionUseCase useCase)? onActivate;
  final Future<void> Function()? onDeactivate;
  final Future<void> Function(bool enabled)? onSetSpeakerphone;

  final List<String> events = <String>[];
  final List<bool> speakerphoneStates = <bool>[];

  @override
  Future<void> activate(ChatAudioSessionUseCase useCase) async {
    events.add('activate:${useCase.name}');
    if (onActivate != null) {
      await onActivate!(useCase);
    }
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
    if (onSetSpeakerphone != null) {
      await onSetSpeakerphone!(enabled);
    }
  }
}
