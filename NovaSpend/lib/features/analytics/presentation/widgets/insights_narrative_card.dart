import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/app_card.dart';
import 'package:nova_spend/features/analytics/domain/insights_math.dart';
import 'package:nova_spend/features/categories/presentation/widgets/category_catalog_scope.dart';
import 'package:nova_spend/features/analytics/presentation/widgets/insights_category_bars.dart';
import 'package:nova_spend/l10n/app_localizations.dart';
import 'package:nova_spend/l10n/app_strings.dart';

class InsightsNarrativeCard extends StatelessWidget {
  const InsightsNarrativeCard({
    required this.facts,
    required this.formatMoney,
    this.aiNarrative,
    this.isLoadingNarrative = false,
    super.key,
  });

  final InsightsNarrativeFacts facts;
  final String Function(double amount) formatMoney;
  final String? aiNarrative;
  final bool isLoadingNarrative;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (isLoadingNarrative && (aiNarrative?.trim().isEmpty ?? true)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.insightsWhatChanged,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 48,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final text = aiNarrative?.trim().isNotEmpty == true
        ? aiNarrative!.trim()
        : _templateText(l10n, facts, formatMoney, context);
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.insightsWhatChanged,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _templateText(
  AppLocalizations l10n,
  InsightsNarrativeFacts facts,
  String Function(double amount) formatMoney,
  BuildContext context,
) {
  if (!facts.hasContent) return null;
  final catalog = CategoryCatalogScope.of(context);
  final parts = <String>[];
  final change = facts.spendChangePercent;
  if (change != null) {
    final percent = change.abs().round().toString();
    if (change.abs() < 1) {
      parts.add(l10n.insightsNarrativeSpendFlat);
    } else if (change > 0) {
      parts.add(l10n.insightsNarrativeSpendUp(percent));
    } else {
      parts.add(l10n.insightsNarrativeSpendDown(percent));
    }
  }
  if (facts.topCategory != null && facts.topCategoryShare != null) {
    parts.add(
      l10n.insightsNarrativeTopCategory(
        categoryDisplayName(catalog, facts.topCategory!),
        (facts.topCategoryShare! * 100).round().toString(),
      ),
    );
  }
  if (facts.topMerchant != null && facts.topMerchantAmount != null) {
    parts.add(
      l10n.insightsNarrativeTopMerchant(
        facts.topMerchant!,
        formatMoney(facts.topMerchantAmount!),
      ),
    );
  }
  if (parts.isEmpty) return null;
  return parts.join(' ');
}
