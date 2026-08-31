import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/core/currency/app_currency_controller.dart';
import 'package:nova_spend/core/currency/app_currency_scope.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/adaptive_scaffold.dart';
import 'package:nova_spend/core/widgets/app_loader.dart';
import 'package:nova_spend/core/widgets/app_segmented_toggle.dart';
import 'package:nova_spend/core/widgets/empty_state_view.dart';
import 'package:nova_spend/core/widgets/error_state_view.dart';
import 'package:nova_spend/core/widgets/section_header.dart';
import 'package:nova_spend/core/widgets/skeleton.dart';
import 'package:nova_spend/features/analytics/domain/insights_math.dart';
import 'package:nova_spend/features/analytics/presentation/provider/insights_provider.dart';
import 'package:nova_spend/features/analytics/presentation/widgets/insights_category_bars.dart';
import 'package:nova_spend/features/analytics/presentation/widgets/insights_kpi_row.dart';
import 'package:nova_spend/features/analytics/presentation/widgets/insights_merchant_list.dart';
import 'package:nova_spend/features/analytics/presentation/widgets/insights_narrative_card.dart';
import 'package:nova_spend/features/analytics/presentation/widgets/insights_recurring_list.dart';
import 'package:nova_spend/features/analytics/presentation/widgets/insights_trend_chart.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/search/presentation/provider/search_provider.dart';
import 'package:nova_spend/features/settings/presentation/main_shell_scope.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:provider/provider.dart';

class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().uid;
    if (uid == null) {
      return AdaptiveScaffold(
        title: context.l10n.insightsTitle,
        body: AppPageLoader(label: context.l10n.authLoading),
      );
    }

    return ChangeNotifierProvider(
      create: (_) {
        final p = sl<InsightsProvider>();
        p.start(uid);
        return p;
      },
      child: const _InsightsView(),
    );
  }
}

class _InsightsView extends StatelessWidget {
  const _InsightsView();

