import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/app_card.dart';

class InsightsKpiRow extends StatelessWidget {
  const InsightsKpiRow({
    required this.spentLabel,
    required this.spentValue,
    required this.receivedLabel,
    required this.receivedValue,
    required this.countLabel,
    required this.countValue,
    super.key,
  });

  final String spentLabel;
  final String spentValue;
  final String receivedLabel;
  final String receivedValue;
  final String countLabel;
  final String countValue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(child: _KpiCard(label: spentLabel, value: spentValue)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _KpiCard(label: receivedLabel, value: receivedValue),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _KpiCard(label: countLabel, value: countValue)),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.smPlus2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
