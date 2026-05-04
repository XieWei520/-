import 'package:flutter/material.dart';

/// Swipe back wrapper for iOS-style navigation
class SwipeBackWrapper extends StatelessWidget {
  final Widget child;

  const SwipeBackWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
