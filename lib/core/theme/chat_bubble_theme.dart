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
    topRight: Radius.circular(4),
    bottomLeft: Radius.circular(16),
    bottomRight: Radius.circular(16),
  );

  /// Incoming bubble: left-bottom corner is tight (4dp), rest is 16dp.
  static const BorderRadius incomingRadius = BorderRadius.only(
    topLeft: Radius.circular(4),
    topRight: Radius.circular(16),
    bottomLeft: Radius.circular(16),
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
    colors: [
      Color(0xFFFDE4DC), // light peach
      Color(0xFFFDDED6), // chatOutgoing
      Color(0xFFF8C9BD), // slightly deeper
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// Dark-mode outgoing bubble gradient (muted warm tones).
  static const LinearGradient outgoingGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF3D2823), // dark warm brown
      Color(0xFF352220), // deeper
    ],
  );

  // ── Incoming bubble colors ──────────────────────────────────────

  static const Color incomingBgLight = WKColors.surface;
  static const Color incomingBgDark = Color(0xFF1E1E1E);

  // ── Shadows ─────────────────────────────────────────────────────

  /// Subtle shadow for incoming bubbles (light mode).
  static const List<BoxShadow> incomingShadowLight = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Very subtle shadow for incoming bubbles (dark mode).
  static const List<BoxShadow> incomingShadowDark = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 6,
      offset: Offset(0, 1),
    ),
  ];

  // ── Text colors ─────────────────────────────────────────────────

  static const Color outgoingTextLight = Color(0xFF2D1A14);
  static const Color outgoingTextDark = Color(0xFFE8D5CF);
  static const Color incomingTextLight = WKColors.textPrimary;
  static const Color incomingTextDark = Color(0xFFE0E0E0);

  // ── Read receipts ───────────────────────────────────────────────

  static const Color readTickColor = Color(0xFF2196F3);
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
    );
  }

  /// Returns the appropriate [BoxDecoration] for an incoming bubble.
  static BoxDecoration incomingDecoration(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? incomingBgDark : incomingBgLight,
      borderRadius: incomingRadius,
      boxShadow: isDark ? incomingShadowDark : incomingShadowLight,
      border: isDark ? null : Border.all(color: const Color(0x0A000000)),
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
