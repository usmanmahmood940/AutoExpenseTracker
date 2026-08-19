import 'package:flutter/material.dart';

/// Single accent palette — green is the only brand hue.
///
/// Two green tones per the NovaSpend design system (`docs/design-system.md`):
/// [accent] is the vivid emerald "primary-container" (fills, positive amounts,
/// links, active states); [primaryStrong] is the deeper "primary" green used
/// for on-light glyphs (wordmark, category icons, FAB).
abstract final class AppColors {
  static const Color accent = Color(0xFF006C49);
  static const Color accentMuted = Color(0x3310B981);

  /// Deeper "primary" green — for icons/wordmark on light surfaces.
  static const Color primaryStrong = Color(0xFF006C49);

  /// Text/glyph color on an [accent] emerald fill (on-primary-container).
  static const Color onAccent = Color(0xFF00422B);

  /// Soft fill behind the selected bottom-nav destination.
  static const Color navActiveFillLight = Color(0xFFE8F5EB);
  static const Color navActiveFillDark = Color(0xFF1B3A2C);

  /// Glyph/label on the selected bottom-nav destination (dark).
  /// Light mode uses [accent].
  static const Color navActiveForegroundDark = Color(0xFF4EDEA3);

  /// Debit/"spend" red — used only for high-impact debit emphasis (e.g. the
  /// highest-spend highlight badge), never as decoration.
  static const Color spend = Color(0xFFB61722);


  static const Color surfaceLight = Color(0xFFF9F9F9);
  static const Color surfaceDark = Color(0xFF1C1C1E);

  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF2C2C2E);

  /// Neutral fill behind category icons / avatars (surface-container-high).
  static const Color neutralFillLight = Color(0xFFE8E8E8);
  static const Color neutralFillDark = Color(0xFF3A3A3C);

  static const Color borderLight = Color(0xFFBBCABF);
  static const Color borderDark = Color(0xFF3A3A3C);

  /// Warning / needs-review chip (light).
  static const Color warningFgLight = Color(0xFF9A6700);
  static const Color warningBgLight = Color(0xFFFFF4CE);

  /// Warning / needs-review chip (dark).
  static const Color warningFgDark = Color(0xFFFFD666);
  static const Color warningBgDark = Color(0xFF3D2E00);

  /// Glass overlay fill (~80% opacity surface, per design "Subtle Glass").
  static Color glassFill(Brightness brightness) {
    return brightness == Brightness.light
        ? const Color(0xCCF9F9F9)
        : const Color(0xCC1C1C1E);
  }

  static Color glassBorder(Brightness brightness) {
    return brightness == Brightness.light
        ? borderLight.withValues(alpha: 0.6)
        : borderDark.withValues(alpha: 0.6);
  }

  /// Page / scaffold surface for the current brightness.
  static Color surface(Brightness brightness) {
    return brightness == Brightness.light ? surfaceLight : surfaceDark;
  }

  /// Raised card surface for the current brightness.
  static Color card(Brightness brightness) {
    return brightness == Brightness.light ? cardLight : cardDark;
  }

  /// Hairline / field border for the current brightness.
  static Color border(Brightness brightness) {
    return brightness == Brightness.light ? borderLight : borderDark;
  }

  /// Softer outline for raised cards (lower contrast than field borders).
  static Color cardBorder(Brightness brightness) {
    return border(brightness).withValues(
      alpha: brightness == Brightness.light ? 0.7 : 0.45,
    );
  }

  /// Neutral avatar/icon fill for the current brightness.
  static Color neutralFill(Brightness brightness) {
    return brightness == Brightness.light ? neutralFillLight : neutralFillDark;
  }

  static Color warningForeground(Brightness brightness) {
    return brightness == Brightness.light ? warningFgLight : warningFgDark;
  }

  static Color warningBackground(Brightness brightness) {
    return brightness == Brightness.light ? warningBgLight : warningBgDark;
  }

  /// Pale green pill behind the selected bottom-nav item.
  static Color navActiveFill(Brightness brightness) {
    return brightness == Brightness.light
        ? navActiveFillLight
        : navActiveFillDark;
  }

  /// Icon and label color for the selected bottom-nav item.
  static Color navActiveForeground(Brightness brightness) {
    return brightness == Brightness.light
        ? accent
        : navActiveForegroundDark;
  }
}
