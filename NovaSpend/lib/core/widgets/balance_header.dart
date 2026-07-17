import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Large balance display — primary metric at the top of dashboard screens.
class BalanceHeader extends StatelessWidget {
  const BalanceHeader({
    required this.label,
    this.amount,
    this.subtitle,
    this.spentAmount,
    this.receivedAmount,
    super.key,
  });

  final String label;
  final String? amount;
  final String? subtitle;
  final String? spentAmount;
  final String? receivedAmount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showDualTotals =
        spentAmount != null && receivedAmount != null && amount == null;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (showDualTotals) ...[
            Text(
              spentAmount!,
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              receivedAmount!,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ] else if (amount != null) ...[
            Text(
              amount!,
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.accent,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
