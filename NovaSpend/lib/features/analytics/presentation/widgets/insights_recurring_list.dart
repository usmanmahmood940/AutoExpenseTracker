import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/app_card.dart';
import 'package:nova_spend/features/analytics/domain/entities/recurring_merchant_entity.dart';
import 'package:nova_spend/features/merchants/presentation/pages/merchant_page.dart';
import 'package:nova_spend/l10n/app_strings.dart';

class InsightsRecurringList extends StatelessWidget {
  const InsightsRecurringList({
    required this.items,
    required this.formatMoney,
    super.key,
  });

  final List<RecurringMerchantEntity> items;
  final String Function(double amount) formatMoney;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            _RecurringRow(
              item: items[i],
              amountLabel: formatMoney(items[i].averageAmount),
              showDivider: i != items.length - 1,
              textTheme: theme.textTheme,
              brightness: theme.brightness,
            ),
        ],
      ),
    );
  }
}

class _RecurringRow extends StatelessWidget {
  const _RecurringRow({
    required this.item,
    required this.amountLabel,
    required this.showDivider,
    required this.textTheme,
    required this.brightness,
  });

  final RecurringMerchantEntity item;
  final String amountLabel;
  final bool showDivider;
  final TextTheme textTheme;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accentFill = AppColors.navActiveFill(brightness);
    final accentInk = AppColors.navActiveForeground(brightness);
    final muted = textTheme.bodySmall?.copyWith(
      color: cs.onSurface.withValues(alpha: 0.55),
    );
    final meta = context.l10n.insightsRecurringMeta(
      context.l10n.insightsRecurringChargeCount(item.count),
      DateFormat.MMMd().format(item.lastDate),
    );

    return Column(
      children: [
        Semantics(
          button: true,
          label: '${item.displayName}, $meta, $amountLabel',
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MerchantPage(
                    merchantNormalized: item.merchantNormalized,
                    displayName: item.displayName,
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
                      _avatarLetter(item.displayName),
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
                          item.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: muted,
                        ),
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
