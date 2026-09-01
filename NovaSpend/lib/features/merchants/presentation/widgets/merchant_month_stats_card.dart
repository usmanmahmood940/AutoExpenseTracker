import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/app_card.dart';
import 'package:nova_spend/features/merchants/domain/entities/merchant_summary_entity.dart';
import 'package:nova_spend/l10n/app_strings.dart';

class MerchantMonthStatsCard extends StatelessWidget {
  const MerchantMonthStatsCard({
    required this.summary,
    required this.formatMoney,
    super.key,
  });

  final MerchantSummaryEntity summary;
  final String Function(double amount) formatMoney;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final avgThisMonth = summary.thisMonthVisits > 0
        ? summary.thisMonthSpent / summary.thisMonthVisits
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.merchantThisMonthTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _MetricColumn(
                    label: l10n.merchantStatSpentLabel,
                    value: formatMoney(summary.thisMonthSpent),
                  ),
                ),
                Expanded(
                  child: _MetricColumn(
                    label: l10n.merchantStatVisitsLabel,
                    value: '${summary.thisMonthVisits}',
                  ),
                ),
                Expanded(
                  child: _MetricColumn(
                    label: l10n.merchantStatAvgLabel,
                    value: formatMoney(avgThisMonth),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MerchantInsightLine extends StatelessWidget {
  const MerchantInsightLine({
    required this.summary,
    required this.formatMoney,
    super.key,
  });

  final MerchantSummaryEntity summary;
  final String Function(double amount) formatMoney;

  @override
  Widget build(BuildContext context) {
    if (summary.thisMonthVisits <= 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = context.l10n;
    final avgThisMonth = summary.thisMonthSpent / summary.thisMonthVisits;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Text(
        l10n.merchantInsightThisMonth(
          '${summary.thisMonthVisits}',
          formatMoney(avgThisMonth),
        ),
        style: theme.textTheme.bodyMedium?.copyWith(
          height: 1.45,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: muted.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
