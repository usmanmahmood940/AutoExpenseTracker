import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Restricted gradients — hero wash and chart underfill only.
///
/// Do not use on FAB, filled buttons, or every card. Product chrome stays flat.
abstract final class AppGradients {
  /// Height of the page-top wash behind Home / Insights hero content.
  static const double heroWashHeight = 280;

  /// Soft vertical wash: mint/forest → canvas. Bottom stop matches [AppColors.surface].
  static LinearGradient heroWash(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        isLight ? const Color(0xFFE8F5EE) : const Color(0xFF0A1F18),
        isLight ? AppColors.surfaceLight : AppColors.surfaceDark,
      ],
    );
  }

  /// Area under a primary chart series: emerald 35% → transparent.
  static LinearGradient chartArea(Brightness brightness) {
    final top = AppColors.positiveAmount(brightness).withValues(alpha: 0.35);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [top, top.withValues(alpha: 0)],
    );
  }
}
