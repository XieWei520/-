import 'package:flutter/material.dart';

import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';

/// Dark theme configuration using Material 3 `ColorScheme.fromSeed`.
///
/// Pairs with [WKTheme.themeData] (the light theme) in `app.dart` via
/// `darkTheme: WKDarkTheme.themeData`.
class WKDarkTheme {
  WKDarkTheme._();

  /// Brand-seeded dark color scheme.
  static ColorScheme get colorScheme {
    return ColorScheme.fromSeed(
      seedColor: WKColors.brand500,
      brightness: Brightness.dark,
    );
  }

  // ── Surface palette ────────────────────────────────────────────

  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceSoft = Color(0xFF2A2A2A);
  static const Color surfaceStrong = Color(0xFF333333);

  // ── Text palette ───────────────────────────────────────────────

  static const Color textPrimary = Color(0xFFE0E0E0);
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color textTertiary = Color(0xFF757575);

  // ── Outline ────────────────────────────────────────────────────

  static const Color outline = Color(0xFF3D3D3D);
  static const Color outlineStrong = Color(0xFF555555);

  // ── Chat bubbles (dark) ────────────────────────────────────────

  static const Color chatOutgoing = Color(0xFF352220);
  static const Color chatOutgoingPressed = Color(0xFF4A302C);
  static const Color chatIncoming = surface;
  static const Color chatIncomingPressed = surfaceSoft;

  // ── ThemeData ──────────────────────────────────────────────────

  static ThemeData get themeData {
    final scheme = colorScheme;

    final textTheme = WKTypography.buildTextTheme(
      primary: textPrimary,
      secondary: textSecondary,
      tertiary: textTertiary,
    );

    return ThemeData(
      useMaterial3: false,
      brightness: Brightness.dark,
      colorScheme: scheme,
      primaryColor: WKColors.brand500,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      splashColor: WKColors.brand500.withValues(alpha: 0.12),
      highlightColor: WKColors.brand500.withValues(alpha: 0.08),
      dividerColor: outline,
      iconTheme: const IconThemeData(color: textSecondary, size: 22),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 48,
        iconTheme: const IconThemeData(color: textSecondary, size: 22),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontFamily: WKFontFamily.title,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        height: 72,
        indicatorColor: WKColors.brand500.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? WKColors.brand500 : textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? WKColors.brand500 : textSecondary,
            size: 22,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: WKColors.brand500,
        unselectedItemColor: textSecondary,
        elevation: 0,
        selectedLabelStyle: textTheme.labelSmall?.copyWith(
          color: WKColors.brand500,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: textTheme.labelSmall?.copyWith(
          color: textSecondary,
        ),
        type: BottomNavigationBarType.fixed,
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        labelColor: WKColors.brand500,
        unselectedLabelColor: textSecondary,
        indicatorColor: WKColors.brand500,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: WKSpace.md,
          vertical: 2,
        ),
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall,
        minLeadingWidth: 44,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSoft,
        hintStyle: textTheme.bodyMedium?.copyWith(color: textTertiary),
        labelStyle: textTheme.titleSmall?.copyWith(color: textSecondary),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WKRadius.lg),
          borderSide: const BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WKRadius.lg),
          borderSide: const BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WKRadius.lg),
          borderSide: const BorderSide(color: WKColors.brand500, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WKRadius.lg),
          borderSide: const BorderSide(color: WKColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WKRadius.lg),
          borderSide: const BorderSide(color: WKColors.danger, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WKColors.brand500,
          foregroundColor: WKColors.white,
          disabledBackgroundColor: outlineStrong,
          disabledForegroundColor: textTertiary,
          elevation: 0,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: WKSpace.lg,
            vertical: WKSpace.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WKRadius.lg),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: WKColors.brand500,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: WKSpace.lg,
            vertical: WKSpace.sm,
          ),
          side: const BorderSide(color: outlineStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WKRadius.lg),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: WKColors.brand500,
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: WKColors.brand500,
        foregroundColor: WKColors.white,
        elevation: 0,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: WKColors.brand500,
      ),
      cardTheme: CardThemeData(
        color: surface,
        margin: EdgeInsets.zero,
        elevation: 0,
        shadowColor: Colors.black26,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WKRadius.md),
          side: const BorderSide(color: outline),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: outline,
        thickness: 1,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceStrong,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WKRadius.md),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WKRadius.xl),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(WKRadius.xl),
          ),
        ),
      ),
    );
  }
}
