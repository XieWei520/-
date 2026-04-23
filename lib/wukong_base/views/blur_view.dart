import 'dart:ui';
import 'package:flutter/material.dart';

/// Blur view widget
class BlurView extends StatelessWidget {
  final Widget child;
  final double blur;          // Blur radius (0-25)
  final Color? overlayColor;   // Optional color overlay
  final double overlayOpacity; // Opacity of overlay (0-1)
  final BlurStyle blurStyle;   // Blur style

  const BlurView({
    super.key,
    required this.child,
    this.blur = 10,
    this.overlayColor,
    this.overlayOpacity = 0,
    this.blurStyle = BlurStyle.normal,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Blur effect
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blur,
                sigmaY: blur,
              ),
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
        ),
        
        // Optional overlay
        if (overlayOpacity > 0)
          Positioned.fill(
            child: Container(
              color: (overlayColor ?? Colors.white).withValues(alpha: overlayOpacity),
            ),
          ),
        
        // Child content
        child,
      ],
    );
  }
}

/// Frosted glass effect widget
class FrostedGlassView extends StatelessWidget {
  final Widget child;
  final double blur;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final double opacity;

  const FrostedGlassView({
    super.key,
    required this.child,
    this.blur = 10,
    this.borderRadius,
    this.padding,
    this.backgroundColor,
    this.opacity = 0.7,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (backgroundColor ?? (isDark ? Colors.white : Colors.black))
                .withValues(alpha: opacity),
            borderRadius: borderRadius ?? BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
