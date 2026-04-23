import 'package:flutter/material.dart';

import '../../../../widgets/wk_design_tokens.dart';

class AuthExperienceTokens {
  AuthExperienceTokens._();

  static const String stageBackgroundKey = 'auth-stage-background';
  static const String pagePanelKey = 'auth-page-panel';
  static const String stageShellKey = 'auth-stage-shell';
  static const String brandPanelKey = 'auth-brand-panel';
  static const String formPanelKey = 'auth-form-panel';
  static const String mobileBrandHeaderKey = 'auth-mobile-brand-header';

  static const double desktopPanelMaxWidth = 540;
  static const double desktopStageMaxWidth = 1220;
  static const double desktopBrandPanelWidth = 560;
  static const double desktopStageGap = 24;
  static const double pageHorizontalPadding = 20;
  static const double pageTopPadding = 34;
  static const double pageBottomPadding = 30;
  static const double mobileBrandHeaderHeight = 190;

  static const EdgeInsets panelPadding = EdgeInsets.fromLTRB(30, 32, 30, 30);
  static const EdgeInsets brandPanelPadding = EdgeInsets.fromLTRB(
    40,
    42,
    36,
    36,
  );
  static const EdgeInsets mobileBrandHeaderPadding = EdgeInsets.fromLTRB(
    22,
    24,
    22,
    20,
  );
  static const double panelBorderRadius = WKRadius.xl;
  static const double brandPanelBorderRadius = 34;
  static const double stageShellRadius = 42;
  static const double titleToBodySpacing = 24;
  static const double subtitleSpacing = 8;
  static const double sectionSpacing = 20;
  static const double footerSpacing = 20;
  static const double statusBannerSpacing = 16;
  static const double primaryActionSpacing = 20;
  static const double secondaryActionSpacing = 12;
  static const double brandHighlightSpacing = 10;

  static const double actionButtonHeight = 50;
  static const double actionButtonRadius = 26;
  static const double minimumTouchTarget = 44;

  static const Color stageBackgroundTop = Color(0xFF111B2D);
  static const Color stageBackgroundBottom = Color(0xFF060B15);
  static const Color stageGlowPrimary = Color(0x33E4C88E);
  static const Color stageGlowSecondary = Color(0x26385175);
  static const Color stageGlowTertiary = Color(0x2E9A7B4C);
  static const Color stageShellTop = Color(0xFF131E31);
  static const Color stageShellBottom = Color(0xFF0A1221);
  static const Color stageShellBorder = Color(0x3D546A8A);
  static const List<BoxShadow> stageShellShadow = [
    BoxShadow(color: Color(0x5A03060D), blurRadius: 56, offset: Offset(0, 30)),
    BoxShadow(color: Color(0x1FE4C88E), blurRadius: 30, offset: Offset(0, 12)),
  ];

  static const Color panelBackground = Color(0xFFF8F5EE);
  static const Color panelBorder = Color(0x2BA69575);
  static const Color panelInk = Color(0xFF1C2737);
  static const Color panelMuted = Color(0xFF667186);

  static const Color brandPanelBackground = Color(0xFF0F1A2E);
  static const Color brandPanelOverlay = Color(0x1EE0C387);
  static const Color brandInk = Color(0xFFF4EBDD);
  static const Color brandMuted = Color(0xFF8C99B2);
  static const Color brandAccent = Color(0xFFC8A66A);
  static const Color brandAccentStrong = Color(0xFFE2C68F);
  static const Color brandChipBackground = Color(0x1C25344D);
  static const Color brandChipBorder = Color(0x45E2C68F);

  static const Color inputFill = Color(0xFFFCF8F1);
  static const Color inputHint = Color(0xFF8A8391);
  static const Color inputText = Color(0xFF1F2A3B);
  static const Color inputBorder = Color(0x33505D71);
  static const Color inputBorderFocus = Color(0xFFC8A66A);
  static const Color inputFillDisabled = Color(0xFFF0EBE2);
  static const Color fieldBackground = inputFill;
  static const Color fieldBackgroundDisabled = inputFillDisabled;
  static const Color fieldBorder = inputBorder;
  static const Color fieldBorderHover = Color(0x33596578);
  static const Color fieldBorderFocus = inputBorderFocus;
  static const Color fieldBorderError = Color(0xFFC65C57);
  static const Color fieldFocusShadow = Color(0x29C8A66A);
  static const Color helperText = Color(0xFF707C90);
  static const Color errorText = Color(0xFFB14A45);

  static const Color statusInfoBackground = Color(0xFFE9EEF8);
  static const Color statusInfoForeground = Color(0xFF34445F);
  static const Color statusSuccessBackground = Color(0xFFE7F4EC);
  static const Color statusSuccessForeground = Color(0xFF2A6A4A);
  static const Color statusWarningBackground = Color(0xFFF8F0E2);
  static const Color statusWarningForeground = Color(0xFF8C632B);
  static const Color statusErrorBackground = Color(0xFFF9ECEB);
  static const Color statusErrorForeground = Color(0xFFA44A45);
}
