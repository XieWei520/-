import 'package:flutter/material.dart';

import 'liquid_glass_tokens.dart';
import 'wk_design_tokens.dart';

class WKWebBreakpoints {
  WKWebBreakpoints._();

  static const double mobileMax = 719;
  static const double tabletMin = 720;
  static const double desktopMin = 1024;
  static const double wideMin = 1280;

  static bool useDesktopWorkbench(double width) => width >= desktopMin;
  static bool showRightContext(double width) => width >= wideMin;
}

class WKWebColors {
  WKWebColors._();

  static const Color pageWarm = LiquidGlassColors.lightBackground;
  static const Color surface = LiquidGlassColors.surfaceSolid;
  static const Color surfaceSoft = Color(0xFFF3F4F6);
  static const Color borderWarm = LiquidGlassColors.borderStrong;
  static const Color action = LiquidGlassColors.primary;
  static const Color actionHover = LiquidGlassColors.primary2;
  static const Color actionSoft = Color(0x144F46E5);
  static const Color online = LiquidGlassColors.online;
  static const Color success = LiquidGlassColors.online;
  static const Color danger = LiquidGlassColors.accent;
  static const Color textPrimary = LiquidGlassColors.text;
  static const Color textSecondary = LiquidGlassColors.textSecondary;
  static const Color textTertiary = LiquidGlassColors.textTertiary;
  static const Color overlayScrim = Color(0x33000000);
  static const Color shadow = LiquidGlassColors.shadow;
}

class WKWebRadius {
  WKWebRadius._();

  static const double control = WKRadius.sm;
  static const double panel = 14;
  static const double avatar = 12;
}

class WKWebSizes {
  WKWebSizes._();

  static const double railWidth = LiquidGlassSizes.navRailWidth;
  static const double conversationListWidth =
      LiquidGlassSizes.conversationListWidth;
  static const double conversationListMinWidth =
      LiquidGlassSizes.conversationListMinWidth;
  static const double chatRightContextWidth =
      LiquidGlassSizes.detailsDrawerWidth;
  static const double chatPaneMinWidth = 420;
  static const double conversationRowHeight =
      LiquidGlassSizes.conversationRowHeight;
  static const double composerMinHeight = 72;
  static const double messageBubbleMinWidth =
      LiquidGlassSizes.messageBubbleMinWidth;
  static const double messageBubbleMaxWidth =
      LiquidGlassSizes.messageBubbleMaxWidth;
  static const double messageBubbleRobotMaxWidth =
      LiquidGlassSizes.messageBubbleRobotMaxWidth;
  static const double messageBubbleWidthRatio =
      LiquidGlassSizes.messageBubbleDesktopRatio;
}

class WKWebPanel extends StatelessWidget {
  const WKWebPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.color = WKWebColors.surface,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(WKWebRadius.panel),
        border: Border.all(color: WKWebColors.borderWarm),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: WKWebColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
