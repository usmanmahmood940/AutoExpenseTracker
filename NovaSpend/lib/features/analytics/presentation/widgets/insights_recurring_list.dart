import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
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
    final l10n = context.l10n;
    final brightness = theme.brightness;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MerchantPage(
                      merchantNormalized: items[i].merchantNormalized,
                      displayName: items[i].displayName,
                    ),
                  ),
                );
              },
              title: Text(
                items[i].displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                l10n.insightsRecurringMeta(
                  items[i].count.toString(),
                  formatMoney(items[i].averageAmount),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              trailing: Text(
                DateFormat.MMMd().format(items[i].lastDate),
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (i != items.length - 1)
              Divider(
                height: 1,
                color: AppColors.border(brightness).withValues(alpha: 0.35),
              ),
          ],
        ],
      ),
    );
  }
}
