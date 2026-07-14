import 'package:flutter/material.dart';

/// Single accent palette — green is the only brand hue.
abstract final class AppColors {
  static const Color accent = Color(0xFF10B981);
  static const Color accentMuted = Color(0x3310B981);

  static const Color surfaceLight = Color(0xFFFAFAFA);
  static const Color surfaceDark = Color(0xFF1C1C1E);

  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF2C2C2E);

  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF3A3A3C);

  /// Glass overlay fill (~10% glassmorphism layer).
  static Color glassFill(Brightness brightness) {
    return brightness == Brightness.light
        ? const Color(0xB3FFFFFF)
        : const Color(0xB31C1C1E);
  }

  static Color glassBorder(Brightness brightness) {
    return brightness == Brightness.light
        ? const Color(0x33FFFFFF)
        : const Color(0x33FFFFFF);
  }
}
