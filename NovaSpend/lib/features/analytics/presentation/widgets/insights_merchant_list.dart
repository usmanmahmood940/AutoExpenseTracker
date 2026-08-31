import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/app_card.dart';
import 'package:nova_spend/features/analytics/domain/entities/monthly_summary_entity.dart';
import 'package:nova_spend/features/analytics/domain/insights_math.dart';
import 'package:nova_spend/features/merchants/presentation/pages/merchant_page.dart';
import 'package:nova_spend/l10n/app_strings.dart';

import '../../../../core/constants/app_constants.dart';

class InsightsMerchantList extends StatelessWidget {
  const InsightsMerchantList({
    required this.summary,
    required this.formatMoney,
    super.key,
  });

  final MonthlySummaryEntity summary;
  final String Function(double amount) formatMoney;

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
              name: top[i].key,
              amount: top[i].value,
              amountLabel: formatMoney(top[i].value),
              visits: stats[top[i].key]?.visitCount,
              merchantNormalized: stats[top[i].key]?.merchantNormalized ??
                  normalizeMerchantKey(top[i].key),
              formatMoney: formatMoney,
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
    required this.name,
    required this.amount,
    required this.amountLabel,
    required this.merchantNormalized,
    required this.formatMoney,
    required this.showDivider,
    required this.textTheme,
    required this.brightness,
    this.visits,
  });

  final String name;
  final double amount;
  final String amountLabel;
  final String merchantNormalized;
  final String Function(double amount) formatMoney;
  final bool showDivider;
  final TextTheme textTheme;
  final Brightness brightness;
  final int? visits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accentFill = AppColors.navActiveFill(brightness);
    final accentInk = AppColors.navActiveForeground(brightness);
    final muted = textTheme.bodySmall?.copyWith(
      color: cs.onSurface.withValues(alpha: 0.55),
    );
    final String? meta;
    if (visits != null && visits! > 0) {
      final visitsLabel = context.l10n.insightsVisitCount(visits!);
      meta = visits! > 3
          ? context.l10n.insightsMerchantMeta(
              visitsLabel,
              formatMoney(amount / visits!),
            )
          : visitsLabel;
    } else {
      meta = null;
    }

    return Column(
      children: [
        Semantics(
          button: true,
          label: meta != null ? '$name, $meta, $amountLabel' : '$name, $amountLabel',
          child: InkWell(
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
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.smPlus2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: accentFill,
                    child: Text(
                      _avatarLetter(name),
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accentInk,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.smPlus2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        if (meta != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: muted,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    amountLabel,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
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

String _avatarLetter(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed[0].toUpperCase();
}
