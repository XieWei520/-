import 'package:flutter/material.dart';

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
  static const double panelBorderRadius = 20;
  static const double brandPanelBorderRadius = 20;
  static const double stageShellRadius = 20;
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

  static const Color stageBackgroundTop = Color(0xFFF0F4F8);
  static const Color stageBackgroundBottom = Color(0xFFF0F4F8);
  static const Color stageGlowPrimary = Color(0x334F46E5);
  static const Color stageGlowSecondary = Color(0x260284C7);
  static const Color stageGlowTertiary = Color(0x2E9A7B4C);
  static const Color stageShellTop = Color(0xFFFFFFFF);
  static const Color stageShellBottom = Color(0xFFFFFFFF);
  static const Color stageShellBorder = Color(0x120F172A);
  static const List<BoxShadow> stageShellShadow = [
    BoxShadow(color: Color(0x17172433), blurRadius: 24, offset: Offset(0, 10)),
  ];

  static const Color panelBackground = Color(0xFFFFFFFF);
  static const Color panelBorder = Color(0x120F172A);
  static const Color panelInk = Color(0xFF172033);
  static const Color panelMuted = Color(0xFF64748B);

  static const Color brandPanelBackground = Color(0xA6FFFFFF);
  static const Color brandPanelOverlay = Color(0x1F4F46E5);
  static const Color brandInk = Color(0xFF172033);
  static const Color brandMuted = Color(0xFF64748B);
  static const Color brandAccent = Color(0xFF4F46E5);
  static const Color brandAccentStrong = Color(0xFF4338CA);
  static const Color brandChipBackground = Color(0x1F4F46E5);
  static const Color brandChipBorder = Color(0x334F46E5);

  static const Color inputFill = Color(0xFFFFFFFF);
  static const Color inputHint = Color(0xFF475569);
  static const Color inputText = Color(0xFF172033);
  static const Color inputBorder = Color(0x800F172A);
  static const Color inputBorderFocus = Color(0xFF0284C7);
  static const Color inputFillDisabled = Color(0xFFFFEDD5);
  static const Color fieldBackground = inputFill;
  static const Color fieldBackgroundDisabled = inputFillDisabled;
  static const Color fieldBorder = inputBorder;
  static const Color fieldBorderHover = Color(0x33596578);
  static const Color fieldBorderFocus = inputBorderFocus;
  static const Color fieldBorderError = Color(0xFFC65C57);
  static const Color fieldFocusShadow = Color(0x290284C7);
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

class AuthExperiencePalette {
  const AuthExperiencePalette({
    required this.stageBackgroundBottom,
    required this.stageShellTop,
    required this.stageShellBottom,
    required this.stageShellBorder,
    required this.panelBackground,
    required this.panelInk,
    required this.panelMuted,
    required this.brandPanelBackground,
    required this.brandPanelOverlay,
    required this.brandInk,
    required this.brandMuted,
    required this.brandAccent,
    required this.brandAccentStrong,
    required this.brandChipBackground,
    required this.brandChipBorder,
    required this.inputFill,
    required this.inputFillDisabled,
    required this.inputHint,
    required this.inputText,
    required this.inputBorder,
    required this.inputBorderFocus,
    required this.fieldBorderError,
    required this.helperText,
    required this.errorText,
  });

  final Color stageBackgroundBottom;
  final Color stageShellTop;
  final Color stageShellBottom;
  final Color stageShellBorder;
  final Color panelBackground;
  final Color panelInk;
  final Color panelMuted;
  final Color brandPanelBackground;
  final Color brandPanelOverlay;
  final Color brandInk;
  final Color brandMuted;
  final Color brandAccent;
  final Color brandAccentStrong;
  final Color brandChipBackground;
  final Color brandChipBorder;
  final Color inputFill;
  final Color inputFillDisabled;
  final Color inputHint;
  final Color inputText;
  final Color inputBorder;
  final Color inputBorderFocus;
  final Color fieldBorderError;
  final Color helperText;
  final Color errorText;

  static const AuthExperiencePalette light = AuthExperiencePalette(
    stageBackgroundBottom: AuthExperienceTokens.stageBackgroundBottom,
    stageShellTop: AuthExperienceTokens.stageShellTop,
    stageShellBottom: AuthExperienceTokens.stageShellBottom,
    stageShellBorder: AuthExperienceTokens.stageShellBorder,
    panelBackground: AuthExperienceTokens.panelBackground,
    panelInk: AuthExperienceTokens.panelInk,
    panelMuted: AuthExperienceTokens.panelMuted,
    brandPanelBackground: AuthExperienceTokens.brandPanelBackground,
    brandPanelOverlay: AuthExperienceTokens.brandPanelOverlay,
    brandInk: AuthExperienceTokens.brandInk,
    brandMuted: AuthExperienceTokens.brandMuted,
    brandAccent: AuthExperienceTokens.brandAccent,
    brandAccentStrong: AuthExperienceTokens.brandAccentStrong,
    brandChipBackground: AuthExperienceTokens.brandChipBackground,
    brandChipBorder: AuthExperienceTokens.brandChipBorder,
    inputFill: AuthExperienceTokens.inputFill,
    inputFillDisabled: AuthExperienceTokens.inputFillDisabled,
    inputHint: AuthExperienceTokens.inputHint,
    inputText: AuthExperienceTokens.inputText,
    inputBorder: AuthExperienceTokens.inputBorder,
    inputBorderFocus: AuthExperienceTokens.inputBorderFocus,
    fieldBorderError: AuthExperienceTokens.fieldBorderError,
    helperText: AuthExperienceTokens.helperText,
    errorText: AuthExperienceTokens.errorText,
  );

  static const AuthExperiencePalette dark = AuthExperiencePalette(
    stageBackgroundBottom: Color(0xFF0B0E14),
    stageShellTop: Color(0x991E293B),
    stageShellBottom: Color(0x991E293B),
    stageShellBorder: Color(0x1AFFFFFF),
    panelBackground: Color(0xFF111827),
    panelInk: Color(0xFFF8FAFC),
    panelMuted: Color(0xFF94A3B8),
    brandPanelBackground: Color(0x661E293B),
    brandPanelOverlay: Color(0x1F6366F1),
    brandInk: Color(0xFFF8FAFC),
    brandMuted: Color(0xFF475569),
    brandAccent: Color(0xFF6366F1),
    brandAccentStrong: Color(0xFF93C5FD),
    brandChipBackground: Color(0x1F6366F1),
    brandChipBorder: Color(0x336366F1),
    inputFill: Color(0xFF1E293B),
    inputFillDisabled: Color(0xFF111827),
    inputHint: Color(0xFFCBD5E1),
    inputText: Color(0xFFF8FAFC),
    inputBorder: Color(0x66FFFFFF),
    inputBorderFocus: Color(0xFF93C5FD),
    fieldBorderError: Color(0xFFFCA5A5),
    helperText: Color(0xFFCBD5E1),
    errorText: Color(0xFFFCA5A5),
  );

  static AuthExperiencePalette of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}
