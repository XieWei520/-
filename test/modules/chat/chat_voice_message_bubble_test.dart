import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/modules/chat/chat_audio_session_bridge.dart';
import 'package:wukong_im_app/data/models/chat_session.dart';
import 'package:wukong_im_app/modules/chat/chat_message_view_model.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_providers.dart';
import 'package:wukong_im_app/modules/chat/chat_voice_playback_controller.dart';
import 'package:wukong_im_app/modules/chat/widgets/chat_voice_message_bubble.dart';
import 'package:wukong_im_app/wukong_base/utils/audio_record_manager.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_voice_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('ChatVoiceMessageBubble', () {
    const session = ChatSession(
      channelId: 'c_voice',
      channelType: WKChannelType.personal,
    );

    testWidgets('tap toggles play and pause for the same message', (
      tester,
    ) async {
      final runtime = _FakeAudioPlaybackRuntime();
      final playManager = AudioPlayManager.test(playbackRuntime: runtime);
      final controller = _buildTestPlaybackController(playManager: playManager);
      addTearDown(controller.dispose);
      addTearDown(playManager.dispose);

      final model = _buildVoiceModel(
        messageId: 'm_local_toggle',
        localPath: '/tmp/local-toggle.m4a',
      );

      await tester.pumpWidget(
        _buildHarness(
          session: session,
          controller: controller,
          child: ChatVoiceMessageBubble(session: session, model: model),
        ),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('chat-voice-bubble-mid:m_local_toggle'),
        ),
      );
      await _waitForPlaybackStatus(
        tester,
        controller,
        messageId: 'mid:m_local_toggle',
        status: ChatVoicePlaybackStatus.playing,
      );

      expect(controller.state.activeMessageId, 'mid:m_local_toggle');
      expect(
        controller.state.entries['mid:m_local_toggle']?.status,
        ChatVoicePlaybackStatus.playing,
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('chat-voice-bubble-mid:m_local_toggle'),
        ),
      );
      await _waitForPlaybackStatus(
        tester,
        controller,
        messageId: 'mid:m_local_toggle',
        status: ChatVoicePlaybackStatus.paused,
      );

      expect(
        controller.state.entries['mid:m_local_toggle']?.status,
        ChatVoicePlaybackStatus.paused,
      );
      expect(runtime.pauseCalls, 1);
    });

    testWidgets('failed playback remains retryable on the same bubble', (
      tester,
    ) async {
      final runtime = _FakeAudioPlaybackRuntime(failSetSourceCount: 1);
      final playManager = AudioPlayManager.test(playbackRuntime: runtime);
      final controller = _buildTestPlaybackController(playManager: playManager);
      addTearDown(controller.dispose);
      addTearDown(playManager.dispose);

      final model = _buildVoiceModel(
        messageId: 'm_retryable',
        localPath: '/tmp/retryable.m4a',
      );

      await tester.pumpWidget(
        _buildHarness(
          session: session,
          controller: controller,
          child: ChatVoiceMessageBubble(session: session, model: model),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('chat-voice-bubble-mid:m_retryable')),
      );
      await _waitForPlaybackStatus(
        tester,
        controller,
        messageId: 'mid:m_retryable',
        status: ChatVoicePlaybackStatus.failed,
      );

      expect(controller.state.activeMessageId, isNull);
      expect(
        controller.state.entries['mid:m_retryable']?.status,
        ChatVoicePlaybackStatus.failed,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('chat-voice-bubble-mid:m_retryable')),
      );
      await _waitForPlaybackStatus(
        tester,
        controller,
        messageId: 'mid:m_retryable',
        status: ChatVoicePlaybackStatus.playing,
      );

      expect(runtime.setSourceCalls, 2);
      expect(controller.state.activeMessageId, 'mid:m_retryable');
      expect(
        controller.state.entries['mid:m_retryable']?.status,
        ChatVoicePlaybackStatus.playing,
      );
    });

    testWidgets('prefers local file source when local and remote both exist', (
      tester,
    ) async {
      final runtime = _FakeAudioPlaybackRuntime();
      final playManager = AudioPlayManager.test(playbackRuntime: runtime);
      final controller = _buildTestPlaybackController(playManager: playManager);
      addTearDown(controller.dispose);
      addTearDown(playManager.dispose);

      final model = _buildVoiceModel(
        messageId: 'm_local_priority',
        localPath: '/tmp/local-priority.m4a',
        url: 'voices/remote-priority.m4a',
      );

      await tester.pumpWidget(
        _buildHarness(
          session: session,
          controller: controller,
          child: ChatVoiceMessageBubble(session: session, model: model),
        ),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('chat-voice-bubble-mid:m_local_priority'),
        ),
      );
      await _pumpUntil(
        tester,
        description:
            'mid:m_local_priority runtime source to resolve to local file',
        condition: () =>
            runtime.lastSource ==
            const AudioPlaybackSource.file('/tmp/local-priority.m4a'),
      );

      expect(
        runtime.lastSource,
        const AudioPlaybackSource.file('/tmp/local-priority.m4a'),
      );
    });

    testWidgets(
      'fallback retries with remote when local-first playback fails',
      (tester) async {
        final runtime = _FakeAudioPlaybackRuntime(failSetSourceCount: 1);
        final playManager = AudioPlayManager.test(playbackRuntime: runtime);
        final controller = _buildTestPlaybackController(
          playManager: playManager,
        );
        addTearDown(controller.dispose);
        addTearDown(playManager.dispose);

        final model = _buildVoiceModel(
          messageId: 'm_local_fallback',
          localPath: '/tmp/local-fallback.m4a',
          url: 'voices/fallback-remote.m4a',
        );

        await tester.pumpWidget(
          _buildHarness(
            session: session,
            controller: controller,
            child: ChatVoiceMessageBubble(session: session, model: model),
          ),
        );

        await tester.tap(
          find.byKey(
            const ValueKey<String>('chat-voice-bubble-mid:m_local_fallback'),
          ),
        );
        await _waitForPlaybackStatus(
          tester,
          controller,
          messageId: 'mid:m_local_fallback',
          status: ChatVoicePlaybackStatus.playing,
        );

        expect(runtime.setSourceCalls, 2);
        expect(runtime.attemptedSources, <AudioPlaybackSource>[
          const AudioPlaybackSource.file('/tmp/local-fallback.m4a'),
          AudioPlaybackSource.network(
            ApiConfig.resolveMediaUrl('voices/fallback-remote.m4a'),
          ),
        ]);
        expect(controller.state.activeMessageId, 'mid:m_local_fallback');
        expect(
          controller.state.entries['mid:m_local_fallback']?.status,
          ChatVoicePlaybackStatus.playing,
        );
      },
    );

    testWidgets('web prefers remote url when local path is not web-playable', (
      tester,
    ) async {
      final runtime = _FakeAudioPlaybackRuntime();
      final playManager = AudioPlayManager.test(playbackRuntime: runtime);
      final controller = _buildTestPlaybackController(playManager: playManager);
      addTearDown(controller.dispose);
      addTearDown(playManager.dispose);

      final model = _buildVoiceModel(
        messageId: 'm_web_remote_priority',
        localPath: '/tmp/web-local-only.m4a',
        url: 'voices/web-remote-priority.m4a',
      );

      await tester.pumpWidget(
        _buildHarness(
          session: session,
          controller: controller,
          child: ChatVoiceMessageBubble(
            session: session,
            model: model,
            isWebOverride: true,
          ),
        ),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('chat-voice-bubble-mid:m_web_remote_priority'),
        ),
      );
      await _pumpUntil(
        tester,
        description:
            'mid:m_web_remote_priority runtime source to resolve to remote url',
        condition: () =>
            runtime.lastSource ==
            AudioPlaybackSource.network(
              ApiConfig.resolveMediaUrl('voices/web-remote-priority.m4a'),
            ),
      );

      expect(
        runtime.lastSource,
        AudioPlaybackSource.network(
          ApiConfig.resolveMediaUrl('voices/web-remote-priority.m4a'),
        ),
      );
    });

    testWidgets('structured payload url is used when content url is empty', (
      tester,
    ) async {
      final runtime = _FakeAudioPlaybackRuntime();
      final playManager = AudioPlayManager.test(playbackRuntime: runtime);
      final controller = _buildTestPlaybackController(playManager: playManager);
      addTearDown(controller.dispose);
      addTearDown(playManager.dispose);

      final model = _buildVoiceModel(
        messageId: 'm_structured_url',
        structured: const <String, dynamic>{'url': 'media/voice-fallback.m4a'},
      );

      await tester.pumpWidget(
        _buildHarness(
          session: session,
          controller: controller,
          child: ChatVoiceMessageBubble(session: session, model: model),
        ),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('chat-voice-bubble-mid:m_structured_url'),
        ),
      );
      await _pumpUntil(
        tester,
        description:
            'mid:m_structured_url runtime source to resolve to structured payload url',
        condition: () =>
            runtime.lastSource ==
            AudioPlaybackSource.network(
              ApiConfig.resolveMediaUrl('media/voice-fallback.m4a'),
            ),
      );

      expect(
        runtime.lastSource,
        AudioPlaybackSource.network(
          ApiConfig.resolveMediaUrl('media/voice-fallback.m4a'),
        ),
      );
    });

    testWidgets(
      'client key survives server message id assignment during playback',
      (tester) async {
        final runtime = _FakeAudioPlaybackRuntime();
        final playManager = AudioPlayManager.test(playbackRuntime: runtime);
        final controller = _buildTestPlaybackController(
          playManager: playManager,
        );
        addTearDown(controller.dispose);
        addTearDown(playManager.dispose);

        const stableKey = 'cid:client_pending_voice';
        final pendingModel = _buildVoiceModel(
          messageId: '',
          clientMsgNo: 'client_pending_voice',
          identity: stableKey,
          localPath: '/tmp/pending-voice.m4a',
        );

        await tester.pumpWidget(
          _buildHarness(
            session: session,
            controller: controller,
            child: ChatVoiceMessageBubble(
              session: session,
              model: pendingModel,
            ),
          ),
        );

        await tester.tap(
          find.byKey(
            const ValueKey<String>(
              'chat-voice-bubble-cid:client_pending_voice',
            ),
          ),
        );
        await _waitForPlaybackStatus(
          tester,
          controller,
          messageId: stableKey,
          status: ChatVoicePlaybackStatus.playing,
        );

        expect(controller.state.activeMessageId, stableKey);
        expect(
          controller.state.entries[stableKey]?.status,
          ChatVoicePlaybackStatus.playing,
        );

        final syncedModel = _buildVoiceModel(
          messageId: 'm_server_voice',
          clientMsgNo: 'client_pending_voice',
          identity: 'mid:m_server_voice',
          localPath: '/tmp/pending-voice.m4a',
        );

        await tester.pumpWidget(
          _buildHarness(
            session: session,
            controller: controller,
            child: ChatVoiceMessageBubble(session: session, model: syncedModel),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(
            const ValueKey<String>(
              'chat-voice-bubble-cid:client_pending_voice',
            ),
          ),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(
            const ValueKey<String>(
              'chat-voice-bubble-cid:client_pending_voice',
            ),
          ),
        );
        await _waitForPlaybackStatus(
          tester,
          controller,
          messageId: stableKey,
          status: ChatVoicePlaybackStatus.paused,
        );

        expect(runtime.pauseCalls, 1);
        expect(
          controller.state.entries[stableKey]?.status,
          ChatVoicePlaybackStatus.paused,
        );
      },
    );

    testWidgets('unread received voice shows unread indicator', (tester) async {
      final runtime = _FakeAudioPlaybackRuntime();
      final playManager = AudioPlayManager.test(playbackRuntime: runtime);
      final controller = _buildTestPlaybackController(playManager: playManager);
      addTearDown(controller.dispose);
      addTearDown(playManager.dispose);

      final model = _buildVoiceModel(
        messageId: 'm_unread_voice',
        localPath: '/tmp/unread-voice.m4a',
        voiceStatus: 0,
        self: false,
      );

      await tester.pumpWidget(
        _buildHarness(
          session: session,
          controller: controller,
          child: ChatVoiceMessageBubble(session: session, model: model),
        ),
      );

      expect(
        find.byKey(
          const ValueKey<String>(
            'chat-voice-unread-indicator-mid:m_unread_voice',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'self and already-read received voices do not show unread indicator',
      (tester) async {
        final runtime = _FakeAudioPlaybackRuntime();
        final playManager = AudioPlayManager.test(playbackRuntime: runtime);
        final controller = _buildTestPlaybackController(
          playManager: playManager,
        );
        addTearDown(controller.dispose);
        addTearDown(playManager.dispose);

        final selfUnreadModel = _buildVoiceModel(
          messageId: 'm_self_unread_voice',
          localPath: '/tmp/self-unread-voice.m4a',
          voiceStatus: 0,
          self: true,
        );
        final receivedReadModel = _buildVoiceModel(
          messageId: 'm_received_read_voice',
          localPath: '/tmp/received-read-voice.m4a',
          voiceStatus: 1,
          self: false,
        );

        await tester.pumpWidget(
          _buildHarness(
            session: session,
            controller: controller,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ChatVoiceMessageBubble(
                  session: session,
                  model: selfUnreadModel,
                ),
                const SizedBox(height: 8),
                ChatVoiceMessageBubble(
                  session: session,
                  model: receivedReadModel,
                ),
              ],
            ),
          ),
        );

        expect(
          find.byKey(
            const ValueKey<String>(
              'chat-voice-unread-indicator-mid:m_self_unread_voice',
            ),
          ),
          findsNothing,
        );
        expect(
          find.byKey(
            const ValueKey<String>(
              'chat-voice-unread-indicator-mid:m_received_read_voice',
            ),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'long duration bubble stays within constrained chat width across states',
      (tester) async {
        final runtime = _FakeAudioPlaybackRuntime();
        final playManager = AudioPlayManager.test(playbackRuntime: runtime);
        final controller = _buildTestPlaybackController(
          playManager: playManager,
        );
        addTearDown(controller.dispose);
        addTearDown(playManager.dispose);

        final model = _buildVoiceModel(
          messageId: 'm_constrained_long_voice',
          localPath: '/tmp/constrained-long-voice.m4a',
          durationSeconds: 78,
        );
        const bubbleKey = ValueKey<String>(
          'chat-voice-bubble-container-mid:m_constrained_long_voice',
        );
        const constrainedWidth = 208.0;
        const source = AudioPlaybackSource.file(
          '/tmp/constrained-long-voice.m4a',
        );
        const statuses = <ChatVoicePlaybackStatus>[
          ChatVoicePlaybackStatus.playing,
          ChatVoicePlaybackStatus.paused,
          ChatVoicePlaybackStatus.failed,
        ];

        await tester.pumpWidget(
          _buildHarness(
            session: session,
            controller: controller,
            maxBubbleHostWidth: constrainedWidth,
            child: ChatVoiceMessageBubble(session: session, model: model),
          ),
        );

        for (final status in statuses) {
          controller.replaceState(
            ChatVoicePlaybackState(
              activeMessageId: status == ChatVoicePlaybackStatus.failed
                  ? null
                  : 'mid:m_constrained_long_voice',
              entries: <String, ChatVoicePlaybackEntry>{
                'mid:m_constrained_long_voice': ChatVoicePlaybackEntry(
                  messageId: 'mid:m_constrained_long_voice',
                  source: source,
                  status: status,
                  positionMs: 37000,
                  durationMs: 78000,
                ),
              },
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
          expect(tester.getSize(find.byKey(bubbleKey)).width, constrainedWidth);
        }
      },
    );

    testWidgets(
      'longer duration voice uses wider bubble under constrained chat width',
      (tester) async {
        final runtime = _FakeAudioPlaybackRuntime();
        final playManager = AudioPlayManager.test(playbackRuntime: runtime);
        final controller = _buildTestPlaybackController(
          playManager: playManager,
        );
        addTearDown(controller.dispose);
        addTearDown(playManager.dispose);

        final shortModel = _buildVoiceModel(
          messageId: 'm_short_voice',
          localPath: '/tmp/short-voice.m4a',
          durationSeconds: 3,
        );
        final longModel = _buildVoiceModel(
          messageId: 'm_long_voice',
          localPath: '/tmp/long-voice.m4a',
          durationSeconds: 52,
        );

        await tester.pumpWidget(
          _buildHarness(
            session: session,
            controller: controller,
            maxBubbleHostWidth: 240,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ChatVoiceMessageBubble(session: session, model: shortModel),
                const SizedBox(height: 8),
                ChatVoiceMessageBubble(session: session, model: longModel),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        final shortWidth = tester
            .getSize(
              find.byKey(
                const ValueKey<String>(
                  'chat-voice-bubble-container-mid:m_short_voice',
                ),
              ),
            )
            .width;
        final longWidth = tester
            .getSize(
              find.byKey(
                const ValueKey<String>(
                  'chat-voice-bubble-container-mid:m_long_voice',
                ),
              ),
            )
            .width;

        expect(tester.takeException(), isNull);
        expect(longWidth, greaterThan(shortWidth));
        expect(longWidth, lessThanOrEqualTo(240));
      },
    );
  });
}

Future<void> _waitForPlaybackStatus(
  WidgetTester tester,
  ChatVoicePlaybackController controller, {
  required String messageId,
  required ChatVoicePlaybackStatus status,
}) {
  return _pumpUntil(
    tester,
    description: '$messageId status to become $status',
    condition: () => controller.state.entries[messageId]?.status == status,
  );
}

Future<void> _pumpUntil(
  WidgetTester tester, {
  required String description,
  required bool Function() condition,
  Duration timeout = const Duration(seconds: 2),
  Duration step = const Duration(milliseconds: 10),
}) async {
  var pumped = Duration.zero;
  while (!condition()) {
    if (pumped >= timeout) {
      fail(
        'Timed out waiting for $description after pumping '
        '${pumped.inMilliseconds}ms (timeout: ${timeout.inMilliseconds}ms)',
      );
    }
    await tester.pump(step);
    pumped += step;
  }
}

ChatVoicePlaybackController _buildTestPlaybackController({
  required AudioPlayManager playManager,
}) {
  return ChatVoicePlaybackController(
    playManager: playManager,
    audioSessionBridge: const ChatAudioSessionBridgeStub(),
  );
}

Widget _buildHarness({
  required ChatSession session,
  required ChatVoicePlaybackController controller,
  required Widget child,
  double? maxBubbleHostWidth,
}) {
  final body = maxBubbleHostWidth == null
      ? child
      : SizedBox(width: maxBubbleHostWidth, child: child);

  return ProviderScope(
    overrides: [
      chatVoicePlaybackControllerProvider.overrideWith(
        (ref, providedSession) => controller,
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: body),
      ),
    ),
  );
}

ChatMessageViewModel _buildVoiceModel({
  required String messageId,
  String clientMsgNo = '',
  String? identity,
  String localPath = '',
  String url = '',
  int voiceStatus = 1,
  int durationSeconds = 8,
  bool self = false,
  Map<String, dynamic>? structured,
}) {
  final content = WKVoiceContent(durationSeconds)
    ..localPath = localPath
    ..url = url;
  final message = WKMsg()
    ..messageID = messageId
    ..clientMsgNO = clientMsgNo
    ..channelID = 'c_voice'
    ..channelType = WKChannelType.personal
    ..fromUID = self ? 'u_self' : 'u_other'
    ..contentType = WkMessageContentType.voice
    ..messageContent = content
    ..voiceStatus = voiceStatus;

  return ChatMessageViewModel(
    identity: identity ?? 'mid:$messageId',
    message: message,
    preview: '[voice]',
    system: false,
    self: self,
    structured: structured,
    revision: 'r:$messageId',
  );
}

class _FakeAudioPlaybackRuntime implements AudioPlaybackRuntime {
  _FakeAudioPlaybackRuntime({this.failSetSourceCount = 0})
    : _remainingSetSourceFailures = failSetSourceCount;

  final int failSetSourceCount;

  int setSourceCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;
  final List<AudioPlaybackSource> attemptedSources = <AudioPlaybackSource>[];

  int _remainingSetSourceFailures;
  AudioPlaybackSource? lastSource;
  bool _isPlaying = false;
  Duration _position = Duration.zero;

  @override
  Future<void> dispose() async {}

  @override
  Future<Duration> durationValue() async => const Duration(seconds: 8);

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
      _position += const Duration(milliseconds: 160);
    }
    return _position;
  }

  @override
  Future<void> seek(Duration position) async {
    _position = position;
  }

  @override
  Future<void> setSource(AudioPlaybackSource source) async {
    setSourceCalls++;
    attemptedSources.add(source);
    if (_remainingSetSourceFailures > 0) {
      _remainingSetSourceFailures -= 1;
      throw StateError('source failed');
    }
    lastSource = source;
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
