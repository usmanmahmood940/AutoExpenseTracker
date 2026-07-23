import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../utils/category_visuals.dart';

/// Rounded-square icon tile representing a transaction category.
///
/// Reusable across transaction lists, merchant pages and detail headers.
/// Icons are Lucide SVGs — same stroke weight, tinted with [iconColor].
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({
    required this.category,
    this.size = 48,
    this.iconColor,
    this.backgroundColor,
    super.key,
  });

  final String? category;
  final double size;
  final Color? iconColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = iconColor ?? AppColors.primaryStrong;
    final iconSize = size * 0.42;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.neutralFill(brightness),
        borderRadius: BorderRadius.circular(AppRadius.sm),
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
