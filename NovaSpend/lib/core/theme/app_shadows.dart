import 'package:flutter/material.dart';

/// Shared ambient shadows for raised cards and controls.
abstract final class AppShadows {
  static List<BoxShadow> card(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
    ];
  }
}
