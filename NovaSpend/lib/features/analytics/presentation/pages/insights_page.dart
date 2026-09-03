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
import 'package:nova_spend/core/widgets/error_state_view.dart';
import 'package:nova_spend/core/widgets/glass_header_bar.dart';
import 'package:nova_spend/features/settings/presentation/widgets/shell_glass_header_bar.dart';
import 'package:nova_spend/core/widgets/hero_wash.dart';
import 'package:nova_spend/core/widgets/section_header.dart';
import 'package:nova_spend/features/analytics/domain/entities/monthly_summary_entity.dart';
import 'package:nova_spend/features/analytics/domain/insights_math.dart';
import 'package:nova_spend/features/analytics/presentation/provider/insights_provider.dart';
import 'package:nova_spend/features/analytics/presentation/widgets/insights_category_bars.dart';
import 'package:nova_spend/features/analytics/presentation/widgets/insights_kpi_row.dart';
import 'package:nova_spend/features/analytics/presentation/widgets/insights_merchant_list.dart';
import 'package:nova_spend/features/analytics/presentation/widgets/insights_merchant_sort_dropdown.dart';
import 'package:nova_spend/features/analytics/presentation/widgets/insights_narrative_card.dart';
import 'package:nova_spend/features/analytics/presentation/widgets/insights_recurring_list.dart';
import 'package:nova_spend/features/analytics/presentation/widgets/insights_skeleton.dart';
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
      return _InsightsChrome(
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

  static const _sectionGap = AppSpacing.lg;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<InsightsProvider>();

    return _InsightsChrome(
      body: Column(
        children: [
          const _PeriodControls(),
          Expanded(
            child: ClipRect(
              child: RefreshIndicator(
                onRefresh: provider.refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: const [
                    SliverToBoxAdapter(child: _InsightsKpiSection()),
                    SliverPadding(
                      padding: EdgeInsets.only(bottom: AppSpacing.xxl),
                      sliver: SliverToBoxAdapter(child: _InsightsBody()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared Insights chrome: hero wash + glass brand header over [body].
class _InsightsChrome extends StatelessWidget {
  const _InsightsChrome({required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdaptiveScaffold(
      applySafeArea: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          const Positioned(top: 0, left: 0, right: 0, child: HeroWash()),
          Positioned.fill(child: body),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: GlassHeaderBar.totalHeight(context),
            child: const ShellGlassHeaderBar(),
          ),
        ],
      ),
    );
  }
}

/// KPI cards — skeleton only on first load when summary is not cached yet.
class _InsightsKpiSection extends StatelessWidget {
  const _InsightsKpiSection();

  @override
  Widget build(BuildContext context) {
    final showSkeleton = context.select(
      (InsightsProvider p) => p.isLoading && p.summary == null,
    );
    if (showSkeleton) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.sm),
        child: InsightsKpiSkeleton(),
      );
    }

    final summary = context.select((InsightsProvider p) => p.summary);
    if (summary == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final money = AppCurrencyScope.of(context);
    final provider = context.read<InsightsProvider>();
    final trendSuffix =
        provider.preset == InsightsPeriodPreset.thisYear &&
            !provider.chevronOverride
        ? l10n.insightsVsLastYear
        : l10n.insightsVsLastMonth;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: InsightsKpiRow(
        spentLabel: l10n.insightsSpent,
        spentValue: money.formatMoney(summary.totalDebit),
        receivedLabel: l10n.insightsIncome,
        receivedValue: money.formatMoney(summary.totalCredit),
        netLabel: l10n.insightsNet,
        netValue: _signedMoney(money, summary.net),
        countLabel: l10n.insightsTransactions,
        countValue: '${summary.transactionCount}',
        spentChangePercent: provider.spentChangePercent,
        receivedChangePercent: provider.receivedChangePercent,
        netChangePercent: provider.netChangePercent,
        transactionCountChange: provider.transactionCountChange,
        trendSuffix: trendSuffix,
        netAmountColor: summary.net.abs() < 0.0001
            ? null
            : (summary.net > 0
                  ? AppColors.positiveAmount(Theme.of(context).brightness)
                  : AppColors.spendForeground(Theme.of(context).brightness)),
      ),
    );
  }

  String _signedMoney(AppCurrencyController money, double amount) {
    final formatted = money.formatMoney(amount.abs());
    if (amount.abs() < 0.0001) return money.formatMoney(0);
    return amount > 0 ? '+$formatted' : '-$formatted';
  }
}

class _InsightsBody extends StatelessWidget {
  const _InsightsBody();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InsightsProvider>();

    if (provider.error != null && provider.summary == null) {
      return ErrorStateView(error: provider.error, onRetry: provider.retry);
    }

    return const _InsightsSections();
  }
}

class _InsightsSections extends StatelessWidget {
  const _InsightsSections();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        _TrendSection(),
        _NarrativeSection(),
        _CategoriesSection(),
        _TopMerchantsSection(),
        _RecurringSection(),
      ],
    );
  }
}

class _TrendSection extends StatelessWidget {
  const _TrendSection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final money = AppCurrencyScope.of(context);
    final snapshot = context.select(
      (InsightsProvider p) =>
          (p.isLoading, p.isLoadingExtras, p.trend, p.previousTrendValues),
    );
    final (isLoading, isLoadingExtras, trend, previousTrendValues) = snapshot;
    final hasTrend = hasTrendChartContent(trend);
    final waitingForTrend = !hasTrend && (isLoading || isLoadingExtras);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: _InsightsView._sectionGap),
        _PaddedSectionHeader(l10n.insightsTrends),
        if (waitingForTrend)
          const InsightsTrendSkeleton()
        else if (hasTrend)
          InsightsTrendChart(
            points: trend,
            previousValues: previousTrendValues,
            formatMoney: money.formatMoney,
          )
        else
          InsightsSectionEmpty(message: l10n.insightsSectionTrendEmpty),
      ],
    );
  }
}

