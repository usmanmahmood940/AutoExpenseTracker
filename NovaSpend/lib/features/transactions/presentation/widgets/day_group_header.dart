import 'package:flutter/material.dart';

import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';

/// Header above a day's transaction group: a relative day [label] on the left
/// and an optional day summary on the right (spent total or positive net).
class DayGroupHeader extends StatelessWidget {
  const DayGroupHeader({
    required this.label,
    this.summaryPrefix,
    this.summaryAmount,
    this.summaryAmountColor,
    super.key,
  });

  final String label;
  final String? summaryPrefix;
  final String? summaryAmount;
  final Color? summaryAmountColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final showSummary =
        summaryPrefix != null &&
        summaryAmount != null &&
        summaryAmount!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
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
      amountColor: AppColors.primaryStrong,
    );
  }

  if (spent <= 0) return (prefix: null, amount: null, amountColor: null);

  return (
    prefix: spentPrefix,
    amount: formatMoney(spent),
    amountColor: null,
  );
}
