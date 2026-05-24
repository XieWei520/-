import 'package:flutter/material.dart';

import 'liquid_glass_tokens.dart';
import 'wk_design_tokens.dart';

class LiquidGlassAppFrameScope extends InheritedWidget {
  const LiquidGlassAppFrameScope({
    super.key,
    required super.child,
    this.framed = true,
  });

  final bool framed;

  static bool isFramed(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<LiquidGlassAppFrameScope>()
            ?.framed ??
        false;
  }

  @override
  bool updateShouldNotify(LiquidGlassAppFrameScope oldWidget) {
    return framed != oldWidget.framed;
  }
}

class LiquidGlassPanel extends StatelessWidget {
  const LiquidGlassPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.borderRadius = LiquidGlassRadii.lg,
    this.shadow = LiquidGlassShadows.md,
    this.disableBlur = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius borderRadius;
  final List<BoxShadow> shadow;
  final bool disableBlur;

  @override
  Widget build(BuildContext context) {
    final tokens = LiquidGlassTokens.of(context);
    final panel = DecoratedBox(
      key: const ValueKey<String>('liquid-glass-panel-decoration'),
      decoration: BoxDecoration(
        color: disableBlur ? tokens.surfaceSolid : tokens.surface,
        borderRadius: borderRadius,
        border: Border.all(color: tokens.border),
      ),
      child: Padding(padding: padding, child: child),
    );
    return Padding(
      padding: margin,
      child: DecoratedBox(
        key: const ValueKey<String>('liquid-glass-panel-shadow'),
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: shadow,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: disableBlur
              ? panel
              : BackdropFilter(filter: tokens.backdropFilter, child: panel),
        ),
      ),
    );
  }
}

class LiquidGlassAppFrame extends StatelessWidget {
  const LiquidGlassAppFrame({
    super.key,
    required this.child,
    this.frameKey,
    this.width,
    this.height,
    this.disableBlur = false,
  });

  final Widget child;
  final Key? frameKey;
  final double? width;
  final double? height;
  final bool disableBlur;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassPanel(
      borderRadius: LiquidGlassRadii.lg,
      shadow: LiquidGlassShadows.md,
      disableBlur: disableBlur,
      child: ClipRRect(
        borderRadius: LiquidGlassRadii.lg,
        child: SizedBox(
          key: frameKey,
          width: width,
          height: height,
          child: LiquidGlassAppFrameScope(child: child),
        ),
      ),
    );
  }
}

class LiquidGlassPillButton extends StatelessWidget {
  const LiquidGlassPillButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = LiquidGlassTokens.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: LiquidGlassRadii.pill,
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: tokens.surfaceSolid,
            borderRadius: LiquidGlassRadii.pill,
            border: Border.all(color: tokens.border),
            boxShadow: LiquidGlassShadows.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 18, color: tokens.text),
                const SizedBox(width: WKSpace.xs),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: WKFontFamily.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tokens.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LiquidGlassStage extends StatelessWidget {
  const LiquidGlassStage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark
        ? LiquidGlassColors.darkBackground
        : LiquidGlassColors.lightBackground;
    return DecoratedBox(
      key: const ValueKey<String>('liquid-glass-stage'),
      decoration: BoxDecoration(color: base),
      child: child,
    );
  }
}
