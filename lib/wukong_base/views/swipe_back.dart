import 'package:flutter/material.dart';

/// Swipe back route observer for tracking navigation
class SwipeBackRouteObserver extends RouteObserver<Route<dynamic>> {
  final void Function(Route<dynamic>? route)? onRouteChanged;

  SwipeBackRouteObserver({this.onRouteChanged});

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    onRouteChanged?.call(previousRoute);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    onRouteChanged?.call(route);
  }
}

/// Swipe back wrapper widget
/// 
/// Wraps a page with swipe-back gesture support.
class SwipeBackWrapper extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final VoidCallback? onSwipeBack;
  final Color? backgroundColor;

  const SwipeBackWrapper({
    super.key,
    required this.child,
    this.enabled = true,
    this.onSwipeBack,
    this.backgroundColor,
  });

  @override
  State<SwipeBackWrapper> createState() => _SwipeBackWrapperState();
}

class _SwipeBackWrapperState extends State<SwipeBackWrapper> {
  double _dragOffset = 0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(
        children: [
          widget.child,
          if (_isDragging && _dragOffset > 0)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: _dragOffset / 300 * 0.5),
              ),
            ),
        ],
      ),
    );
  }

  void _onDragStart(DragStartDetails details) {
    // Only enable swipe back from left edge
    if (details.globalPosition.dx < 20) {
      _isDragging = true;
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    
    setState(() {
      _dragOffset += details.delta.dx;
      _dragOffset = _dragOffset.clamp(0, 300);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    
    if (_dragOffset > 100) {
      // Swipe back threshold reached
      widget.onSwipeBack?.call();
      Navigator.of(context).pop();
    }
    
    setState(() {
      _isDragging = false;
      _dragOffset = 0;
    });
  }
}
