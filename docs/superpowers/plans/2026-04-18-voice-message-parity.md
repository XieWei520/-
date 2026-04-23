# WuKongIM Voice Message Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade WuKongIM press-to-talk voice messaging from a feature-complete baseline into a production-grade IM voice experience with stronger feedback, smaller payloads, lower playback latency, and better device adaptation.

**Architecture:** Keep the current chat voice split between action service, overlay, message bubble, playback controller, and audio runtime, but add two missing layers: a small feedback domain for record/play cues and an audio-session bridge for device/focus policy. Then tighten recording config, local-first playback, and voice-bubble UI around those shared primitives.

**Tech Stack:** Flutter, Dart, Riverpod, record, video_player, audioplayers, platform channels for mobile audio session routing, existing WuKongIM message APIs and voice tests.

---

## Delivery Order

Ship in three waves instead of one merge:

1. **Wave 1: Fast product feel wins**
   - haptic and cue feedback
   - countdown warning
   - local-first playback policy
   - bubble unread/play polish
2. **Wave 2: Performance hardening**
   - IM-tuned recording bitrate/sample rate
   - download-before-play fallback
   - richer playback statuses and retries
3. **Wave 3: Native parity**
   - audio focus policy
   - speaker/earpiece routing
   - proximity sensor behavior

## File Map

### Existing Flutter files to modify

- Modify: `lib/modules/chat/chat_voice_action_service.dart`
- Modify: `lib/modules/chat/chat_voice_playback_controller.dart`
- Modify: `lib/modules/chat/widgets/chat_voice_press_hold_button.dart`
- Modify: `lib/modules/chat/widgets/chat_voice_record_overlay.dart`
- Modify: `lib/modules/chat/widgets/chat_voice_message_bubble.dart`
- Modify: `lib/wukong_base/utils/audio_record_manager.dart`

### New Flutter files to create

- Create: `lib/modules/chat/chat_voice_feedback_service.dart`
- Create: `lib/modules/chat/chat_audio_session_bridge.dart`
- Create: `lib/modules/chat/chat_audio_session_bridge_stub.dart`
- Create: `lib/modules/chat/chat_audio_session_bridge_mobile.dart`

### Existing tests to extend

- Modify: `test/modules/chat/chat_voice_action_service_test.dart`
- Modify: `test/modules/chat/chat_voice_message_bubble_test.dart`
- Modify: `test/modules/chat/chat_voice_playback_controller_test.dart`
- Modify: `test/modules/chat/chat_voice_record_overlay_test.dart`

### New tests to create

- Create: `test/modules/chat/chat_voice_feedback_service_test.dart`
- Create: `test/wukong_base/utils/audio_record_manager_test.dart`

## Task 1: Introduce voice feedback cues for press-to-talk

**Files:**
- Create: `lib/modules/chat/chat_voice_feedback_service.dart`
- Modify: `lib/modules/chat/widgets/chat_voice_press_hold_button.dart`
- Modify: `lib/modules/chat/chat_voice_action_service.dart`
- Test: `test/modules/chat/chat_voice_feedback_service_test.dart`

- [ ] **Step 1: Write the failing feedback-service test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_voice_feedback_service.dart';

