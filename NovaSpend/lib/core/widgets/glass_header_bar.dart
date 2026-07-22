import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fixed glass top bar — matches Figma Header - TopAppBar.
///
/// Sits at the top of the screen (including status-bar inset), with backdrop
/// blur, 80% surface fill, and a 1px bottom border. Content scrolls underneath.
///
/// Height is always [topInset] + [defaultBarHeight] so the bar never expands
/// and steals taps from content below.
class GlassHeaderBar extends StatelessWidget {
  const GlassHeaderBar({
    required this.title,
    this.actions,
    this.barHeight = defaultBarHeight,
    super.key,
  });

  final Widget title;
  final List<Widget>? actions;
  final double barHeight;

  /// Toolbar height below the status bar (Figma: 64px).
  static const double defaultBarHeight = 64;

  /// Total height including status-bar inset.
  static double totalHeight(BuildContext context, {double barHeight = defaultBarHeight}) {
    return MediaQuery.paddingOf(context).top + barHeight;
  }

  /// Top padding for scroll content clearing the fixed header.
  static double contentTopPadding(BuildContext context) {
    return totalHeight(context) + 16;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final topInset = MediaQuery.paddingOf(context).top;
    final isDark = brightness == Brightness.dark;
    final height = topInset + barHeight;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.glassFill(brightness),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? AppColors.borderDark.withValues(alpha: 0.6)
                      : AppColors.borderLight,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(top: topInset),
              child: SizedBox(
                height: barHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(child: title),
                      ...?actions,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
