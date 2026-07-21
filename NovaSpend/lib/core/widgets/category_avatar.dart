import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../utils/category_visuals.dart';

/// Rounded-square icon tile representing a transaction category.
///
/// Reusable across transaction lists, merchant pages and detail headers.
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

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.neutralFill(brightness),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(
        categoryIcon(category),
        size: size * 0.42,
        color: iconColor ?? AppColors.primaryStrong,
      ),
    );
  }
}