class _NarrativeSection extends StatelessWidget {
  const _NarrativeSection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final money = AppCurrencyScope.of(context);
    final snapshot = context.select(
      (InsightsProvider p) => (
        p.isLoading,
        p.isLoadingNarrative,
        p.aiNarrative,
        p.templateFacts,
        p.preset,
        p.chevronOverride,
      ),
    );
    final (
      isLoading,
      isLoadingNarrative,
      aiNarrative,
      templateFacts,
      preset,
      chevronOverride,
    ) = snapshot;
    final hasAi = aiNarrative?.trim().isNotEmpty ?? false;
    final hasContent = templateFacts.hasContent || hasAi;
    final waitingForNarrative =
        !hasContent && (isLoading || isLoadingNarrative);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: _InsightsView._sectionGap),
        _PaddedSectionHeader(l10n.insightsWhatChanged),
        if (waitingForNarrative)
          const InsightsNarrativeSkeleton()
        else if (hasContent)
          InsightsNarrativeCard(
            facts: templateFacts,
            formatMoney: money.formatMoney,
            aiNarrative: aiNarrative,
            isLoadingNarrative: false,
            useMonthComparisonCopy:
                preset == InsightsPeriodPreset.thisMonth && !chevronOverride,
          )
        else
          InsightsSectionEmpty(message: l10n.insightsSectionNarrativeEmpty),
      ],
    );
  }
}

class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection();

  void _openActivityForRange(BuildContext context, InsightsProvider provider) {
    context.read<SearchProvider>().applyActivityFilters(
      range: provider.activityDateRange,
    );
    MainShellScope.selectTransactionsTab(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final money = AppCurrencyScope.of(context);
    final snapshot = context.select(
      (InsightsProvider p) => (p.isLoading, p.summary),
    );
    final (isLoading, summary) = snapshot;
    final waitingForSummary = isLoading && summary == null;
    final hasCategories =
        summary != null && topEntries(summary.byCategory).isNotEmpty;
    final showCategoriesEmpty =
        !waitingForSummary && !isLoading && !hasCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: _InsightsView._sectionGap),
        _PaddedSectionHeader(
          l10n.insightsByCategory,
          actionLabel: hasCategories ? l10n.homeViewAllInsights : null,
          onActionTap: hasCategories
              ? () => _openActivityForRange(
                  context,
                  context.read<InsightsProvider>(),
                )
              : null,
        ),
        if (waitingForSummary)
          const InsightsCategorySkeleton()
        else if (showCategoriesEmpty)
          InsightsSectionEmpty(message: l10n.insightsSectionCategoriesEmpty)
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: InsightsCategoryBars(
              byCategory: summary!.byCategory,
              totalSpent: summary.totalDebit,
              formatMoney: money.formatMoney,
              otherLabel: l10n.insightsOtherCategory,
              onCategoryTap: (key, displayName) {
                context.read<SearchProvider>().applyActivityFilters(
                  range: context.read<InsightsProvider>().activityDateRange,
                  categories: [displayName],
                );
                MainShellScope.selectTransactionsTab(context);
              },
              onOtherTap: () => _openActivityForRange(
                context,
                context.read<InsightsProvider>(),
              ),
            ),
          ),
      ],
    );
  }
}

