import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/utils/category_visuals.dart';
import 'package:nova_spend/core/widgets/app_card.dart';
import 'package:nova_spend/core/widgets/category_avatar.dart';
import 'package:nova_spend/core/widgets/category_color_scope.dart';
import 'package:nova_spend/features/analytics/domain/insights_math.dart';
import 'package:nova_spend/features/categories/domain/entities/category_entity.dart';
import 'package:nova_spend/features/categories/presentation/widgets/category_catalog_scope.dart';
import 'package:nova_spend/l10n/app_strings.dart';

class InsightsCategoryBars extends StatelessWidget {
  const InsightsCategoryBars({
    required this.byCategory,
    required this.totalSpent,
    required this.formatMoney,
    this.onCategoryTap,
    super.key,
  });

  final Map<String, double> byCategory;
  final double totalSpent;
  final String Function(double amount) formatMoney;
  final void Function(String categoryKey, String displayName)? onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final top = topEntries(byCategory);
    if (top.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(child: Text(context.l10n.insightsEmpty)),
      );
    }

    final catalog = CategoryCatalogScope.of(context);

    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < top.length; i++) ...[
            if (i != 0) const SizedBox(height: AppSpacing.smPlus2),
            _CategoryBarRow(
              categoryKey: top[i].key,
              displayName: categoryDisplayName(catalog, top[i].key),
              amountLabel: formatMoney(top[i].value),
              amount: top[i].value,
              totalSpent: totalSpent,
              onTap: onCategoryTap,
            ),
          ],
        ],
      ),
    );
  }
}

String categoryDisplayName(List<CategoryEntity> catalog, String key) {
  for (final category in catalog) {
    if (category.id == key ||
        category.name.toLowerCase() == key.toLowerCase()) {
      return category.name;
    }
  }
  return key;
}

class _CategoryBarRow extends StatelessWidget {
  const _CategoryBarRow({
    required this.categoryKey,
    required this.displayName,
    required this.amountLabel,
    required this.amount,
    required this.totalSpent,
    required this.onTap,
  });

  final String categoryKey;
  final String displayName;
  final String amountLabel;
  final double amount;
  final double totalSpent;
  final void Function(String categoryKey, String displayName)? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final share = shareOfTotal(amount, totalSpent);
    final storedHex =
        CategoryColorScope.maybeOf(context)?.hexFor(categoryKey);
    final color = categoryColor(categoryKey, storedHex: storedHex);

    return InkWell(
      onTap: onTap == null ? null : () => onTap!(categoryKey, displayName),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Row(
        children: [
          CategoryAvatar(category: categoryKey, size: 36),
          const SizedBox(width: AppSpacing.smPlus2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${(share * 100).round()}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: share.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor:
                        theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96),
            child: Text(
              amountLabel,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