  void _openActivityForRange(BuildContext context, InsightsProvider provider) {
    context.read<SearchProvider>().applyActivityFilters(
          range: provider.activityDateRange,
        );
    MainShellScope.selectTransactionsTab(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<InsightsProvider>();
    final summary = provider.summary;
    final money = AppCurrencyScope.of(context);
    final trendSuffix = provider.preset == InsightsPeriodPreset.thisYear &&
            !provider.chevronOverride
        ? l10n.insightsVsLastYear
        : l10n.insightsVsLastMonth;

    return AdaptiveScaffold(
      title: l10n.insightsTitle,
      appBar: AppBar(title: Text(l10n.insightsTitle)),
      body: Column(
        children: [
          _PeriodControls(provider: provider),
          Expanded(
            child: provider.isLoading && summary == null
                ? const _InsightsSkeleton()
                : provider.error != null && summary == null
                    ? ErrorStateView(
                        error: provider.error,
                        onRetry: provider.retry,
                      )
                    : summary == null || provider.isEmpty
                        ? _InsightsEmptyState(provider: provider)
                        : RefreshIndicator(
                            onRefresh: provider.refresh,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(
                                top: AppSpacing.sm,
                                bottom: AppSpacing.xxl,
                              ),
                              children: [
                                InsightsKpiRow(
                                  spentLabel: l10n.insightsSpent,
                                  spentValue: money.formatMoney(summary.totalDebit),
                                  receivedLabel: l10n.insightsIncome,
                                  receivedValue:
                                      money.formatMoney(summary.totalCredit),
                                  netLabel: l10n.insightsNet,
                                  netValue: _signedMoney(money, summary.net),
                                  countLabel: l10n.insightsTransactions,
                                  countValue: '${summary.transactionCount}',
                                  spentChangePercent: provider.spentChangePercent,
                                  receivedChangePercent:
                                      provider.receivedChangePercent,
                                  netChangePercent: provider.netChangePercent,
                                  transactionCountChange:
                                      provider.transactionCountChange,
                                  trendSuffix: trendSuffix,
                                  netAmountColor: summary.net.abs() < 0.0001
                                      ? null
                                      : (summary.net > 0
                                          ? AppColors.primaryStrong
                                          : AppColors.spend),
                                ),
                                if (provider.isLoadingExtras &&
                                    !hasTrendChartContent(provider.trend)) ...[
                                  const SizedBox(height: AppSpacing.lg),
                                  const _SectionSkeleton(height: 180),
                                ] else if (hasTrendChartContent(provider.trend)) ...[
                                  const SizedBox(height: AppSpacing.lg),
                                  _PaddedSectionHeader(l10n.insightsTrends),
                                  InsightsTrendChart(
                                    points: provider.trend,
                                    previousValues: provider.previousTrendValues,
                                    formatMoney: money.formatMoney,
                                  ),
                                ],
                                if (provider.templateFacts.hasContent ||
                                    (provider.aiNarrative?.isNotEmpty ?? false) ||
                                    provider.isLoadingNarrative) ...[
                                  const SizedBox(height: AppSpacing.lg),
                                  InsightsNarrativeCard(
                                    facts: provider.templateFacts,
                                    formatMoney: money.formatMoney,
                                    aiNarrative: provider.aiNarrative,
                                    isLoadingNarrative: provider.isLoadingNarrative,
                                    useMonthComparisonCopy:
                                        provider.preset ==
                                                InsightsPeriodPreset.thisMonth &&
                                            !provider.chevronOverride,
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.lg),
                                _PaddedSectionHeader(
                                  l10n.insightsByCategory,
                                  actionLabel: l10n.homeViewAllInsights,
                                  onActionTap: () =>
                                      _openActivityForRange(context, provider),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                  ),
                                  child: InsightsCategoryBars(
                                    byCategory: summary.byCategory,
                                    totalSpent: summary.totalDebit,
                                    formatMoney: money.formatMoney,
                                    otherLabel: l10n.insightsOtherCategory,
                                    onCategoryTap: (key, displayName) {
                                      context
                                          .read<SearchProvider>()
                                          .applyActivityFilters(
                                            range: provider.activityDateRange,
                                            categories: [displayName],
                                          );
                                      MainShellScope.selectTransactionsTab(context);
                                    },
                                    onOtherTap: () =>
                                        _openActivityForRange(context, provider),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                _PaddedSectionHeader(
                                  l10n.insightsTopMerchants,
                                  actionLabel: l10n.homeViewAllInsights,
                                  onActionTap: () =>
                                      _openActivityForRange(context, provider),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                  ),
                                  child: InsightsMerchantList(
                                    summary: summary,
                                    formatMoney: money.formatMoney,
                                  ),
                                ),
                                if (provider.recurring.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.lg),
                                  _PaddedSectionHeader(l10n.insightsRecurring),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                    ),
                                    child: InsightsRecurringList(
                                      items: provider.recurring,
                                      formatMoney: money.formatMoney,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  String _signedMoney(AppCurrencyController money, double amount) {
    final formatted = money.formatMoney(amount.abs());
    if (amount.abs() < 0.0001) return money.formatMoney(0);
    return amount > 0 ? '+$formatted' : '-$formatted';
  }
}

class _InsightsEmptyState extends StatelessWidget {
  const _InsightsEmptyState({required this.provider});

  final InsightsProvider provider;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canTryLastMonth =
        provider.preset == InsightsPeriodPreset.thisMonth &&
        !provider.chevronOverride;

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          EmptyStateView(
            title: l10n.insightsEmpty,
            message: l10n.insightsEmptyHint,
            actionLabel:
                canTryLastMonth ? l10n.insightsTryLastMonth : null,
            onActionTap: canTryLastMonth
                ? () => provider.setPreset(InsightsPeriodPreset.lastMonth)
                : null,
          ),
        ],
      ),
    );
  }
}

class _PeriodControls extends StatelessWidget {
  const _PeriodControls({required this.provider});

  final InsightsProvider provider;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final showChevrons = provider.preset != InsightsPeriodPreset.thisYear;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Column(
        children: [
          AppSegmentedToggle<InsightsPeriodPreset>(
            value: provider.selectedPreset,
            onChanged: provider.setPreset,
            segments: [
              AppSegment(
                value: InsightsPeriodPreset.thisMonth,
                label: l10n.insightsThisMonth,
              ),
              AppSegment(
                value: InsightsPeriodPreset.lastMonth,
                label: l10n.insightsLastMonth,
              ),
              AppSegment(
                value: InsightsPeriodPreset.thisYear,
                label: l10n.insightsThisYear,
              ),
            ],
          ),
          if (showChevrons)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MonthChevron(
                    tooltip: l10n.insightsPrevMonth,
                    icon: Icons.chevron_left_rounded,
                    onPressed: provider.previousMonth,
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 148),
                    child: Text(
                      DateFormat.yMMMM().format(provider.month),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  _MonthChevron(
                    tooltip: l10n.insightsNextMonth,
                    icon: Icons.chevron_right_rounded,
                    onPressed:
                        provider.canGoNextMonth ? provider.nextMonth : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthChevron extends StatelessWidget {
  const _MonthChevron({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final enabled = onPressed != null;
    final fill = AppColors.neutralFill(brightness);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill.withValues(alpha: enabled ? 1 : 0.45),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface.withValues(
                    alpha: enabled ? 0.85 : 0.35,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaddedSectionHeader extends StatelessWidget {
  const _PaddedSectionHeader(
    this.title, {
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: SectionHeader(
        title: title,
        actionLabel: actionLabel,
        onActionTap: onActionTap,
        showActionChevron: onActionTap != null,
      ),
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: SkeletonPulse(
        child: SkeletonCard(child: SizedBox(height: height)),
      ),
    );
  }
}

class _InsightsSkeleton extends StatelessWidget {
  const _InsightsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          Row(
            children: [
              const Expanded(child: SkeletonCard(child: SizedBox(height: 92))),
              SizedBox(width: AppSpacing.smPlus2),
              const Expanded(child: SkeletonCard(child: SizedBox(height: 92))),
            ],
          ),
          const SizedBox(height: AppSpacing.smPlus2),
          Row(
            children: [
              const Expanded(child: SkeletonCard(child: SizedBox(height: 92))),
              SizedBox(width: AppSpacing.smPlus2),
              const Expanded(child: SkeletonCard(child: SizedBox(height: 92))),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const SkeletonSectionHeader(titleWidth: 124),
          const SizedBox(height: AppSpacing.sm),
          const SkeletonCard(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}
