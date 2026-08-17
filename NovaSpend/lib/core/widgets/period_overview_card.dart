import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

/// Period summary card — spent, received, and net with optional trend lines.
class PeriodOverviewCard extends StatelessWidget {
  const PeriodOverviewCard({
    required this.title,
    required this.spentLabel,
    required this.spentAmount,
    required this.receivedLabel,
    required this.receivedAmount,
    required this.netLabel,
    required this.netAmount,
    this.spentChangePercent,
    this.receivedChangePercent,
    this.netChangePercent,
    this.trendSuffix,
    this.spentIsZero = false,
    this.receivedIsZero = false,
    this.netIsZero = false,
    this.netIsNegative = false,
    super.key,
  });

  final String title;
  final String spentLabel;
  final String spentAmount;
  final String receivedLabel;
  final String receivedAmount;
  final String netLabel;
  final String netAmount;
  final double? spentChangePercent;
  final double? receivedChangePercent;
  final double? netChangePercent;

  /// Trailing copy for trends, e.g. "vs last month".
  final String? trendSuffix;
  final bool spentIsZero;
  final bool receivedIsZero;
  final bool netIsZero;
  final bool netIsNegative;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;
    final border = AppColors.cardBorder(brightness);
    final dividerColor = AppColors.border(brightness).withValues(
      alpha: isDark ? 0.45 : 0.35,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.card(brightness),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _OverviewRow(
                label: spentLabel,
                amount: spentAmount,
                amountColor: theme.colorScheme.onSurface,
                amountIsZero: spentIsZero,
                changePercent: spentChangePercent,
                trendSuffix: trendSuffix,
                positiveIsGood: false,
                dividerBelow: true,
                dividerColor: dividerColor,
              ),
              _OverviewRow(
                label: receivedLabel,
                amount: receivedAmount,
                amountColor: AppColors.primaryStrong,
                amountIsZero: receivedIsZero,
                changePercent: receivedChangePercent,
                trendSuffix: trendSuffix,
                positiveIsGood: true,
                dividerBelow: true,
                dividerColor: dividerColor,
              ),
              _OverviewRow(
                label: netLabel,
                amount: netAmount,
                amountColor: netIsNegative
                    ? AppColors.spend
                    : AppColors.primaryStrong,
                amountIsZero: netIsZero,
                changePercent: netChangePercent,
                trendSuffix: trendSuffix,
                positiveIsGood: true,
                dividerBelow: false,
                dividerColor: dividerColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    required this.label,
    required this.amount,
    required this.amountColor,
    required this.amountIsZero,
    required this.changePercent,
    required this.trendSuffix,
    required this.positiveIsGood,
    required this.dividerBelow,
    required this.dividerColor,
  });

  final String label;
  final String amount;
  final Color amountColor;
  final bool amountIsZero;
  final double? changePercent;
  final String? trendSuffix;
  final bool positiveIsGood;
  final bool dividerBelow;
  final Color dividerColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedAmountColor = amountIsZero
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55)
        : amountColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing:0.06 * 11,
            height: 1.3,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                amount,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.02 * 20,
                  height: 1.2,
                  color: resolvedAmountColor,
                ),
              ),
            ),
            if (changePercent != null && trendSuffix != null)
              _TrendBadge(
                percent: changePercent!,
                suffix: trendSuffix!,
                positiveIsGood: positiveIsGood,
              ),
          ],
        ),
        if (dividerBelow) ...[
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, thickness: 1, color: dividerColor),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({
    required this.percent,
    required this.suffix,
    required this.positiveIsGood,
  });

  final double percent;
  final String suffix;
  final bool positiveIsGood;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUp = percent >= 0;
    final isGood = positiveIsGood ? isUp : !isUp;
    final trendColor =
        isGood ? AppColors.primaryStrong : AppColors.spend;
    final suffixColor =
        theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
    final displayPercent = percent.abs().round();

    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm, top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 14,
            color: trendColor,
          ),
          const SizedBox(width: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$displayPercent%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: trendColor,
                  ),
                ),
                TextSpan(
                  text: ' $suffix',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                    color: suffixColor,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}
