import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Large balance display — primary metric at the top of dashboard screens.
///
/// Two layouts:
/// * dual totals ([spentAmount] + [receivedAmount]) — used on Home.
/// * single [amount] (+ optional [subtitle]) — used on Insights.
///
/// Set [centered] for the Home editorial style (caps label, centered hero
/// number, emerald received line). Left-aligned by default.
class BalanceHeader extends StatelessWidget {
  const BalanceHeader({
    required this.label,
    this.amount,
    this.subtitle,
    this.spentAmount,
    this.receivedAmount,
    this.centered = false,
    super.key,
  });

  final String label;
  final String? amount;
  final String? subtitle;
  final String? spentAmount;
  final String? receivedAmount;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showDualTotals =
        spentAmount != null && receivedAmount != null && amount == null;

    final labelStyle = centered
        ? theme.textTheme.labelSmall?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.05 * 12,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          )
        : theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          );

    final heroStyle = theme.textTheme.displaySmall?.copyWith(
      fontSize: 36,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.02 * 36,
      color: theme.colorScheme.onSurface,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment:
            centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            centered ? label.toUpperCase() : label,
            style: labelStyle,
            textAlign: centered ? TextAlign.center : TextAlign.start,
          ),
          SizedBox(height: centered ? AppSpacing.sm + 2 : AppSpacing.sm),
          if (showDualTotals) ...[
            Text(
              spentAmount!,
              style: heroStyle,
              textAlign: centered ? TextAlign.center : TextAlign.start,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              receivedAmount!,
              style: centered
                  ? theme.textTheme.titleMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accent,
                    )
                  : theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
              textAlign: centered ? TextAlign.center : TextAlign.start,
            ),
          ] else if (amount != null) ...[
            Text(
              amount!,
              style: heroStyle,
              textAlign: centered ? TextAlign.center : TextAlign.start,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.accent,
                ),
                textAlign: centered ? TextAlign.center : TextAlign.start,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
