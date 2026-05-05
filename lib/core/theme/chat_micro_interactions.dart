import 'package:flutter/material.dart';

import '../motion/chat_motion.dart';

/// Micro-interaction widgets for chat visual polish.
///
/// - [UnreadBadgeBounce]: Elastic scale animation on the unread count badge
/// - [ReadReceiptTicks]: Double blue ticks that appear sequentially
/// - [ConnectionStatusBanner]: Slide-down + color-gradient connectivity banner

/// Animated unread badge that bounces in when the count changes.
class UnreadBadgeBounce extends StatefulWidget {
  const UnreadBadgeBounce({
    super.key,
    required this.count,
    this.color = const Color(0xFFFF5353),
    this.textColor = const Color(0xFFFFFFFF),
    this.size = 20.0,
    this.fontSize = 11.0,
  });

  final int count;
  final Color color;
  final Color textColor;
  final double size;
  final double fontSize;

  @override
  State<UnreadBadgeBounce> createState() => _UnreadBadgeBounceState();
}

class _UnreadBadgeBounceState extends State<UnreadBadgeBounce>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  int _previousCount = 0;

  @override
  void initState() {
    super.initState();
    _previousCount = widget.count;
    _controller = AnimationController(
      vsync: this,
      duration: ChatMotionDurations.badgeBounce.value,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.3,
          end: 0.9,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.9,
          end: 1.0,
        ).chain(CurveTween(curve: ChatMotionCurves.spring)),
        weight: 30,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(UnreadBadgeBounce oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count && widget.count != _previousCount) {
      _previousCount = widget.count;
      if (widget.count > 0) {
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count <= 0) return const SizedBox.shrink();

    final label = widget.count > 99 ? '99+' : widget.count.toString();
    final minWidth = label.length > 2 ? widget.size + 8 : widget.size;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        constraints: BoxConstraints(minWidth: minWidth, minHeight: widget.size),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(widget.size / 2),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: widget.textColor,
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Animated double-tick read receipt indicator.
///
/// Shows one tick when sent, two ticks (appearing sequentially) when read.
class ReadReceiptTicks extends StatefulWidget {
  const ReadReceiptTicks({
    super.key,
    required this.isRead,
    this.isSent = true,
    this.size = 16.0,
    this.readColor = const Color(0xFF2196F3),
    this.unreadColor = const Color(0xFFB6B5B5),
  });

  final bool isRead;
  final bool isSent;
  final double size;
  final Color readColor;
  final Color unreadColor;

  @override
  State<ReadReceiptTicks> createState() => _ReadReceiptTicksState();
}

class _ReadReceiptTicksState extends State<ReadReceiptTicks>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _secondTickAnimation;
  bool _wasRead = false;

  @override
  void initState() {
    super.initState();
    _wasRead = widget.isRead;
    _controller = AnimationController(
      vsync: this,
      duration: ChatMotionDurations.statusChange.value,
    );
    _secondTickAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    if (widget.isRead) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(ReadReceiptTicks oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_wasRead && widget.isRead) {
      _wasRead = true;
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
    if (!widget.isSent) {
      return SizedBox(width: widget.size, height: widget.size);
    }

    final color = widget.isRead ? widget.readColor : widget.unreadColor;

    return SizedBox(
      width: widget.size + 6,
      height: widget.size,
      child: Stack(
        children: [
          // First tick (always visible when sent)
          Icon(Icons.check, size: widget.size, color: color),
          // Second tick (slides in when read)
          Positioned(
            left: 6,
            child: ScaleTransition(
              scale: _secondTickAnimation,
              alignment: Alignment.centerLeft,
              child: Icon(Icons.check, size: widget.size, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Connection status banner that slides down with a color gradient.
///
/// Usage:
/// ```dart
/// ConnectionStatusBanner(
///   status: ConnectionStatus.connecting,
/// )
/// ```
enum ConnectionBannerStatus { connected, connecting, disconnected }

class ConnectionStatusBanner extends StatelessWidget {
  const ConnectionStatusBanner({
    super.key,
    required this.status,
    this.duration = const Duration(milliseconds: 300),
  });

  final ConnectionBannerStatus status;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final isVisible = status != ConnectionBannerStatus.connected;

    return AnimatedSlide(
      offset: isVisible ? Offset.zero : const Offset(0, -1),
      duration: duration,
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.0,
        duration: duration,
        child: _BannerContent(status: status),
      ),
    );
  }
}

class _BannerContent extends StatelessWidget {
  const _BannerContent({required this.status});

  final ConnectionBannerStatus status;

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final String text;
    final IconData icon;

    switch (status) {
      case ConnectionBannerStatus.connecting:
        bgColor = const Color(0xFFF59E0B);
        text = '连接中...';
        icon = Icons.sync;
      case ConnectionBannerStatus.disconnected:
        bgColor = const Color(0xFFF80303);
        text = '网络已断开';
        icon = Icons.cloud_off;
      case ConnectionBannerStatus.connected:
        bgColor = const Color(0xFF4CAF50);
        text = '已连接';
        icon = Icons.cloud_done;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgColor, bgColor.withValues(alpha: 0.85)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
