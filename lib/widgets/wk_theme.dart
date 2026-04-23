import 'package:flutter/material.dart';

import 'wk_colors.dart';
import 'wk_design_tokens.dart';

class WKTheme {
  WKTheme._();

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [WKColors.brand400, WKColors.brand500, WKColors.brand600],
  );

  static const LinearGradient authBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      WKColors.brand50,
      WKColors.pageBackground,
      WKColors.pageBackground,
    ],
    stops: [0, 0.32, 1],
  );

  static ThemeData get themeData {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: WKColors.brand500,
      onPrimary: WKColors.white,
      primaryContainer: WKColors.brand100,
      onPrimaryContainer: WKColors.textPrimary,
      secondary: WKColors.info,
      onSecondary: WKColors.white,
      secondaryContainer: Color(0xFFE6EDFF),
      onSecondaryContainer: WKColors.textPrimary,
      tertiary: WKColors.success,
      onTertiary: WKColors.white,
      tertiaryContainer: Color(0xFFE8F6EF),
      onTertiaryContainer: WKColors.textPrimary,
      error: WKColors.danger,
      onError: WKColors.white,
      errorContainer: Color(0xFFFDECEC),
      onErrorContainer: WKColors.danger,
      surface: WKColors.surface,
      onSurface: WKColors.textPrimary,
      onSurfaceVariant: WKColors.textSecondary,
      outline: WKColors.outline,
      outlineVariant: WKColors.outlineStrong,
      shadow: WKColors.shadow,
      scrim: Color(0x66000000),
      inverseSurface: WKColors.textPrimary,
      onInverseSurface: WKColors.white,
      inversePrimary: WKColors.brand200,
      surfaceContainerHighest: WKColors.surfaceMuted,
    );

    final textTheme = WKTypography.buildTextTheme(
      primary: WKColors.textPrimary,
      secondary: WKColors.textSecondary,
      tertiary: WKColors.textTertiary,
    );

    return ThemeData(
      useMaterial3: false,
      colorScheme: colorScheme,
      primaryColor: WKColors.brand500,
      scaffoldBackgroundColor: WKColors.pageBackground,
      canvasColor: WKColors.pageBackground,
      splashColor: WKColors.brand500.withValues(alpha: 0.08),
      highlightColor: WKColors.brand500.withValues(alpha: 0.04),
      dividerColor: WKColors.outline,
      iconTheme: const IconThemeData(color: WKColors.textSecondary, size: 22),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: WKColors.pageBackground,
        foregroundColor: WKColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 48,
        iconTheme: const IconThemeData(color: WKColors.textSecondary, size: 22),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontFamily: WKFontFamily.title,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: WKColors.textPrimary,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: WKColors.surface,
        surfaceTintColor: Colors.transparent,
        height: 72,
        indicatorColor: WKColors.brand100,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? WKColors.brand500 : WKColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? WKColors.brand500 : WKColors.textSecondary,
            size: 22,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: WKColors.pageBackground,
        selectedItemColor: WKColors.brand500,
        unselectedItemColor: WKColors.textSecondary,
        elevation: 0,
        selectedLabelStyle: textTheme.labelSmall?.copyWith(
          color: WKColors.brand500,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: textTheme.labelSmall?.copyWith(
          color: WKColors.textSecondary,
        ),
        type: BottomNavigationBarType.fixed,
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        labelColor: WKColors.brand500,
        unselectedLabelColor: WKColors.textSecondary,
        indicatorColor: WKColors.brand500,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: WKColors.textSecondary,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: WKColors.textSecondary,
        textColor: WKColors.textPrimary,
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
        fillColor: WKColors.surfaceSoft,
        hintStyle: textTheme.bodyMedium?.copyWith(color: WKColors.textTertiary),
        labelStyle: textTheme.titleSmall?.copyWith(
          color: WKColors.textSecondary,
        ),
        prefixIconColor: WKColors.textSecondary,
        suffixIconColor: WKColors.textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WKRadius.lg),
          borderSide: const BorderSide(color: WKColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WKRadius.lg),
          borderSide: const BorderSide(color: WKColors.outline),
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
          disabledBackgroundColor: WKColors.outlineStrong,
          disabledForegroundColor: WKColors.white,
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
          side: const BorderSide(color: WKColors.outlineStrong),
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
        color: WKColors.surface,
        margin: EdgeInsets.zero,
        elevation: 0,
        shadowColor: WKColors.shadow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WKRadius.md),
          side: const BorderSide(color: WKColors.outline),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: WKColors.outline,
        thickness: 1,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: WKColors.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: WKColors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WKRadius.md),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: WKColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WKRadius.xl),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: WKColors.textSecondary,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: WKColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(WKRadius.xl),
          ),
        ),
      ),
    );
  }

  static Decoration getListBgDecoration({bool isSelected = false}) {
    return BoxDecoration(
      color: isSelected ? WKColors.surfaceMuted : WKColors.surface,
      borderRadius: BorderRadius.circular(WKRadius.lg),
      border: Border.all(
        color: isSelected ? WKColors.brand100 : WKColors.outline,
      ),
      boxShadow: WKShadows.soft,
    );
  }

  static BoxDecoration getListItemDecoration({
    Color? color,
    BorderRadius? borderRadius,
  }) {
    return BoxDecoration(
      color: color ?? WKColors.surface,
      borderRadius: borderRadius ?? BorderRadius.circular(WKRadius.lg),
      border: Border.all(color: WKColors.outline),
      boxShadow: WKShadows.soft,
    );
  }

  static Widget buildDivider({double? height, Color? color}) {
    return Container(height: height ?? 1, color: color ?? WKColors.outline);
  }

  static BoxDecoration getRoundedDecoration({
    required Color color,
    double radius = WKRadius.lg,
    Border? border,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: border,
    );
  }
}
