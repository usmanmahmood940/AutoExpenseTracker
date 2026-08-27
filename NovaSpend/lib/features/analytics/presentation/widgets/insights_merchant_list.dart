import 'package:flutter/material.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/app_card.dart';
import 'package:nova_spend/features/analytics/domain/entities/monthly_summary_entity.dart';
import 'package:nova_spend/features/analytics/domain/insights_math.dart';
import 'package:nova_spend/features/merchants/presentation/pages/merchant_page.dart';

class InsightsMerchantList extends StatelessWidget {
  const InsightsMerchantList({
    required this.summary,
    required this.formatMoney,
    this.visitLabel,
    super.key,
  });

  final MonthlySummaryEntity summary;
  final String Function(double amount) formatMoney;
  final String Function(int count)? visitLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = summary.byMerchantStats;
    final top = topEntries(summary.byMerchant);
    if (top.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          for (var i = 0; i < top.length; i++)
            _MerchantRow(
              rank: i + 1,
              name: top[i].key,
              amountLabel: formatMoney(top[i].value),
              visits: stats[top[i].key]?.visitCount,
              visitLabel: visitLabel,
              merchantNormalized: stats[top[i].key]?.merchantNormalized ??
                  normalizeMerchantKey(top[i].key),
              showDivider: i != top.length - 1,
              textTheme: theme.textTheme,
              brightness: theme.brightness,
            ),
        ],
      ),
    );
  }
}

class _MerchantRow extends StatelessWidget {
  const _MerchantRow({
    required this.rank,
    required this.name,
    required this.amountLabel,
    required this.merchantNormalized,
    required this.showDivider,
    required this.textTheme,
    required this.brightness,
    this.visits,
    this.visitLabel,
  });

  final int rank;
  final String name;
  final String amountLabel;
  final String merchantNormalized;
  final bool showDivider;
  final TextTheme textTheme;
  final Brightness brightness;
  final int? visits;
  final String Function(int count)? visitLabel;

  @override
  Widget build(BuildContext context) {
    final muted = textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
    );

    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          minLeadingWidth: 72,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MerchantPage(
                  merchantNormalized: merchantNormalized,
                  displayName: name,
                ),
              ),
            );
          },
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                child: Text(
                  '$rank',
                  style: muted,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.neutralFill(brightness),
                child: Text(
                  merchantInitials(name),
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          title: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: visits != null && visits! > 0 && visitLabel != null
              ? Text(visitLabel!(visits!), style: muted)
              : null,
          trailing: Text(amountLabel, style: textTheme.bodyMedium),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: AppColors.border(brightness).withValues(alpha: 0.35),
          ),
      ],
    );
  }
}