class _TopMerchantsSection extends StatefulWidget {
  const _TopMerchantsSection();

  @override
  State<_TopMerchantsSection> createState() => _TopMerchantsSectionState();
}

class _TopMerchantsSectionState extends State<_TopMerchantsSection> {
  TopMerchantSort _sort = TopMerchantSort.amountSpent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final money = AppCurrencyScope.of(context);
    final snapshot = context.select(
      (InsightsProvider p) => (p.isLoading, p.summary),
    );
    final (isLoading, summary) = snapshot;
    final waitingForSummary = isLoading && summary == null;
    final merchants = summary == null
        ? const <TopMerchantRowData>[]
        : topMerchantsForSort(summary, _sort);
    final hasMerchants = merchants.isNotEmpty;
    final showMerchantsEmpty =
        !waitingForSummary && !isLoading && !hasMerchants;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: _InsightsView._sectionGap),
        _PaddedSectionHeader(
          l10n.insightsTopMerchants,
          trailing: _hasMerchantsDropdown(summary)
              ? InsightsMerchantSortDropdown(
                  value: _sort,
                  onChanged: (next) => setState(() => _sort = next),
                )
              : null,
        ),
        if (waitingForSummary)
          const InsightsMerchantListSkeleton()
        else if (showMerchantsEmpty)
          InsightsSectionEmpty(message: l10n.insightsSectionMerchantsEmpty)
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: InsightsMerchantList(
              summary: summary!,
              formatMoney: money.formatMoney,
              sort: _sort,
            ),
          ),
      ],
    );
  }

  bool _hasMerchantsDropdown(MonthlySummaryEntity? summary) {
    if (summary == null) return false;
    return summary.topMerchantsSpent.isNotEmpty ||
        summary.topMerchantsReceived.isNotEmpty ||
        summary.topMerchantsByVisits.isNotEmpty;
  }
}

class _RecurringSection extends StatelessWidget {
  const _RecurringSection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final money = AppCurrencyScope.of(context);
    final snapshot = context.select(
      (InsightsProvider p) => (p.isLoading, p.isLoadingExtras, p.recurring),
    );
    final (isLoading, isLoadingExtras, recurring) = snapshot;
    final waitingForRecurring =
        recurring.isEmpty && (isLoading || isLoadingExtras);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: _InsightsView._sectionGap),
        _PaddedSectionHeader(l10n.insightsRecurring),
        if (waitingForRecurring)
          const InsightsMerchantListSkeleton(rowCount: 2)
        else if (recurring.isEmpty)
          InsightsSectionEmpty(message: l10n.insightsSectionRecurringEmpty)
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: InsightsRecurringList(
              items: recurring,
              formatMoney: money.formatMoney,
            ),
          ),
      ],
    );
  }
}

class _PeriodControls extends StatelessWidget {
  const _PeriodControls();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<InsightsProvider>();
    final showChevrons = provider.preset != InsightsPeriodPreset.thisYear;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        GlassHeaderBar.contentTopPadding(context),
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
                    onPressed: provider.canGoNextMonth
                        ? provider.nextMonth
                        : null,
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
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: enabled ? 0.85 : 0.35),
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
    this.trailing,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final Widget? trailing;

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
        trailing: trailing,
      ),
    );
  }
}
