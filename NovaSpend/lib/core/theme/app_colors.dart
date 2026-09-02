import 'package:flutter/material.dart';

/// NovaSpend color tokens — emerald brand, green-tinted neutrals.
///
/// Role split (do not collapse these):
/// * [primaryStrong] — deep emerald for on-light ink, FAB, filled buttons
///   (white-on-mint fails contrast; keep CTAs on this fill).
/// * [accent] — vivid emerald for credits, charts, positive momentum.
/// * [inversePrimary] — dark-mode ink / received amounts / chart series.
///
/// Semantic reds stay separate: [spend] for debit emphasis, [error] for
/// destructive / validation, warning helpers for needs-review chips.
abstract final class AppColors {
  // --- Brand ---

  /// Vivid emerald — credits, charts, positive amounts. Never body text
  /// on light surfaces (fails WCAG).
  static const Color accent = Color(0xFF10B981);

  static const Color accentMuted = Color(0x3310B981);

  /// Deeper primary — icons, links, wordmark, FAB, filled buttons.
  static const Color primaryStrong = Color(0xFF006C49);

  /// Dark-mode primary ink (Material inverse-primary).
  static const Color inversePrimary = Color(0xFF4EDEA3);

  /// Glyph on a [primaryStrong] fill.
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Glyph on a dark-mode mint / primaryContainer fill.
  static const Color onPrimaryDark = Color(0xFF002113);

  /// Text/glyph on an [accent] emerald fill (on-primary-container, light).
  static const Color onAccent = Color(0xFF00422B);

  /// Dark primary-container fill (nav pills, soft accent surfaces).
  static const Color primaryContainerDark = Color(0xFF005236);

  /// Full-screen splash — matches [assets/branding/app_icon.png].
  static const Color splashBackground = Color(0xFF0D4A32);

  /// Soft fill behind the selected bottom-nav destination.
  static const Color navActiveFillLight = Color(0xFFE8F5EB);
  static const Color navActiveFillDark = Color(0xFF005236);

  /// Glyph/label on the selected bottom-nav destination (dark).
  /// Light mode uses [primaryStrong].
  static const Color navActiveForegroundDark = Color(0xFF4EDEA3);

  // --- Semantic ---

  /// Debit/"spend" red (light) — high-impact debit emphasis only.
  static const Color spend = Color(0xFFB61722);

  /// Debit emphasis on dark surfaces.
  static const Color spendDark = Color(0xFFFFB3AD);

  static const Color error = Color(0xFFBA1A1A);
  static const Color errorDark = Color(0xFFFFB4AB);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color errorContainerDark = Color(0xFF93000A);

  // --- Surfaces ---

  static const Color surfaceLight = Color(0xFFF6FAF8);
  static const Color surfaceDark = Color(0xFF121614);

  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF242B28);

  /// Neutral fill behind category icons / avatars.
  static const Color neutralFillLight = Color(0xFFE4EBE7);
  static const Color neutralFillDark = Color(0xFF2E3632);

  static const Color borderLight = Color(0xFFC5D4CB);
  static const Color borderDark = Color(0xFF3A4340);

  static const Color outlineLight = Color(0xFF8FA396);
  static const Color outlineDark = Color(0xFF4A5650);

  static const Color onSurfaceLight = Color(0xFF141917);
  static const Color onSurfaceDark = Color(0xFFE8EDEA);

  static const Color onSurfaceVariantLight = Color(0xFF3C4A42);
  static const Color onSurfaceVariantDark = Color(0xFF9CAEA4);

  /// Warning / needs-review chip (light).
  static const Color warningFgLight = Color(0xFF9A6700);
  static const Color warningBgLight = Color(0xFFFEF3C7);

  /// Warning / needs-review chip (dark).
  static const Color warningFgDark = Color(0xFFFFD666);
  static const Color warningBgDark = Color(0xFF3D2E00);

  // --- Brightness helpers ---

  /// Deep green on light, mint on dark — icons, links, labels on surfaces.
  static Color primaryInk(Brightness brightness) {
    return brightness == Brightness.light ? primaryStrong : inversePrimary;
  }

  /// Vivid emerald on light, mint on dark — credits, received, charts.
  static Color positiveAmount(Brightness brightness) {
    return brightness == Brightness.light ? accent : inversePrimary;
  }

  static Color spendForeground(Brightness brightness) {
    return brightness == Brightness.light ? spend : spendDark;
  }

  static Color errorForeground(Brightness brightness) {
    return brightness == Brightness.light ? error : errorDark;
  }

  /// Glass overlay fill (~82% light / ~85% dark).
  static Color glassFill(Brightness brightness) {
    return brightness == Brightness.light
        ? const Color(0xD1F6FAF8)
        : const Color(0xD9121614);
  }

  static Color glassBorder(Brightness brightness) {
    return brightness == Brightness.light
        ? borderLight.withValues(alpha: 0.6)
        : borderDark.withValues(alpha: 0.6);
  }

  static Color surface(Brightness brightness) {
    return brightness == Brightness.light ? surfaceLight : surfaceDark;
  }

  static Color card(Brightness brightness) {
    return brightness == Brightness.light ? cardLight : cardDark;
  }

  static Color border(Brightness brightness) {
    return brightness == Brightness.light ? borderLight : borderDark;
  }

  /// Hairline for raised cards (lower contrast than field borders).
  static Color cardBorder(Brightness brightness) {
    return border(brightness).withValues(
      alpha: brightness == Brightness.light ? 0.7 : 0.55,
    );
  }

  static Color outline(Brightness brightness) {
    return brightness == Brightness.light ? outlineLight : outlineDark;
  }

  static Color onSurface(Brightness brightness) {
    return brightness == Brightness.light ? onSurfaceLight : onSurfaceDark;
  }

  static Color onSurfaceVariant(Brightness brightness) {
    return brightness == Brightness.light
        ? onSurfaceVariantLight
        : onSurfaceVariantDark;
  }

  static Color neutralFill(Brightness brightness) {
    return brightness == Brightness.light ? neutralFillLight : neutralFillDark;
  }

  static Color warningForeground(Brightness brightness) {
    return brightness == Brightness.light ? warningFgLight : warningFgDark;
  }

  static Color warningBackground(Brightness brightness) {
    return brightness == Brightness.light ? warningBgLight : warningBgDark;
  }

  static Color navActiveFill(Brightness brightness) {
    return brightness == Brightness.light
        ? navActiveFillLight
        : navActiveFillDark;
  }

  static Color navActiveForeground(Brightness brightness) {
    return brightness == Brightness.light
        ? primaryStrong
        : navActiveForegroundDark;
  }
}
