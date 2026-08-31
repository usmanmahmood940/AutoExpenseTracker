import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/features/analytics/domain/insights_math.dart';
import 'package:nova_spend/features/analytics/presentation/widgets/insights_category_bars.dart';
import 'package:nova_spend/features/categories/presentation/widgets/category_catalog_scope.dart';
import 'package:nova_spend/l10n/app_localizations.dart';
import 'package:nova_spend/l10n/app_strings.dart';

class InsightsNarrativeCard extends StatelessWidget {
  const InsightsNarrativeCard({
    required this.facts,
    required this.formatMoney,
    this.useMonthComparisonCopy = true,
    this.aiNarrative,
    this.isLoadingNarrative = false,
    super.key,
  });

  final InsightsNarrativeFacts facts;
  final String Function(double amount) formatMoney;
  final bool useMonthComparisonCopy;
  final String? aiNarrative;
  final bool isLoadingNarrative;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accentInk = AppColors.navActiveForeground(brightness);

    if (isLoadingNarrative && (aiNarrative?.trim().isEmpty ?? true)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: _NarrativeCardShell(
          child: SizedBox(
            height: 72,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: accentInk,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final copy = _resolveCopy(context);
    if (copy.headline == null && copy.body == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: _NarrativeCardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TrendIcon(isIncrease: copy.isIncrease),
                const SizedBox(width: AppSpacing.smPlus2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (copy.headline != null)
                        Text(
                          copy.headline!,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                                color: accentInk,
                              ),
                        ),
                      if (copy.body != null) ...[
                        if (copy.headline != null)
                          const SizedBox(height: AppSpacing.sm),
                        Text(
                          copy.body!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                height: 1.45,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  _NarrativeCopy _resolveCopy(BuildContext context) {
    final l10n = context.l10n;
    final aiText = aiNarrative?.trim();
    final hasAi = aiText?.isNotEmpty == true;

    final change = facts.spendChangePercent;
    final delta = facts.spendDelta;
    String? headline;
    String? body;
    bool? isIncrease;

    if (change != null && delta != null) {
      final percent = change.abs().round().toString();
      final amount = formatMoney(delta.abs());
      if (change.abs() < 1) {
        headline = l10n.insightsNarrativeHeadlineSpendFlat;
        body = useMonthComparisonCopy
            ? l10n.insightsNarrativeSpendDeltaFlat
            : l10n.insightsNarrativeSpendDeltaFlatGeneric;
        isIncrease = null;
      } else if (change > 0) {
        headline = useMonthComparisonCopy
            ? l10n.insightsNarrativeHeadlineSpendUp(percent)
            : l10n.insightsNarrativeHeadlineSpendUpGeneric(percent);
        body = useMonthComparisonCopy
            ? l10n.insightsNarrativeSpendDeltaUp(amount)
            : l10n.insightsNarrativeSpendDeltaUpGeneric(amount);
        isIncrease = true;
      } else {
        headline = useMonthComparisonCopy
            ? l10n.insightsNarrativeHeadlineSpendDown(percent)
            : l10n.insightsNarrativeHeadlineSpendDownGeneric(percent);
        body = useMonthComparisonCopy
            ? l10n.insightsNarrativeSpendDeltaDown(amount)
            : l10n.insightsNarrativeSpendDeltaDownGeneric(amount);
        isIncrease = false;
      }
    }

    if (hasAi) {
      body = aiText;
      headline ??= l10n.insightsWhatChanged;
    } else if (body == null) {
      body = _fallbackBody(l10n, context);
      headline ??= l10n.insightsWhatChanged;
    }

    if (headline == null && body == null) {
      return const _NarrativeCopy();
    }

    return _NarrativeCopy(
      headline: headline,
      body: body,
      isIncrease: isIncrease,
    );
  }

  String? _fallbackBody(AppLocalizations l10n, BuildContext context) {
    if (!facts.hasContent) return null;
    return _templateText(l10n, facts, formatMoney, context);
  }
}

class _NarrativeCopy {
  const _NarrativeCopy({
    this.headline,
    this.body,
    this.isIncrease,
  });

  final String? headline;
  final String? body;
  final bool? isIncrease;
}

class _NarrativeCardShell extends StatelessWidget {
  const _NarrativeCardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.navActiveFill(brightness),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.border(brightness).withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: child,
      ),
    );
  }
}

class _TrendIcon extends StatelessWidget {
  const _TrendIcon({this.isIncrease});

  final bool? isIncrease;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final ink = AppColors.navActiveForeground(brightness);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.card(brightness),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: isIncrease == false
          ? Icon(Icons.trending_down_rounded, size: 22, color: ink)
          : SvgPicture.asset(
              'assets/icons/icon_nav_insights.svg',
              width: 22,
              height: 22,
              colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
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
