import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Compact stat tile: a caps label + tinted icon badge, a headline value and a
/// muted subtitle. Two of these sit side by side under the balance header
/// ("Highest spend" / "Highest received"), but it's reusable for any KPI pair.
class StatHighlightCard extends StatelessWidget {
  const StatHighlightCard({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.amount,
    required this.subtitle,
    this.amountColor,
    this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;

  /// Drives the icon color and its 10%-opacity badge background.
  final Color accentColor;
  final String amount;

  /// Caption under the amount (e.g. merchant name).
  final String subtitle;
  final Color? amountColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final content = Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.05 * 12,
                    color: theme.colorScheme.onSurface,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs + 1),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 12, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            amount,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.01 * 18,
              color: amountColor ?? theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: content,
      ),
    );
  }
}
