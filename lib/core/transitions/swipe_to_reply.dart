import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Swipe-to-reply gesture wrapper for message bubbles.
///
/// Wraps a message bubble and detects a right-swipe gesture that,
/// when exceeding a threshold, triggers the reply callback with
/// haptic feedback.
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.enabled = true,
    this.threshold = 0.3,
  });

  final Widget child;
  final VoidCallback onReply;
  final bool enabled;

  /// Fraction of screen width required to trigger reply (0.0–1.0).
  final double threshold;

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragExtent = 0.0;
  bool _triggered = false;

  static const double _maxDragFraction = 0.4;
  static const double _replyIconSize = 24.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxDrag = screenWidth * _maxDragFraction;

    setState(() {
      _dragExtent = (_dragExtent + details.delta.dx).clamp(0.0, maxDrag);
    });

    final fraction = _dragExtent / screenWidth;
    if (fraction >= widget.threshold && !_triggered) {
      _triggered = true;
      HapticFeedback.lightImpact();
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final fraction = _dragExtent / screenWidth;

    if (fraction >= widget.threshold) {
      widget.onReply();
    }

    // Animate back to original position
    _controller.value = _dragExtent / (screenWidth * _maxDragFraction);
    _controller.animateTo(0.0, curve: Curves.easeOutBack);
    _controller.addListener(_animateBack);
  }

  void _animateBack() {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxDrag = screenWidth * _maxDragFraction;
    setState(() {
      _dragExtent = _controller.value * maxDrag;
    });
    if (_controller.isCompleted || _controller.isDismissed) {
      _controller.removeListener(_animateBack);
      _triggered = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final replyIconOpacity = (_dragExtent / 60.0).clamp(0.0, 1.0);

    return GestureDetector(
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Reply icon that fades in as you swipe
          Positioned(
            left: 8,
            child: Opacity(
              opacity: replyIconOpacity,
              child: Transform.scale(
                scale: replyIconOpacity.clamp(0.5, 1.0),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.reply,
                    size: _replyIconSize,
                    color: _triggered ? Colors.blue : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),
          // The actual message bubble, translated
          Transform.translate(
            offset: Offset(_dragExtent, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
