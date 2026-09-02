import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';

/// Application theme — minimal surfaces, deep-green CTAs, vivid emerald accent.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = _colorScheme(brightness);
    final surface = AppColors.surface(brightness);
    final card = AppColors.card(brightness);
    final border = AppColors.border(brightness);

    final textTheme = _textTheme(
      GoogleFonts.interTextTheme(
        isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
      ),
      colorScheme.onSurface,
      colorScheme.onSurfaceVariant,
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      textTheme: textTheme,
      fontFamily: GoogleFonts.inter().fontFamily,
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: surface,
        foregroundColor: colorScheme.onSurface,
      ),
      // Flat deep-green CTA — not colorScheme.primary (mint in dark).
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryStrong,
        foregroundColor: AppColors.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.xl)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryStrong,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.primaryStrong.withValues(
            alpha: 0.38,
          ),
          disabledForegroundColor: AppColors.onPrimary.withValues(alpha: 0.38),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryInk(brightness),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(
            color: AppColors.primaryStrong,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        space: AppSpacing.lg,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.onPrimary;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryStrong;
          }
          return null;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primaryInk(brightness),
      ),
    );
  }

  static ColorScheme _colorScheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ColorScheme(
      brightness: brightness,
      primary: isDark ? AppColors.inversePrimary : AppColors.primaryStrong,
      onPrimary: isDark ? AppColors.onPrimaryDark : AppColors.onPrimary,
      primaryContainer: isDark ? AppColors.primaryContainerDark : AppColors.accent,
      onPrimaryContainer:
          isDark ? const Color(0xFFA7F3D0) : AppColors.onAccent,
      secondary: AppColors.spendForeground(brightness),
      onSecondary: isDark ? const Color(0xFF410004) : AppColors.onPrimary,
      secondaryContainer: isDark ? const Color(0xFF930013) : const Color(0xFFDA3437),
      onSecondaryContainer:
          isDark ? const Color(0xFFFFDAD7) : const Color(0xFFFFFBFF),
      tertiary: isDark ? const Color(0xFFFFB3AF) : const Color(0xFFA43A3A),
      onTertiary: isDark ? const Color(0xFF410005) : AppColors.onPrimary,
      error: AppColors.errorForeground(brightness),
      onError: isDark ? const Color(0xFF690005) : AppColors.onPrimary,
      errorContainer:
          isDark ? AppColors.errorContainerDark : AppColors.errorContainer,
      onErrorContainer:
          isDark ? AppColors.errorContainer : const Color(0xFF93000A),
      surface: AppColors.surface(brightness),
      onSurface: AppColors.onSurface(brightness),
      onSurfaceVariant: AppColors.onSurfaceVariant(brightness),
      outline: AppColors.outline(brightness),
      outlineVariant: AppColors.border(brightness),
      inverseSurface: isDark ? AppColors.surfaceLight : const Color(0xFF2F3131),
      onInverseSurface:
          isDark ? AppColors.onSurfaceLight : AppColors.onSurfaceDark,
      inversePrimary:
          isDark ? AppColors.primaryStrong : AppColors.inversePrimary,
      surfaceTint: isDark ? AppColors.inversePrimary : AppColors.primaryStrong,
    );
  }

  static TextTheme _textTheme(
    TextTheme base,
    Color onSurface,
    Color onSurfaceVariant,
  ) {
    return base.copyWith(
      displayMedium: base.displayMedium?.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: onSurface,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        color: onSurface.withValues(alpha: 0.87),
      ),
      bodySmall: base.bodySmall?.copyWith(
        color: onSurfaceVariant,
      ),
    );
  }
}
