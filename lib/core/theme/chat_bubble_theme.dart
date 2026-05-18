import 'package:flutter/material.dart';

import '../../widgets/wk_colors.dart';

/// Chat bubble visual design tokens.
///
/// Provides:
/// - Gradient background for outgoing (sender) bubbles
/// - Subtle shadow for incoming (receiver) bubbles
/// - Asymmetric border radius: sender right-bottom 4dp, others 16dp
/// - Dark mode aware colors
class ChatBubbleTheme {
  ChatBubbleTheme._();

  // ── Border radii ───────────────────────────────────────────────

  /// Outgoing bubble: right-bottom corner is tight (4dp), rest is 16dp.
  static const BorderRadius outgoingRadius = BorderRadius.only(
    topLeft: Radius.circular(16),
    topRight: Radius.circular(16),
    bottomLeft: Radius.circular(16),
    bottomRight: Radius.circular(4),
  );

  /// Incoming bubble: left-bottom corner is tight (4dp), rest is 16dp.
  static const BorderRadius incomingRadius = BorderRadius.only(
    topLeft: Radius.circular(16),
    topRight: Radius.circular(16),
    bottomLeft: Radius.circular(4),
    bottomRight: Radius.circular(16),
  );

  /// System / tip message radius.
  static const BorderRadius systemRadius = BorderRadius.all(
    Radius.circular(12),
  );

  // ── Outgoing bubble gradient ────────────────────────────────────

  /// Light-mode outgoing bubble gradient (brand warm → deeper warm).
  static const LinearGradient outgoingGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2F80ED), Color(0xFF2563D9)],
  );

  /// Dark-mode outgoing bubble gradient (muted warm tones).
  static const LinearGradient outgoingGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563D9), Color(0xFF1D4ED8)],
  );

  // ── Incoming bubble colors ──────────────────────────────────────

  static const Color incomingBgLight = Colors.white;
  static const Color incomingBgDark = Color(0xFF171D27);
  static const Color incomingBorderLight = Color(0xFFE4E8EF);
  static const Color incomingBorderDark = Color(0xFF2B3442);

  // ── Shadows ─────────────────────────────────────────────────────

  /// Subtle shadow for incoming bubbles (light mode).
  static const List<BoxShadow> incomingShadowLight = [
    BoxShadow(color: Color(0x0A111827), blurRadius: 5, offset: Offset(0, 1)),
  ];

  /// Very subtle shadow for incoming bubbles (dark mode).
  static const List<BoxShadow> incomingShadowDark = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 5, offset: Offset(0, 1)),
  ];

  /// Barely visible elevation for outgoing bubbles.
  static const List<BoxShadow> outgoingShadowLight = [
    BoxShadow(color: Color(0x142563D9), blurRadius: 5, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> outgoingShadowDark = [
    BoxShadow(color: Color(0x26000000), blurRadius: 5, offset: Offset(0, 1)),
  ];

  // ── Text colors ─────────────────────────────────────────────────

  static const Color outgoingTextLight = Colors.white;
  static const Color outgoingTextDark = Colors.white;
  static const Color incomingTextLight = Color(0xFF111827);
  static const Color incomingTextDark = Color(0xFFE5EAF2);

  // ── Read receipts ───────────────────────────────────────────────

  static const Color readTickColor = Color(0xFF60A5FA);
  static const Color unreadTickColor = WKColors.textTertiary;

  // ── Image overlay in dark mode ──────────────────────────────────

  /// 8% white overlay applied to images in dark mode to soften them.
  static const Color darkModeImageOverlay = Color(0x14FFFFFF);

  // ── Convenience builders ────────────────────────────────────────

  /// Returns the appropriate [BoxDecoration] for an outgoing bubble.
  static BoxDecoration outgoingDecoration(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return BoxDecoration(
      gradient: isDark ? outgoingGradientDark : outgoingGradientLight,
      borderRadius: outgoingRadius,
      boxShadow: isDark ? outgoingShadowDark : outgoingShadowLight,
    );
  }

  /// Returns the appropriate [BoxDecoration] for an incoming bubble.
  static BoxDecoration incomingDecoration(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? incomingBgDark : incomingBgLight,
      borderRadius: incomingRadius,
      boxShadow: isDark ? incomingShadowDark : incomingShadowLight,
      border: Border.all(
        color: isDark ? incomingBorderDark : incomingBorderLight,
      ),
    );
  }

  /// Text color for a bubble given sender status and brightness.
  static Color textColor({
    required bool isSelf,
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;
    if (isSelf) {
      return isDark ? outgoingTextDark : outgoingTextLight;
    }
    return isDark ? incomingTextDark : incomingTextLight;
  }
}
