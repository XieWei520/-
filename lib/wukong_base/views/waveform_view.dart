import 'package:flutter/material.dart';

/// Waveform view widget
class WaveformView extends StatelessWidget {
  final List<double> waveformData;  // Values between 0.0 and 1.0
  final double height;
  final double barWidth;
  final double barSpacing;
  final Color? activeColor;
  final Color? inactiveColor;
  final int? progressIndex;  // Highlight bars up to this index
  final bool animate;
  final VoidCallback? onTap;

  const WaveformView({
    super.key,
    required this.waveformData,
    this.height = 40,
    this.barWidth = 3,
    this.barSpacing = 2,
    this.activeColor,
    this.inactiveColor,
    this.progressIndex,
    this.animate = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(
            waveformData.length,
            (index) => _WaveformBar(
              value: waveformData[index],
              height: height,
              barWidth: barWidth,
              color: _getBarColor(index, context),
            ),
          ).expand((widget) => [widget, SizedBox(width: barSpacing)]).toList()
            ..removeLast(),
        ),
      ),
    );
  }

  Color _getBarColor(int index, BuildContext context) {
    if (progressIndex != null && index <= progressIndex!) {
      return activeColor ?? Theme.of(context).primaryColor;
    }
    return inactiveColor ?? Colors.grey[400]!;
  }
}

class _WaveformBar extends StatelessWidget {
  final double value;  // 0.0 to 1.0
  final double height;
  final double barWidth;
  final Color color;

  const _WaveformBar({
    required this.value,
    required this.height,
    required this.barWidth,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: barWidth,
      height: (value * height).clamp(4.0, height),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(barWidth / 2),
      ),
    );
  }
}

/// Recording waveform view with animation
class RecordingWaveformView extends StatefulWidget {
  final double height;
  final Color? color;
  final bool isRecording;

  const RecordingWaveformView({
    super.key,
    this.height = 60,
    this.color,
    this.isRecording = false,
  });

  @override
  State<RecordingWaveformView> createState() => _RecordingWaveformViewState();
}

class _RecordingWaveformViewState extends State<RecordingWaveformView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<double> _waveformData = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    
    _waveformData = List.generate(20, (i) => 0.3);
  }

  @override
  void didUpdateWidget(RecordingWaveformView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isRecording && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (widget.isRecording) {
          _waveformData = List.generate(
            20,
            (i) => 0.2 + (i % 5) * 0.15 * _controller.value,
          );
        }
        
        return WaveformView(
          waveformData: _waveformData,
          height: widget.height,
          barWidth: 4,
          barSpacing: 2,
          activeColor: widget.color ?? Colors.red,
        );
      },
    );
  }
}
