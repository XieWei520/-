import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class LiquidGlassColors {
  LiquidGlassColors._();

  static const Color primary = Color(0xFF4F46E5);
  static const Color primary2 = Color(0xFF0284C7);
  static const Color darkPrimary = Color(0xFF6366F1);
  static const Color darkPrimary2 = Color(0xFF0EA5E9);
  static const Color accent = Color(0xFFEF4444);
  static const Color lightBackground = Color(0xFFF7F8FA);
  static const Color darkBackground = Color(0xFF0B0E14);
  static const Color surface = Color(0xF7FFFFFF);
  static const Color surfaceSolid = Color(0xFFFFFFFF);
  static const Color darkSurface = Color(0x991E293B);
  static const Color darkSurfaceSolid = Color(0xFF1E293B);
  static const Color muted = Color(0x080F172A);
  static const Color darkMuted = Color(0x08FFFFFF);
  static const Color text = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color darkText = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary = Color(0xFF64748B);
  static const Color border = Color(0x140F172A);
  static const Color borderStrong = Color(0x1A0F172A);
  static const Color darkBorder = Color(0x0FFFFFFF);
  static const Color darkBorderStrong = Color(0x1AFFFFFF);
  static const Color online = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color shadow = Color(0x0D0F172A);
}

class LiquidGlassGradients {
  LiquidGlassGradients._();

  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[LiquidGlassColors.primary, LiquidGlassColors.primary2],
  );

  static const LinearGradient primaryDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      LiquidGlassColors.darkPrimary,
      LiquidGlassColors.darkPrimary2,
    ],
  );
}

class LiquidGlassRadii {
  LiquidGlassRadii._();

  static const BorderRadius sm = BorderRadius.all(Radius.circular(8));
  static const BorderRadius md = BorderRadius.all(Radius.circular(12));
  static const BorderRadius lg = BorderRadius.all(Radius.circular(14));
  static const BorderRadius xl = BorderRadius.all(Radius.circular(16));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

class LiquidGlassSizes {
  LiquidGlassSizes._();

  static const double navRailWidth = 72;
  static const double pageContentMaxWidth = 920;
  static const double pageContentPadding = 20;
  static const double sectionGap = 12;
  static const double listRowHeight = 64;
  static const double listIconSize = 40;
  static const double listAvatarSize = 44;
  static const double conversationListWidth = 328;
  static const double conversationListMinWidth = 260;
  static const double detailsDrawerWidth = 300;
  static const double appMaxWidth = 1280;
  static const double appFrameViewportInset = 20;
  static const double conversationRowHeight = 68;
  static const double messageBubbleMinWidth = 96;
  static const double messageBubbleMaxWidth = 460;
  static const double messageBubbleRobotMaxWidth = 420;
  static const double messageBubbleDesktopRatio = 0.56;
  static const double messageBubbleMobileRatio = 0.82;
}

class LiquidGlassPanelBlur {
  LiquidGlassPanelBlur._();

  static const double sigmaX = 12;
  static const double sigmaY = 12;
  static final ui.ImageFilter filter = ui.ImageFilter.blur(
    sigmaX: sigmaX,
    sigmaY: sigmaY,
  );
}

class LiquidGlassShadows {
  LiquidGlassShadows._();

  static const List<BoxShadow> sm = <BoxShadow>[
    BoxShadow(color: Color(0x080F172A), blurRadius: 6, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> md = <BoxShadow>[
    BoxShadow(color: Color(0x0D0F172A), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> lg = <BoxShadow>[
    BoxShadow(color: Color(0x100F172A), blurRadius: 22, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> glow = <BoxShadow>[
    BoxShadow(color: Color(0x144F46E5), blurRadius: 10, offset: Offset(0, 3)),
  ];
}

class LiquidGlassMotionDuration {
  const LiquidGlassMotionDuration(this.value);

  final Duration value;

  Duration resolve({required bool disableAnimations}) {
    return disableAnimations ? Duration.zero : value;
  }
}

class LiquidGlassMotion {
  LiquidGlassMotion._();

  static const LiquidGlassMotionDuration fast = LiquidGlassMotionDuration(
    Duration(milliseconds: 180),
  );
  static const LiquidGlassMotionDuration normal = LiquidGlassMotionDuration(
    Duration(milliseconds: 220),
  );
  static const LiquidGlassMotionDuration panelEnter = LiquidGlassMotionDuration(
    Duration(milliseconds: 250),
  );
  static const LiquidGlassMotionDuration toast = LiquidGlassMotionDuration(
    Duration(milliseconds: 350),
  );

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;
}

class LiquidGlassTokens {
  const LiquidGlassTokens({
    required this.surface,
    required this.surfaceSolid,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.borderStrong,
    required this.primaryGradient,
    required this.backdropFilter,
  });

  final Color surface;
  final Color surfaceSolid;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;
  final Color borderStrong;
  final Gradient primaryGradient;
  final ui.ImageFilter backdropFilter;

  static LiquidGlassTokens of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LiquidGlassTokens(
      surface: dark ? LiquidGlassColors.darkSurface : LiquidGlassColors.surface,
      surfaceSolid: dark
          ? LiquidGlassColors.darkSurfaceSolid
          : LiquidGlassColors.surfaceSolid,
      text: dark ? LiquidGlassColors.darkText : LiquidGlassColors.text,
      textSecondary: dark
          ? LiquidGlassColors.darkTextSecondary
          : LiquidGlassColors.textSecondary,
      textTertiary: dark
          ? LiquidGlassColors.darkTextTertiary
          : LiquidGlassColors.textTertiary,
      border: dark ? LiquidGlassColors.darkBorder : LiquidGlassColors.border,
      borderStrong: dark
          ? LiquidGlassColors.darkBorderStrong
          : LiquidGlassColors.borderStrong,
      primaryGradient: dark
          ? LiquidGlassGradients.primaryDark
          : LiquidGlassGradients.primary,
      backdropFilter: LiquidGlassPanelBlur.filter,
    );
  }
}
