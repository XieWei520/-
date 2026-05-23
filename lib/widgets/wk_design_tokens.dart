import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class WKFontFamily {
  WKFontFamily._();

  static const String primary = 'WKRMedium';
  static const String title = primary;
  static const String chinese = 'WKNotoSansSC';
}

class WKSpace {
  WKSpace._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
}

class WKRadius {
  WKRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;
}

class WKShadows {
  WKShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x120F172A), blurRadius: 24, offset: Offset(0, 10)),
  ];

  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x0C0F172A), blurRadius: 18, offset: Offset(0, 6)),
  ];
}

class WKTypography {
  WKTypography._();

  static const List<String> nativeFontFamilyFallback = [
    'WKNotoSansSC',
    'Apple Color Emoji',
    'Segoe UI Emoji',
    'Noto Color Emoji',
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'PingFang SC',
    'Hiragino Sans GB',
    'HarmonyOS Sans SC',
    'SF Pro Text',
    'Segoe UI',
    'Arial',
    'sans-serif',
  ];

  // Web keeps only the subsetted bundled Chinese font on the hot path. The
  // full CJK font is too large for first load and is removed from release
  // artifacts by scripts/ops/prune_flutter_web_release.ps1.
  static const List<String> webFontFamilyFallback = [
    'Noto Color Emoji',
    'WKChineseWebSubset',
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'PingFang SC',
    'Hiragino Sans GB',
    'HarmonyOS Sans SC',
    'SF Pro Text',
    'Segoe UI',
    'Arial',
    'sans-serif',
  ];

  static List<String> get fontFamilyFallback =>
      kIsWeb ? webFontFamilyFallback : nativeFontFamilyFallback;

  static TextTheme buildTextTheme({
    required Color primary,
    required Color secondary,
    required Color tertiary,
  }) {
    return TextTheme(
      displayLarge: _style(36, FontWeight.w700, 1.16, primary),
      displayMedium: _style(32, FontWeight.w700, 1.18, primary),
      displaySmall: _style(28, FontWeight.w700, 1.2, primary),
      headlineLarge: _style(26, FontWeight.w700, 1.22, primary),
      headlineMedium: _style(22, FontWeight.w700, 1.24, primary),
      headlineSmall: _style(20, FontWeight.w600, 1.26, primary),
      titleLarge: _style(18, FontWeight.w700, 1.28, primary),
      titleMedium: _style(16, FontWeight.w600, 1.34, primary),
      titleSmall: _style(14, FontWeight.w600, 1.34, primary),
      bodyLarge: _style(16, FontWeight.w400, 1.5, primary),
      bodyMedium: _style(14, FontWeight.w400, 1.5, secondary),
      bodySmall: _style(12, FontWeight.w400, 1.45, tertiary),
      labelLarge: _style(14, FontWeight.w600, 1.3, primary),
      labelMedium: _style(12, FontWeight.w600, 1.25, secondary),
      labelSmall: _style(11, FontWeight.w500, 1.2, tertiary),
    );
  }

  static TextStyle _style(
    double size,
    FontWeight fontWeight,
    double height,
    Color color,
  ) {
    return TextStyle(
      fontSize: size,
      fontWeight: fontWeight,
      height: height,
      color: color,
      fontFamily: WKFontFamily.primary,
      fontFamilyFallback: fontFamilyFallback,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }
}
