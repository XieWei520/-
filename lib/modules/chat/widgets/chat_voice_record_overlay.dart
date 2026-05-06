import 'package:flutter/material.dart';

import '../../../wukong_uikit/views/record_audio_view.dart';
import '../chat_voice_action_service.dart';

class ChatVoiceRecordOverlay extends StatelessWidget {
  const ChatVoiceRecordOverlay({super.key, required this.state});

  final ChatVoiceRecordingState state;

  @override
  Widget build(BuildContext context) {
    if (!state.isVisible) {
      return const SizedBox.shrink();
    }

    final isDanger = state.phase == ChatVoiceRecordingPhase.cancelCandidate;
    final countdownLabel = _countdownLabel();
    final overlayKey = Key(
      isDanger
          ? 'chat-voice-record-overlay-danger'
          : 'chat-voice-record-overlay-normal',
    );

    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 124),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: KeyedSubtree(
              key: overlayKey,
              child: Stack(
                children: <Widget>[
                  RecordAudioView(
                    durationLabel: _formatDuration(state.duration),
                    waveformSamples: state.waveformSamples,
                    isCancelDanger: isDanger,
                    hintText: _hintForPhase(state.phase),
                  ),
                  if (countdownLabel != null)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.24),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Text(
                            countdownLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _hintForPhase(ChatVoiceRecordingPhase phase) {
    switch (phase) {
      case ChatVoiceRecordingPhase.recording:
        return 'Release to send, slide up to cancel';
      case ChatVoiceRecordingPhase.cancelCandidate:
        return 'Release to cancel';
      case ChatVoiceRecordingPhase.stopping:
        return 'Processing...';
      case ChatVoiceRecordingPhase.tooShort:
        return 'Recording too short';
      case ChatVoiceRecordingPhase.idle:
      case ChatVoiceRecordingPhase.permissionDenied:
      case ChatVoiceRecordingPhase.sendReady:
      case ChatVoiceRecordingPhase.sendFailed:
        return '';
    }
  }

  String? _countdownLabel() {
    final seconds = state.countdownSeconds;
    if (seconds == null) {
      return null;
    }
    if (state.phase != ChatVoiceRecordingPhase.recording &&
        state.phase != ChatVoiceRecordingPhase.cancelCandidate) {
      return null;
    }
    if (seconds <= 0) {
      return null;
    }
    return '${seconds}s left';
  }
}
