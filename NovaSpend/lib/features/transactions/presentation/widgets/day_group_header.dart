import 'package:flutter/material.dart';

import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';

/// Header above a day's transaction group: a relative day [label] on the left
/// and an optional day summary on the right (spent total or positive net).
///
/// When [embedded] is true the header is an in-card band with a neutral fill
/// (full-bleed + tighter vertical padding).
class DayGroupHeader extends StatelessWidget {
  const DayGroupHeader({
    required this.label,
    this.summaryPrefix,
    this.summaryAmount,
    this.summaryAmountColor,
    this.embedded = false,
    super.key,
  });

  final String label;
  final String? summaryPrefix;
  final String? summaryAmount;
  final Color? summaryAmountColor;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = Color.lerp(
      theme.colorScheme.onSurfaceVariant,
      theme.colorScheme.onSurface,
      1,
    )!;
    final showSummary =
        summaryPrefix != null &&
        summaryAmount != null &&
        summaryAmount!.isNotEmpty;

    final row = Padding(
      padding: embedded
          ? const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.smPlus,
            )
          : const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: muted,
            ),
          ),
          if (showSummary)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: summaryPrefix,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: muted,
                    ),
                  ),
                  TextSpan(
                    text: summaryAmount,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.05 * 11,
                      color: summaryAmountColor ?? muted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    if (!embedded) return row;

    return ColoredBox(
      color: AppColors.neutralFill(theme.brightness).withValues(alpha: 0.35),
      child: row,
    );
  }
}

/// Builds day-group summary fields for [DayGroupHeader].
({String? prefix, String? amount, Color? amountColor}) dayGroupSummary({
  required double spent,
  required double received,
  required String spentPrefix,
  required String netPrefix,
  required String Function(double amount) formatMoney,
}) {
  if (received > spent) {
    final net = received - spent;
    if (net <= 0) return (prefix: null, amount: null, amountColor: null);
    return (
      prefix: netPrefix,
      amount: '+${formatMoney(net)}',
      amountColor: AppColors.accent,
    );
  }

  if (spent <= 0) return (prefix: null, amount: null, amountColor: null);

  return (
    prefix: spentPrefix,
    amount: formatMoney(spent),
    amountColor: null,
  );
}
