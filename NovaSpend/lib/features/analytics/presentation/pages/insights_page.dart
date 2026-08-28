import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/core/currency/app_currency_scope.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/adaptive_scaffold.dart';
import 'package:nova_spend/core/widgets/app_loader.dart';
import 'package:nova_spend/core/widgets/app_segmented_toggle.dart';
import 'package:nova_spend/core/widgets/balance_header.dart';
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
import 'package:nova_spend/l10n/app_localizations.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<InsightsProvider>();
    final summary = provider.summary;
    final money = AppCurrencyScope.of(context);

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
                    ? Center(child: Text(l10n.insightsEmpty))
                    : AppBusyContent(
                        busy: provider.isLoading,
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                          children: [
                      BalanceHeader(
                        label: l10n.insightsNet,
                        amount: money.formatMoney(summary.net),
                        subtitle: _vsPreviousSubtitle(
                          l10n,
                          provider.netChangePercent,
                        ),
                      ),
                      InsightsKpiRow(
                        spentLabel: l10n.insightsSpent,
                        spentValue: money.formatMoney(summary.totalDebit),
                        receivedLabel: l10n.insightsIncome,
                        receivedValue: money.formatMoney(summary.totalCredit),
                        countLabel: l10n.insightsTransactions,
                        countValue: '${summary.transactionCount}',
                      ),
                      if (hasTrendChartContent(provider.trend)) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _PaddedSectionHeader(l10n.insightsTrends),
                        InsightsTrendChart(
                          points: provider.trend,
                          formatMoney: money.formatMoney,
                        ),
                      ],
                      if (provider.templateFacts.hasContent ||
                          (provider.aiNarrative?.isNotEmpty ?? false)) ...[
                        const SizedBox(height: AppSpacing.lg),
                        InsightsNarrativeCard(
                          facts: provider.templateFacts,
                          formatMoney: money.formatMoney,
                          aiNarrative: provider.aiNarrative,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _PaddedSectionHeader(l10n.insightsByCategory),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: InsightsCategoryBars(
                          byCategory: summary.byCategory,
                          totalSpent: summary.totalDebit,
                          formatMoney: money.formatMoney,
                          onCategoryTap: (key, displayName) {
                            context.read<SearchProvider>().applyActivityFilters(
                                  range: provider.activityDateRange,
                                  categories: [displayName],
                                );
                            MainShellScope.selectTransactionsTab(context);
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _PaddedSectionHeader(l10n.insightsTopMerchants),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: InsightsMerchantList(
                          summary: summary,
                          formatMoney: money.formatMoney,
                          visitLabel: l10n.insightsVisitCount,
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

  String? _vsPreviousSubtitle(AppLocalizations l10n, double? change) {
    if (change == null) return null;
    final percent = change.abs().round().toString();
    if (change >= 0) return l10n.insightsChangeUp(percent);
    return l10n.insightsChangeDown(percent);
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
            value: provider.preset,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: l10n.insightsPrevMonth,
                  onPressed: provider.previousMonth,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  DateFormat.yMMMM().format(provider.month),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                IconButton(
                  tooltip: l10n.insightsNextMonth,
                  onPressed: provider.nextMonth,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PaddedSectionHeader extends StatelessWidget {
  const _PaddedSectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: SectionHeader(title: title),
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
          const Center(child: SkeletonBox(width: 96, height: 12)),
          const SizedBox(height: AppSpacing.smPlus),
          const Center(child: SkeletonBox(width: 196, height: 34)),
          const SizedBox(height: AppSpacing.lg),
          const Row(
            children: [
              Expanded(child: SkeletonCard(child: SizedBox(height: 44))),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: SkeletonCard(child: SizedBox(height: 44))),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: SkeletonCard(child: SizedBox(height: 44))),
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
