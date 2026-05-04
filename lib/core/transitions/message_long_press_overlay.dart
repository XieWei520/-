import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// iMessage-inspired long-press interaction for message bubbles.
///
/// On long press:
/// 1. Bubble scales to 0.95
/// 2. Background gets a subtle blur
/// 3. Context menu appears above the bubble
/// 4. Release triggers spring-back animation
class MessageLongPressOverlay extends StatefulWidget {
  const MessageLongPressOverlay({
    super.key,
    required this.child,
    required this.menuBuilder,
    this.onLongPressStart,
    this.enabled = true,
  });

  /// The message bubble widget.
  final Widget child;

  /// Builds the context menu shown above the bubble.
  final Widget Function(BuildContext context, VoidCallback dismiss) menuBuilder;

  /// Called when long press begins (before overlay shows).
  final VoidCallback? onLongPressStart;

  /// Whether long press is enabled.
  final bool enabled;

  @override
  State<MessageLongPressOverlay> createState() =>
      _MessageLongPressOverlayState();
}

class _MessageLongPressOverlayState extends State<MessageLongPressOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  OverlayEntry? _overlayEntry;
  final GlobalKey _bubbleKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _dismissOverlay();
    _scaleController.dispose();
    super.dispose();
  }

  void _onLongPress() {
    if (!widget.enabled) return;
    HapticFeedback.mediumImpact();
    widget.onLongPressStart?.call();
    _scaleController.forward();
    _showOverlay();
  }

  void _showOverlay() {
    final renderBox =
        _bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return _LongPressOverlayContent(
          bubblePosition: position,
          bubbleSize: size,
          menuBuilder: widget.menuBuilder,
          onDismiss: _dismissOverlay,
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _dismissOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (_scaleController.isAnimating || _scaleController.isCompleted) {
      _scaleController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: _onLongPress,
      child: ScaleTransition(
        key: _bubbleKey,
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

class _LongPressOverlayContent extends StatefulWidget {
  const _LongPressOverlayContent({
    required this.bubblePosition,
    required this.bubbleSize,
    required this.menuBuilder,
    required this.onDismiss,
  });

  final Offset bubblePosition;
  final Size bubbleSize;
  final Widget Function(BuildContext, VoidCallback) menuBuilder;
  final VoidCallback onDismiss;

  @override
  State<_LongPressOverlayContent> createState() =>
      _LongPressOverlayContentState();
}

class _LongPressOverlayContentState extends State<_LongPressOverlayContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _menuSlideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _menuSlideAnimation = Tween<double>(begin: 10.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismiss,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Stack(
            children: [
              // Blurred background
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 6.0 * _fadeAnimation.value,
                    sigmaY: 6.0 * _fadeAnimation.value,
                  ),
                  child: ColoredBox(
                    color: Colors.black
                        .withValues(alpha: 0.2 * _fadeAnimation.value),
                  ),
                ),
              ),
              // Context menu positioned above the bubble
              Positioned(
                left: widget.bubblePosition.dx,
                top: widget.bubblePosition.dy - 60 + _menuSlideAnimation.value,
                width: widget.bubbleSize.width,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: widget.menuBuilder(context, _dismiss),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
