import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../../widgets/message_bubble.dart';
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
  const SendStatusIndicator({super.key, required int status, this.size = 16.0})
    : state = status == WKSendMsgResult.sendFail
          ? ChatSendVisualState.failed
          : status == WKSendMsgResult.sendLoading
          ? ChatSendVisualState.sending
          : ChatSendVisualState.sent;

  const SendStatusIndicator.visual({
    super.key,
    required this.state,
    this.size = 16.0,
  });

  final ChatSendVisualState state;
  final double size;

  @override
  State<SendStatusIndicator> createState() => _SendStatusIndicatorState();
}

class _SendStatusIndicatorState extends State<SendStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shakeAnimation;
  ChatSendVisualState _previousState = ChatSendVisualState.sending;

  @override
  void initState() {
    super.initState();
    _previousState = widget.state;
    _controller = AnimationController(
      vsync: this,
      duration: ChatMotionDurations.statusChange.value,
    );
    switch (widget.state) {
      case ChatSendVisualState.sent:
      case ChatSendVisualState.delivered:
      case ChatSendVisualState.read:
        _controller.value = 1.0;
      case ChatSendVisualState.sending:
      case ChatSendVisualState.failed:
        break;
    }
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
    if (oldWidget.state != widget.state && widget.state != _previousState) {
      _previousState = widget.state;
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
    switch (widget.state) {
      case ChatSendVisualState.sending:
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
      case ChatSendVisualState.sent:
        return ScaleTransition(
          scale: _scaleAnimation,
          child: Icon(
            Icons.check_rounded,
            size: widget.size,
            color: const Color(0xFF677487),
          ),
        );
      case ChatSendVisualState.delivered:
        return ScaleTransition(
          scale: _scaleAnimation,
          child: Icon(
            Icons.done_all_rounded,
            key: const ValueKey<String>('send-status-delivered'),
            size: widget.size,
            color: const Color(0xFF677487),
          ),
        );
      case ChatSendVisualState.read:
        return ScaleTransition(
          scale: _scaleAnimation,
          child: Icon(
            Icons.done_all_rounded,
            key: const ValueKey<String>('send-status-read'),
            size: widget.size,
            color: const Color(0xFF2196F3),
          ),
        );
      case ChatSendVisualState.failed:
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
            key: const ValueKey<String>('send-status-failed'),
            size: widget.size,
            color: Colors.red.shade400,
          ),
        );
    }
  }
}
