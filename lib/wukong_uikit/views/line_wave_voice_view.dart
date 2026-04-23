import 'dart:math' as math;

import 'package:flutter/material.dart';

class LineWaveVoiceView extends StatelessWidget {
  const LineWaveVoiceView({
    super.key,
    required this.samples,
    required this.color,
    required this.isActive,
    this.maxHeight = 24,
  });

  final List<double> samples;
  final Color color;
  final bool isActive;
  final double maxHeight;

  static const List<double> _fallbackSamples = <double>[
    0.12,
    0.2,
    0.34,
    0.48,
    0.65,
    0.52,
    0.4,
    0.28,
    0.16,
    0.24,
    0.38,
    0.46,
  ];

  @override
  Widget build(BuildContext context) {
    final resolvedSamples = _resolveSamples();
    final paintColor = isActive
        ? color
        : Color.lerp(color, Colors.white, 0.55) ?? color;
    final alpha = isActive ? 1.0 : 0.72;

    return SizedBox(
      height: maxHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          for (int index = 0; index < resolvedSamples.length; index++)
            Padding(
              padding: EdgeInsets.only(
                right: index == resolvedSamples.length - 1 ? 0 : 3,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                width: 3,
                height: _barHeight(resolvedSamples[index]),
                decoration: BoxDecoration(
                  color: paintColor.withOpacity(alpha),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<double> _resolveSamples() {
    if (samples.isEmpty) {
      return _fallbackSamples;
    }
    if (samples.length <= 24) {
      return samples;
    }
    final start = samples.length - 24;
    return samples.sublist(start);
  }

  double _barHeight(double sample) {
    final normalized = _normalizeSample(sample);
    final base = isActive ? normalized : normalized * 0.55;
    final shaped = math.pow(base, 0.8).toDouble();
    return math.max(3, maxHeight * shaped);
  }

  double _normalizeSample(double value) {
    if (value.isNaN || value.isInfinite) {
      return 0.0;
    }
    if (value < 0.0) {
      return 0.0;
    }
    if (value > 1.0) {
      return 1.0;
    }
    return value;
  }
}
