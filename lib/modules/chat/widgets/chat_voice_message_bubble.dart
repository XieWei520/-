import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/model/wk_voice_content.dart';

import '../../../core/config/api_config.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../data/models/chat_session.dart';
import '../../../widgets/wk_colors.dart';
import '../../../wukong_base/utils/audio_record_manager.dart';
import '../../../wukong_uikit/views/line_wave_voice_view.dart';
import '../chat_message_view_model.dart';
import '../chat_scene_providers.dart';
import '../chat_voice_playback_controller.dart';

class ChatVoiceMessageBubble extends ConsumerWidget {
  static const double _minBubbleWidth = 164;
  static const double _maxBubbleWidth = 262;
  static const int _minScaledDurationMs = 1000;
  static const int _maxScaledDurationMs = 60000;

  const ChatVoiceMessageBubble({
    super.key,
    required this.session,
    required this.model,
    this.isWebOverride,
  });

  final ChatSession session;
  final ChatMessageViewModel model;
  final bool? isWebOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(chatVoicePlaybackControllerProvider(session));
    final messageKey = _resolveMessageKey();
    final content = model.message.messageContent as WKVoiceContent?;
    final isWeb = isWebOverride ?? PlatformUtils.isWeb;
    final source = _resolveSource(
      content,
      model.structuredPayload,
      isWeb: isWeb,
    );
    final fallbackSource = _resolveFallbackSource(
      content,
      model.structuredPayload,
      primarySource: source,
      isWeb: isWeb,
    );
    final fallbackDurationMs = _fallbackDurationMs(
      content,
      model.structuredPayload,
    );
    final entry = controller.state.entries[messageKey];
    final status = entry?.status ?? ChatVoicePlaybackStatus.idle;
    final positionMs = entry?.positionMs ?? 0;
    final durationMs = _resolveDurationMs(
      entry?.durationMs,
      fallbackDurationMs,
    );
    final bubbleWidth = _bubbleWidthForDuration(durationMs);
    final isPlaying = status == ChatVoicePlaybackStatus.playing;
    final isPaused = status == ChatVoicePlaybackStatus.paused;
    final isFailed = status == ChatVoicePlaybackStatus.failed;
    final isUnreadReceived = !model.isSelf && model.message.voiceStatus == 0;
    final hasSource = source != null;
    final foregroundColor = isFailed
        ? const Color(0xFFD64545)
        : model.isSelf
        ? WKColors.sendText
        : WKColors.receiveText;
    final waveColor = isFailed
        ? const Color(0xFFD64545)
        : model.isSelf
        ? Colors.white
        : WKColors.brand500;
    final highlightColor = isFailed
        ? const Color(0x1FD64545)
        : (isPlaying || isPaused)
        ? (model.isSelf
              ? Colors.white.withValues(alpha: 0.14)
              : const Color(0x142F6FED))
        : Colors.transparent;
    final borderColor = isFailed
        ? const Color(0x33D64545)
        : (isPlaying || isPaused)
        ? waveColor.withValues(alpha: 0.26)
        : Colors.transparent;
    final labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: foregroundColor,
    );
    final displayLabel = isPlaying || isPaused
        ? '${_formatClock(positionMs)} / ${_formatClock(durationMs)}'
        : _formatClock(durationMs);

    return Opacity(
      opacity: hasSource ? 1 : 0.6,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('chat-voice-bubble-$messageKey'),
          borderRadius: BorderRadius.circular(14),
          onTap: !hasSource
              ? null
              : () {
                  final playbackSource = source;
                  debugPrint(
                    '[voice/bubble] tap message=$messageKey source=${_describeSource(playbackSource)}',
                  );
                  unawaited(
                    controller.toggle(
                      messageId: messageKey,
                      source: playbackSource,
                      fallbackSource: fallbackSource,
                      message: model.message,
                    ),
                  );
                },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bubbleConstraints = _resolveBubbleConstraints(
                scaledWidth: bubbleWidth,
                parentConstraints: constraints,
              );
              final waveSamples = _samplesFor(
                status: status,
                positionMs: positionMs,
                durationMs: durationMs,
              );
              final visibleWaveSamples = _fitWaveSamplesToWidth(
                context: context,
                samples: waveSamples,
                bubbleMaxWidth: bubbleConstraints.minWidth,
                label: displayLabel,
                labelStyle: labelStyle,
                hasUnreadIndicator: isUnreadReceived,
              );
              final content = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isFailed
                        ? Icons.refresh_rounded
                        : isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 20,
                    color: foregroundColor,
                  ),
                  const SizedBox(width: 8),
                  LineWaveVoiceView(
                    samples: visibleWaveSamples,
                    color: waveColor,
                    isActive: isPlaying || isPaused,
                    maxHeight: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(displayLabel, style: labelStyle),
                  if (isUnreadReceived) ...<Widget>[
                    const SizedBox(width: 6),
                    Container(
                      key: ValueKey<String>(
                        'chat-voice-unread-indicator-$messageKey',
                      ),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: WKColors.brand500,
                      ),
                    ),
                  ],
                ],
              );
              final isTightlyClamped =
                  (bubbleConstraints.maxWidth - bubbleConstraints.minWidth)
                      .abs() <
                  0.5;
              return AnimatedContainer(
                key: ValueKey<String>(
                  'chat-voice-bubble-container-$messageKey',
                ),
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                constraints: bubbleConstraints,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: highlightColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: isTightlyClamped
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: content,
                        ),
                      )
                    : content,
              );
            },
          ),
        ),
      ),
    );
  }

  String _resolveMessageKey() {
    final clientMsgNo = model.message.clientMsgNO.trim();
    if (clientMsgNo.isNotEmpty) {
      return 'cid:$clientMsgNo';
    }
    final messageId = model.message.messageID.trim();
    if (messageId.isNotEmpty) {
      return 'mid:$messageId';
    }
    return model.identity;
  }

  static AudioPlaybackSource? _resolveSource(
    WKVoiceContent? content,
    Map<String, dynamic>? payload, {
    required bool isWeb,
  }) {
    final localSource = _resolveLocalSource(content?.localPath, isWeb: isWeb);
    if (localSource != null) {
      return localSource;
    }
    return _resolveRemoteSource(content, payload);
  }

  static AudioPlaybackSource? _resolveFallbackSource(
    WKVoiceContent? content,
    Map<String, dynamic>? payload, {
    required AudioPlaybackSource? primarySource,
    required bool isWeb,
  }) {
    if (primarySource == null) {
      return null;
    }
    final localSource = _resolveLocalSource(content?.localPath, isWeb: isWeb);
    final remoteSource = _resolveRemoteSource(content, payload);
    if (localSource == null || remoteSource == null) {
      return null;
    }
    if (primarySource == localSource) {
      return remoteSource;
    }
    return null;
  }

  static AudioPlaybackSource? _resolveLocalSource(
    String? localPath, {
    required bool isWeb,
  }) {
    final normalized = localPath?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    if (isWeb) {
      return _resolveWebPlayableSource(normalized);
    }
    return AudioPlaybackSource.file(normalized);
  }

  static AudioPlaybackSource? _resolveRemoteSource(
    WKVoiceContent? content,
    Map<String, dynamic>? payload,
  ) {
    final contentUrl = content?.url.trim() ?? '';
    final payloadUrl = payload?['url']?.toString().trim() ?? '';
    final remoteUrl = contentUrl.isNotEmpty ? contentUrl : payloadUrl;
    if (remoteUrl.isEmpty) {
      return null;
    }
    return AudioPlaybackSource.network(ApiConfig.resolveMediaUrl(remoteUrl));
  }

  static String _describeSource(AudioPlaybackSource source) {
    return '${source.kind.name}:${source.value}';
  }

  static AudioPlaybackSource? _resolveWebPlayableSource(String localPath) {
    final normalized = localPath.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final lower = normalized.toLowerCase();
    if (lower.startsWith('blob:') ||
        lower.startsWith('http://') ||
        lower.startsWith('https://')) {
      return AudioPlaybackSource.network(normalized);
    }
    return null;
  }

  static int _fallbackDurationMs(
    WKVoiceContent? content,
    Map<String, dynamic>? payload,
  ) {
    final contentSeconds = content?.timeTrad ?? 0;
    if (contentSeconds > 0) {
      return contentSeconds * 1000;
    }

    final durationMs = _readInt(payload, const ['durationMs', 'duration_ms']);
    if (durationMs > 0) {
      return durationMs;
    }

    final seconds = _readInt(payload, const [
      'timeTrad',
      'time_trad',
      'duration',
      'time',
    ]);
    if (seconds > 0) {
      return seconds * 1000;
    }
    return 1000;
  }

  static int _readInt(Map<String, dynamic>? payload, List<String> keys) {
    if (payload == null) {
      return 0;
    }
    for (final key in keys) {
      final value = payload[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return 0;
  }

  static int _resolveDurationMs(int? current, int fallback) {
    if (current != null && current > 0) {
      return current;
    }
    return fallback;
  }

  static List<double> _samplesFor({
    required ChatVoicePlaybackStatus status,
    required int positionMs,
    required int durationMs,
  }) {
    if (status == ChatVoicePlaybackStatus.failed) {
      return const <double>[0.88, 0.22, 0.8, 0.28, 0.92, 0.24, 0.86, 0.2];
    }
    final safeDurationMs = durationMs <= 0 ? 1 : durationMs;
    final progressRatio = (positionMs / safeDurationMs)
        .clamp(0.0, 1.0)
        .toDouble();
    if (status == ChatVoicePlaybackStatus.playing) {
      final sweepIndex = ((positionMs ~/ 140) % 12).clamp(0, 11);
      return List<double>.generate(12, (index) {
        final distance = (index - sweepIndex).abs();
        final pulse = (1.0 - (distance / 4.0)).clamp(0.0, 1.0).toDouble();
        final base = 0.2 + ((index % 3) * 0.08);
        final progressLift = progressRatio * 0.12;
        return (base + progressLift + (pulse * 0.56)).clamp(0.08, 0.98);
      });
    }
    if (status == ChatVoicePlaybackStatus.paused) {
      return <double>[
        0.2 + (progressRatio * 0.08),
        0.28 + (progressRatio * 0.08),
        0.42 + (progressRatio * 0.1),
        0.34 + (progressRatio * 0.08),
        0.46 + (progressRatio * 0.08),
        0.3 + (progressRatio * 0.08),
        0.38 + (progressRatio * 0.08),
        0.24 + (progressRatio * 0.08),
      ];
    }
    return <double>[
      0.18,
      0.26 + (progressRatio * 0.04),
      0.34 + (progressRatio * 0.06),
      0.28 + (progressRatio * 0.04),
      0.36 + (progressRatio * 0.05),
      0.24,
      0.32 + (progressRatio * 0.04),
      0.2,
    ];
  }

  static double _bubbleWidthForDuration(int durationMs) {
    final clampedDuration = durationMs.clamp(
      _minScaledDurationMs,
      _maxScaledDurationMs,
    );
    final normalized =
        (clampedDuration - _minScaledDurationMs) /
        (_maxScaledDurationMs - _minScaledDurationMs);
    return _minBubbleWidth + ((_maxBubbleWidth - _minBubbleWidth) * normalized);
  }

  static BoxConstraints _resolveBubbleConstraints({
    required double scaledWidth,
    required BoxConstraints parentConstraints,
  }) {
    final parentMaxWidth =
        parentConstraints.hasBoundedWidth && parentConstraints.maxWidth.isFinite
        ? parentConstraints.maxWidth
        : _maxBubbleWidth;
    final maxWidth = parentMaxWidth.clamp(0.0, _maxBubbleWidth).toDouble();
    final minWidth = scaledWidth.clamp(0.0, maxWidth).toDouble();
    return BoxConstraints(minWidth: minWidth, maxWidth: maxWidth);
  }

  static List<double> _fitWaveSamplesToWidth({
    required BuildContext context,
    required List<double> samples,
    required double bubbleMaxWidth,
    required String label,
    required TextStyle labelStyle,
    required bool hasUnreadIndicator,
  }) {
    if (samples.length <= 1) {
      return samples;
    }
    final labelWidth = _measureLabelWidth(
      context: context,
      text: label,
      style: labelStyle,
    );
    const horizontalPadding = 20.0;
    const iconWidth = 20.0;
    const waveAndTextGapWidth = 16.0;
    const unreadWidth = 12.0;
    const borderWidth = 2.0;
    const textMeasurementSlack = 12.0;
    final reservedWidthWithoutWave =
        horizontalPadding +
        iconWidth +
        waveAndTextGapWidth +
        labelWidth +
        (hasUnreadIndicator ? unreadWidth : 0.0);
    final contentMaxWidth = (bubbleMaxWidth - borderWidth).clamp(
      0.0,
      double.infinity,
    );
    final availableWaveWidth =
        contentMaxWidth - reservedWidthWithoutWave - textMeasurementSlack;
    var maxWaveBarCount = ((availableWaveWidth + 3.0) / 6.0).floor().clamp(
      1,
      samples.length,
    );
    while (maxWaveBarCount > 1 &&
        (reservedWidthWithoutWave + _waveWidthForBars(maxWaveBarCount)) >
            contentMaxWidth) {
      maxWaveBarCount -= 1;
    }
    if (maxWaveBarCount >= samples.length) {
      return samples;
    }
    return samples.sublist(samples.length - maxWaveBarCount);
  }

  static double _waveWidthForBars(int barCount) {
    if (barCount <= 0) {
      return 0.0;
    }
    return (barCount * 6.0) - 3.0;
  }

  static double _measureLabelWidth({
    required BuildContext context,
    required String text,
    required TextStyle style,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.width;
  }

  static String _formatClock(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
