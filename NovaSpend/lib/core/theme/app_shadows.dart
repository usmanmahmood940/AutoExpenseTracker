import 'package:flutter/material.dart';

/// Shared ambient shadows for raised cards and controls.
abstract final class AppShadows {
  static List<BoxShadow> card(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ];
  }
}
