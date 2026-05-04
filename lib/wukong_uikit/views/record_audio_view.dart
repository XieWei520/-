import 'package:flutter/material.dart';

import 'line_wave_voice_view.dart';

class RecordAudioView extends StatelessWidget {
  const RecordAudioView({
    super.key,
    required this.durationLabel,
    required this.waveformSamples,
    required this.isCancelDanger,
    required this.hintText,
  });

  final String durationLabel;
  final List<double> waveformSamples;
  final bool isCancelDanger;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final palette = isCancelDanger
        ? _RecordPalette.danger(context)
        : _RecordPalette.normal(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.borderColor, width: 1.2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.gradientColors,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.shadowColor,
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              durationLabel,
              style: TextStyle(
                color: palette.durationColor,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            LineWaveVoiceView(
              samples: waveformSamples,
              color: palette.waveColor,
              isActive: true,
              maxHeight: 24,
            ),
            const SizedBox(height: 12),
            Text(
              hintText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.hintColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordPalette {
  const _RecordPalette({
    required this.gradientColors,
    required this.borderColor,
    required this.shadowColor,
    required this.durationColor,
    required this.waveColor,
    required this.hintColor,
  });

  final List<Color> gradientColors;
  final Color borderColor;
  final Color shadowColor;
  final Color durationColor;
  final Color waveColor;
  final Color hintColor;

  factory _RecordPalette.normal(BuildContext context) {
    final base = Theme.of(context).colorScheme;
    return _RecordPalette(
      gradientColors: <Color>[
        Color.lerp(base.surface, base.primary, 0.14) ?? base.surface,
        Color.lerp(base.surfaceContainerHighest, base.primary, 0.08) ??
            base.surfaceContainerHighest,
      ],
      borderColor: Color.lerp(base.primary, Colors.white, 0.28) ?? base.primary,
      shadowColor: base.primary.withValues(alpha: 0.22),
      durationColor: base.onSurface,
      waveColor: base.primary,
      hintColor: base.onSurface.withValues(alpha: 0.78),
    );
  }

  factory _RecordPalette.danger(BuildContext context) {
    return _RecordPalette(
      gradientColors: <Color>[const Color(0xFF481925), const Color(0xFF7F1D2D)],
      borderColor: const Color(0xFFFF6E8D),
      shadowColor: const Color(0xFFDA3D64).withValues(alpha: 0.35),
      durationColor: const Color(0xFFFFEFF2),
      waveColor: const Color(0xFFFF98AE),
      hintColor: const Color(0xFFFFDFE6),
    );
  }
}
