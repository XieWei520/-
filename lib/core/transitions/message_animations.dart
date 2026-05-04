import 'package:flutter/material.dart';

import '../motion/chat_motion.dart';

/// Animated wrapper for new messages sliding into view from the bottom.
class MessageSlideInAnimation extends StatelessWidget {
  const MessageSlideInAnimation({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: ChatMotionCurves.messageEnter,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(curved),
      child: FadeTransition(opacity: curved, child: child),
    );
  }
}

/// Animated send status indicator with scale-in for success check mark
/// and shake for failure.
class SendStatusIndicator extends StatefulWidget {
  const SendStatusIndicator({
    super.key,
    required this.status,
    this.size = 16.0,
  });

  /// 0=sending, 1=success, 2=failed
  final int status;
  final double size;

  @override
  State<SendStatusIndicator> createState() => _SendStatusIndicatorState();
}

class _SendStatusIndicatorState extends State<SendStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shakeAnimation;
  int _previousStatus = 0;

  @override
  void initState() {
    super.initState();
    _previousStatus = widget.status;
    _controller = AnimationController(
      vsync: this,
      duration: ChatMotionDurations.statusChange.value,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: ChatMotionCurves.spring),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: ChatMotionCurves.statusShake),
    );
  }

  @override
  void didUpdateWidget(SendStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status && widget.status != _previousStatus) {
      _previousStatus = widget.status;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.status) {
      case 0: // Sending
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
            ),
          ),
        );
      case 1: // Success
        return ScaleTransition(
          scale: _scaleAnimation,
          child: Icon(
            Icons.check_circle_outline,
            size: widget.size,
            color: Colors.green.shade400,
          ),
        );
      case 2: // Failed
        return AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            final offset =
                _shakeAnimation.value *
                4.0 *
                (1 - 2 * ((_shakeAnimation.value * 4).floor() % 2));
            return Transform.translate(offset: Offset(offset, 0), child: child);
          },
          child: Icon(
            Icons.error_outline,
            size: widget.size,
            color: Colors.red.shade400,
          ),
        );
      default:
        return SizedBox(width: widget.size, height: widget.size);
    }
  }
}
