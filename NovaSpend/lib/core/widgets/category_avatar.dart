import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../utils/category_visuals.dart';

/// Icon tile representing a transaction category.
///
/// Reusable across transaction lists, merchant pages and detail headers.
/// Icons are Lucide SVGs — same stroke weight, tinted with [iconColor].
/// Use [circular] for detail heroes; lists keep the default rounded square.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({
    required this.category,
    this.size = 48,
    this.iconColor,
    this.backgroundColor,
    this.circular = false,
    this.showBorder = false,
    super.key,
  });

  final String? category;
  final double size;
  final Color? iconColor;
  final Color? backgroundColor;
  final bool circular;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final color = iconColor ?? AppColors.primaryStrong;
    final iconSize = size * 0.42;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.neutralFill(brightness),
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(AppRadius.sm),
        border: showBorder
            ? Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              )
            : null,
        boxShadow: circular && !isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        categoryIconAsset(category),
        width: iconSize,
        height: iconSize,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}
