import 'package:flutter/material.dart';

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

  static const Color pageWarm = Color(0xFFFFFAF5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFFFF7ED);
  static const Color borderWarm = Color(0xFFFED7AA);
  static const Color action = Color(0xFFC2410C);
  static const Color actionHover = Color(0xFF9A3412);
  static const Color actionSoft = Color(0xFFFFEDD5);
  static const Color online = Color(0xFF0D9488);
  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color overlayScrim = Color(0x33000000);
  static const Color shadow = Color(0x17172433);
}

class WKWebRadius {
  WKWebRadius._();

  static const double control = WKRadius.sm;
  static const double panel = 10;
  static const double avatar = 12;
}

class WKWebSizes {
  WKWebSizes._();

  static const double railWidth = 64;
  static const double conversationListWidth = 336;
  static const double conversationListMinWidth = 300;
  static const double chatRightContextWidth = 280;
  static const double conversationRowHeight = 76;
  static const double composerMinHeight = 72;
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
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