void main() {
  test('maps record events to haptic and cue actions', () async {
    final driver = FakeChatVoiceFeedbackDriver();
    final service = ChatVoiceFeedbackService(driver: driver);

    await service.handle(ChatVoiceFeedbackEvent.recordStarted);
    await service.handle(ChatVoiceFeedbackEvent.enterCancelZone);
    await service.handle(ChatVoiceFeedbackEvent.sendReady);

    expect(
      driver.log,
      <String>[
        'haptic:light',
        'haptic:selection',
        'cue:send',
      ],
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/modules/chat/chat_voice_feedback_service_test.dart`

Expected: fail because `ChatVoiceFeedbackService` and its driver types do not exist yet.

- [ ] **Step 3: Implement a small feedback domain**

```dart
enum ChatVoiceFeedbackEvent {
  recordStarted,
  enterCancelZone,
  leaveCancelZone,
  sendReady,
  tooShort,
  sendFailed,
}

abstract class ChatVoiceFeedbackDriver {
  Future<void> lightImpact();
  Future<void> selectionClick();
  Future<void> playSendCue();
  Future<void> playErrorCue();
}

class ChatVoiceFeedbackService {
  ChatVoiceFeedbackService({required ChatVoiceFeedbackDriver driver})
      : _driver = driver;

  final ChatVoiceFeedbackDriver _driver;

  Future<void> handle(ChatVoiceFeedbackEvent event) async {
    switch (event) {
      case ChatVoiceFeedbackEvent.recordStarted:
        await _driver.lightImpact();
        break;
      case ChatVoiceFeedbackEvent.enterCancelZone:
        await _driver.selectionClick();
        break;
      case ChatVoiceFeedbackEvent.leaveCancelZone:
        break;
      case ChatVoiceFeedbackEvent.sendReady:
        await _driver.playSendCue();
        break;
      case ChatVoiceFeedbackEvent.tooShort:
      case ChatVoiceFeedbackEvent.sendFailed:
        await _driver.playErrorCue();
        break;
    }
  }
}
```

- [ ] **Step 4: Wire the feedback service into the existing record flow**

Target integration points:

```dart
// chat_voice_press_hold_button.dart
void _handleHoldStart(LongPressStartDetails details) {
  _startGlobalPosition = details.globalPosition;
  _setHoldingState(value: true, inCancelZone: false, notify: true);
  unawaited(widget.onHoldStart());
}

// chat_voice_action_service.dart
if (started) {
  unawaited(_feedbackService.handle(ChatVoiceFeedbackEvent.recordStarted));
}

if (duration < _minSendDuration) {
  unawaited(_feedbackService.handle(ChatVoiceFeedbackEvent.tooShort));
}
```

- [ ] **Step 5: Run the feedback-service test again**

Run: `flutter test test/modules/chat/chat_voice_feedback_service_test.dart`

Expected: PASS

## Task 2: Add countdown warning and richer overlay state

**Files:**
- Modify: `lib/modules/chat/chat_voice_action_service.dart`
- Modify: `lib/modules/chat/widgets/chat_voice_record_overlay.dart`
- Test: `test/modules/chat/chat_voice_action_service_test.dart`
- Test: `test/modules/chat/chat_voice_record_overlay_test.dart`

- [ ] **Step 1: Extend the failing overlay test**

Add this widget test:

```dart
testWidgets('ChatVoiceRecordOverlay shows countdown warning in final seconds', (
  tester,
) async {
  const state = ChatVoiceRecordingState(
    phase: ChatVoiceRecordingPhase.recording,
    duration: Duration(seconds: 53),
    countdownSeconds: 7,
    waveformSamples: <double>[0.2, 0.3, 0.4],
  );

  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(body: ChatVoiceRecordOverlay(state: state)),
    ),
  );

  expect(find.text('00:53'), findsOneWidget);
  expect(find.text('7s left'), findsOneWidget);
});
```

- [ ] **Step 2: Extend the failing action-service test**

Add this unit test:

```dart
test('recording state enters countdown window near max duration', () async {
  final recordManager = AudioRecordManager.test(
    recorderRuntime: _FakeAudioRecorderRuntime(),
    requestMicrophonePermission: () async => true,
    buildRecordingPath: () async => '${Directory.systemTemp.path}/voice-countdown.m4a',
    progressInterval: const Duration(milliseconds: 20),
  );
  final service = PlatformChatVoiceActionService(recordManager: recordManager);
  addTearDown(service.dispose);

  await service.startRecording();
  service.debugHandleRecordingUpdateForTest(
    const RecordingUpdate(
      type: RecordingUpdateType.progress,
      duration: 53,
      amplitude: 0.4,
    ),
  );

  expect(service.recordingStateListenable.value.countdownSeconds, 7);
});
```

- [ ] **Step 3: Expand `ChatVoiceRecordingState` with countdown fields**

```dart
class ChatVoiceRecordingState {
  const ChatVoiceRecordingState({
    required this.phase,
    this.duration = Duration.zero,
    this.amplitudeLevel = 0.0,
    this.waveformSamples = const <double>[],
    this.countdownSeconds,
    this.errorMessage,
  });

  final int? countdownSeconds;

  bool get isInCountdownWindow =>
      countdownSeconds != null && countdownSeconds! > 0;
}
```

- [ ] **Step 4: Populate countdown state from the record service and render it**

Target logic:

```dart
static const Duration _maxSendDuration = Duration(seconds: 60);
static const Duration _countdownWindow = Duration(seconds: 10);

int? _resolveCountdown(Duration duration) {
  final remaining = _maxSendDuration - duration;
  if (remaining > _countdownWindow || remaining <= Duration.zero) {
    return null;
  }
  return remaining.inSeconds;
}
```

Overlay target:

```dart
final countdownLabel = state.isInCountdownWindow
    ? '${state.countdownSeconds}s left'
    : null;
```

- [ ] **Step 5: Run the two tests**

Run: `flutter test test/modules/chat/chat_voice_action_service_test.dart`

Expected: PASS

Run: `flutter test test/modules/chat/chat_voice_record_overlay_test.dart`

Expected: PASS

## Task 3: Retune recorder config for IM payload size and add runtime tests

**Files:**
- Modify: `lib/wukong_base/utils/audio_record_manager.dart`
- Modify: `lib/modules/chat/chat_voice_action_service.dart`
- Create: `test/wukong_base/utils/audio_record_manager_test.dart`

- [ ] **Step 1: Write the failing recorder-config test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_base/utils/audio_record_manager.dart';

void main() {
  test('medium quality uses IM-tuned sample rate and bitrate', () {
    const config = RecordingConfig(quality: RecordingQuality.medium);

    expect(config.sampleRate, 16000);
    expect(config.bitRate, 32000);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/wukong_base/utils/audio_record_manager_test.dart`

Expected: fail because medium quality is still configured for `44100 / 64000`.

- [ ] **Step 3: Change the default recording profile**

```dart
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
```

- [ ] **Step 4: Keep the action service pinned to the new medium profile**

```dart
_recordManager.setConfig(
  const RecordingConfig(
    quality: RecordingQuality.medium,
    maxDuration: 60,
    minDuration: 1,
  ),
);
```

- [ ] **Step 5: Run the recorder-config test again**

Run: `flutter test test/wukong_base/utils/audio_record_manager_test.dart`

Expected: PASS

## Task 4: Make playback local-first and add download-before-play fallback

**Files:**
- Modify: `lib/modules/chat/widgets/chat_voice_message_bubble.dart`
- Modify: `lib/modules/chat/chat_voice_playback_controller.dart`
- Modify: `lib/wukong_base/utils/audio_record_manager.dart`
- Test: `test/modules/chat/chat_voice_message_bubble_test.dart`
- Test: `test/modules/chat/chat_voice_playback_controller_test.dart`

- [ ] **Step 1: Flip the failing widget test to the desired policy**

Replace the current Windows-specific expectation with:

```dart
testWidgets('local path wins over remote url when both exist', (tester) async {
  final runtime = _FakeAudioPlaybackRuntime();
  final playManager = AudioPlayManager.test(playbackRuntime: runtime);
  final controller = ChatVoicePlaybackController(playManager: playManager);
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
    find.byKey(const ValueKey<String>('chat-voice-bubble-mid:m_local_priority')),
  );
  await tester.pump(const Duration(milliseconds: 20));

  expect(
    runtime.lastSource,
    const AudioPlaybackSource.file('/tmp/local-priority.m4a'),
  );
});
```

- [ ] **Step 2: Add the failing controller test for missing local file fallback**

```dart
test('missing local voice falls back to remote source once', () async {
  final runtime = _FakeAudioPlaybackRuntime(
    failFileSourcePaths: <String>{'/tmp/missing.m4a'},
    duration: const Duration(seconds: 4),
  );
  final playManager = AudioPlayManager.test(playbackRuntime: runtime);
  final controller = ChatVoicePlaybackController(playManager: playManager);
  addTearDown(controller.dispose);
  addTearDown(playManager.dispose);

  await controller.toggle(
    messageId: 'm_missing',
    source: const AudioPlaybackSource.file('/tmp/missing.m4a'),
    fallbackSource: const AudioPlaybackSource.network('https://example.com/voice.m4a'),
  );

  expect(runtime.setSourceCalls, 2);
  expect(runtime.lastSource, const AudioPlaybackSource.network('https://example.com/voice.m4a'));
});
```

- [ ] **Step 3: Remove remote-first desktop policy from the bubble**

Target change:

```dart
if (localPath.isNotEmpty) {
  return AudioPlaybackSource.file(localPath);
}

if (remoteUrl.isNotEmpty) {
  return AudioPlaybackSource.network(ApiConfig.resolveMediaUrl(remoteUrl));
}
```

- [ ] **Step 4: Teach the playback controller about an optional fallback source**

Target signature:

```dart
Future<void> toggle({
  required String messageId,
  required AudioPlaybackSource source,
  AudioPlaybackSource? fallbackSource,
  WKMsg? message,
})
```

Retry target:

```dart
try {
  await _playManager.play(source);
} catch (_) {
  if (fallbackSource != null) {
    await _playManager.play(fallbackSource);
  } else {
    rethrow;
  }
}
```

- [ ] **Step 5: Run playback widget and controller tests**

Run: `flutter test test/modules/chat/chat_voice_message_bubble_test.dart`

Expected: PASS

Run: `flutter test test/modules/chat/chat_voice_playback_controller_test.dart`

Expected: PASS

## Task 5: Upgrade voice bubble UX with unread state, animated playback, and width scaling

**Files:**
- Modify: `lib/modules/chat/widgets/chat_voice_message_bubble.dart`
- Test: `test/modules/chat/chat_voice_message_bubble_test.dart`

- [ ] **Step 1: Add the failing widget test for unread indicator and width growth**

```dart
testWidgets('unread received voice shows indicator and longer audio uses wider bubble', (
  tester,
) async {
  final shortModel = _buildVoiceModel(messageId: 'm_short', seconds: 3, voiceStatus: 0);
  final longModel = _buildVoiceModel(messageId: 'm_long', seconds: 18, voiceStatus: 0);

  await tester.pumpWidget(
    _buildBubbleComparisonHarness(shortModel: shortModel, longModel: longModel),
  );

  final shortWidth = tester.getSize(find.byKey(const ValueKey('chat-voice-bubble-mid:m_short'))).width;
  final longWidth = tester.getSize(find.byKey(const ValueKey('chat-voice-bubble-mid:m_long'))).width;

  expect(find.byKey(const ValueKey('chat-voice-unread-mid:m_short')), findsOneWidget);
  expect(longWidth, greaterThan(shortWidth));
});
```

- [ ] **Step 2: Run the widget test to verify it fails**

Run: `flutter test test/modules/chat/chat_voice_message_bubble_test.dart`

Expected: fail because the unread marker and width scaling do not exist yet.

- [ ] **Step 3: Add duration-based width and an unread marker**

Target shape:

```dart
final width = lerpDouble(96, 188, (durationMs / 20000).clamp(0.0, 1.0))!;

SizedBox(
  width: width,
  child: Stack(
    clipBehavior: Clip.none,
    children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: highlightColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, size: 20, color: foregroundColor),
            const SizedBox(width: 8),
            LineWaveVoiceView(
              samples: samples,
              color: waveColor,
              isActive: isPlaying || isPaused,
              maxHeight: 18,
            ),
            const SizedBox(width: 8),
            Text(displayLabel, style: textStyle),
          ],
        ),
      ),
      if (!model.isSelf && model.message.voiceStatus == 0)
        Positioned(
          right: -6,
          top: 4,
          child: Container(
            key: ValueKey('chat-voice-unread-$messageKey'),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFFF5A5A),
              shape: BoxShape.circle,
            ),
          ),
        ),
    ],
  ),
)
```

- [ ] **Step 4: Animate the waveform only while the message is actively playing**

```dart
final samples = isPlaying
    ? _animatedSamples(positionMs: positionMs, durationMs: durationMs)
    : _idleSamples(durationMs: durationMs);
```

- [ ] **Step 5: Run the widget test again**

Run: `flutter test test/modules/chat/chat_voice_message_bubble_test.dart`

Expected: PASS

## Task 6: Add an audio-session bridge for focus and route control

**Files:**
- Create: `lib/modules/chat/chat_audio_session_bridge.dart`
- Create: `lib/modules/chat/chat_audio_session_bridge_stub.dart`
- Create: `lib/modules/chat/chat_audio_session_bridge_mobile.dart`
- Modify: `lib/wukong_base/utils/audio_record_manager.dart`
- Modify: `lib/modules/chat/chat_voice_playback_controller.dart`
- Test: `test/modules/chat/chat_voice_playback_controller_test.dart`

- [ ] **Step 1: Write the failing playback-controller test for session lifecycle**

```dart
test('playback acquires and releases audio session around active voice', () async {
  final runtime = _FakeAudioPlaybackRuntime(duration: const Duration(seconds: 2));
  final playManager = AudioPlayManager.test(playbackRuntime: runtime);
  final bridge = FakeChatAudioSessionBridge();
  final controller = ChatVoicePlaybackController(
    playManager: playManager,
    audioSessionBridge: bridge,
  );
  addTearDown(controller.dispose);
  addTearDown(playManager.dispose);

  await controller.toggle(
    messageId: 'm_focus',
    source: const AudioPlaybackSource.file('/tmp/focus.m4a'),
  );
  await Future<void>.delayed(const Duration(milliseconds: 20));
  await playManager.stop();

  expect(bridge.log, <String>['activate:playback', 'deactivate']);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/modules/chat/chat_voice_playback_controller_test.dart`

Expected: fail because there is no audio-session bridge in the controller.

- [ ] **Step 3: Add a small bridge abstraction**

```dart
enum ChatAudioSessionUseCase { record, playback }

abstract class ChatAudioSessionBridge {
  Future<void> activate(ChatAudioSessionUseCase useCase);
  Future<void> deactivate();
  Future<void> setSpeakerphone(bool enabled);
}
```

- [ ] **Step 4: Integrate bridge activation into record and playback flows**

Target usage:

```dart
await _audioSessionBridge.activate(ChatAudioSessionUseCase.record);
final started = await _recordManager.start();
if (!started) {
  await _audioSessionBridge.deactivate();
}

await _audioSessionBridge.activate(ChatAudioSessionUseCase.playback);
await _playManager.play(source);
```

- [ ] **Step 5: Run the playback-controller test again**

Run: `flutter test test/modules/chat/chat_voice_playback_controller_test.dart`

Expected: PASS

## Verification Sweep

- [ ] Run: `flutter test test/modules/chat/chat_voice_feedback_service_test.dart`
- [ ] Run: `flutter test test/wukong_base/utils/audio_record_manager_test.dart`
- [ ] Run: `flutter test test/modules/chat/chat_voice_action_service_test.dart`
- [ ] Run: `flutter test test/modules/chat/chat_voice_record_overlay_test.dart`
- [ ] Run: `flutter test test/modules/chat/chat_voice_message_bubble_test.dart`
- [ ] Run: `flutter test test/modules/chat/chat_voice_playback_controller_test.dart`

Expected result: all targeted voice-message tests pass, and the product behavior changes are limited to press-to-talk voice messaging instead of unrelated chat surfaces.

## Rollout Notes

- Gate Wave 1 behind a developer toggle if you want to compare old and new voice UX side by side on Windows desktop.
- Ship Wave 2 only after collecting before/after metrics for average voice file size and first-play latency.
- Ship Wave 3 behind mobile-only flags first; desktop does not need earpiece/proximity routing.
