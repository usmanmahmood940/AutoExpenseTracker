import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Bordered container that stacks a set of rows (typically
/// `TransactionListTile`s) separated by inset hairline dividers.
///
/// Provides the "one card per day group" look on Home, and is reusable anywhere
/// a grouped list of tiles is needed (search results, merchant history).
class TransactionGroupCard extends StatelessWidget {
  const TransactionGroupCard({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: AppSpacing.md,
            endIndent: AppSpacing.md,
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        );
      }
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Column(children: rows),
      ),
    );
  }
}
