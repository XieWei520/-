import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_voice_action_service.dart';
import 'package:wukong_im_app/modules/chat/widgets/chat_voice_press_hold_button.dart';
import 'package:wukong_im_app/modules/chat/widgets/chat_voice_record_overlay.dart';

void main() {
  testWidgets(
    'ChatVoiceRecordOverlay uses normal style and recording hint in recording phase',
    (tester) async {
      const state = ChatVoiceRecordingState(
        phase: ChatVoiceRecordingPhase.recording,
        duration: Duration(seconds: 4),
        waveformSamples: <double>[0.1, 0.4, 0.3],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ChatVoiceRecordOverlay(state: state)),
        ),
      );

      expect(
        find.byKey(const Key('chat-voice-record-overlay-normal')),
        findsOneWidget,
      );
      expect(find.text('Release to send, slide up to cancel'), findsOneWidget);
      expect(find.text('00:04'), findsOneWidget);
    },
  );

  testWidgets(
    'ChatVoiceRecordOverlay shows countdown text when countdownSeconds exists',
    (tester) async {
      const state = ChatVoiceRecordingState(
        phase: ChatVoiceRecordingPhase.recording,
        duration: Duration(seconds: 53),
        waveformSamples: <double>[0.1, 0.4, 0.3],
        countdownSeconds: 7,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ChatVoiceRecordOverlay(state: state)),
        ),
      );

      expect(find.text('Release to send, slide up to cancel'), findsOneWidget);
      expect(find.text('7s left'), findsOneWidget);
    },
  );

  testWidgets(
    'ChatVoiceRecordOverlay hides countdown text when countdownSeconds is null',
    (tester) async {
      const state = ChatVoiceRecordingState(
        phase: ChatVoiceRecordingPhase.recording,
        duration: Duration(seconds: 53),
        waveformSamples: <double>[0.1, 0.4, 0.3],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ChatVoiceRecordOverlay(state: state)),
        ),
      );

      expect(find.text('Release to send, slide up to cancel'), findsOneWidget);
      expect(find.text('7s left'), findsNothing);
    },
  );

  testWidgets(
    'ChatVoiceRecordOverlay uses danger style in cancelCandidate and shows formatted duration',
    (tester) async {
      const state = ChatVoiceRecordingState(
        phase: ChatVoiceRecordingPhase.cancelCandidate,
        duration: Duration(seconds: 3),
        waveformSamples: <double>[0.2, 0.5, 0.7],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ChatVoiceRecordOverlay(state: state)),
        ),
      );

      expect(
        find.byKey(const Key('chat-voice-record-overlay-danger')),
        findsOneWidget,
      );
      expect(find.text('00:03'), findsOneWidget);
    },
  );

  testWidgets(
    'ChatVoiceRecordOverlay shows processing hint in stopping phase',
    (tester) async {
      const state = ChatVoiceRecordingState(
        phase: ChatVoiceRecordingPhase.stopping,
        duration: Duration(seconds: 8),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ChatVoiceRecordOverlay(state: state)),
        ),
      );

      expect(
        find.byKey(const Key('chat-voice-record-overlay-normal')),
        findsOneWidget,
      );
      expect(find.text('Processing...'), findsOneWidget);
    },
  );

  testWidgets('ChatVoiceRecordOverlay shows short hint in tooShort phase', (
    tester,
  ) async {
    const state = ChatVoiceRecordingState(
      phase: ChatVoiceRecordingPhase.tooShort,
      duration: Duration(milliseconds: 500),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ChatVoiceRecordOverlay(state: state)),
      ),
    );

    expect(
      find.byKey(const Key('chat-voice-record-overlay-normal')),
      findsOneWidget,
    );
    expect(find.text('Recording too short'), findsOneWidget);
  });

  testWidgets(
    'ChatVoiceRecordOverlay stays hidden for idle sendReady sendFailed and permissionDenied phases',
    (tester) async {
      const hiddenPhases = <ChatVoiceRecordingPhase>[
        ChatVoiceRecordingPhase.idle,
        ChatVoiceRecordingPhase.sendReady,
        ChatVoiceRecordingPhase.sendFailed,
        ChatVoiceRecordingPhase.permissionDenied,
      ];

      for (final phase in hiddenPhases) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatVoiceRecordOverlay(
                state: ChatVoiceRecordingState(phase: phase),
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('chat-voice-record-overlay-normal')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('chat-voice-record-overlay-danger')),
          findsNothing,
        );
        expect(find.text('Release to send, slide up to cancel'), findsNothing);
        expect(find.text('Release to cancel'), findsNothing);
        expect(find.text('Processing...'), findsNothing);
        expect(find.text('Recording too short'), findsNothing);
      }
    },
  );

  testWidgets(
    'ChatVoicePressHoldButton shows Chinese title copy without legacy helper line',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatVoicePressHoldButton(
              isRecording: false,
              onHoldStart: () async {},
              onCancelZoneChanged: (_) {},
              onHoldRelease: (_) async {},
              onHoldAbort: () async {},
            ),
          ),
        ),
      );

      expect(find.text('\u6309\u4f4f\u8bf4\u8bdd'), findsOneWidget);
      expect(
        find.text('\u4e0a\u6ed1\u53ef\u53d6\u6d88\u53d1\u9001'),
        findsNothing,
      );
    },
  );
}
