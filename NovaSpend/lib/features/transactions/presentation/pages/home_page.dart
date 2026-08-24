import 'package:flutter/material.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/currency/app_currency_controller.dart';
import 'package:nova_spend/core/currency/app_currency_scope.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/utils/date_labels.dart';
import 'package:nova_spend/core/widgets/adaptive_scaffold.dart';
import 'package:nova_spend/core/widgets/app_loader.dart';
import 'package:nova_spend/core/widgets/app_segmented_toggle.dart';
import 'package:nova_spend/core/widgets/empty_state_view.dart';
import 'package:nova_spend/core/widgets/error_state_view.dart';
import 'package:nova_spend/core/widgets/glass_header_bar.dart';
import 'package:nova_spend/core/widgets/period_overview_card.dart';
import 'package:nova_spend/core/widgets/primary_fab.dart';
import 'package:nova_spend/core/widgets/section_header.dart';
import 'package:nova_spend/core/widgets/stat_highlight_card.dart';
import 'package:nova_spend/core/widgets/transaction_group_card.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/merchants/presentation/pages/merchant_page.dart';
import 'package:nova_spend/features/search/domain/entities/date_range_preset.dart';
import 'package:nova_spend/features/search/presentation/provider/search_provider.dart';
import 'package:nova_spend/features/settings/presentation/main_shell_scope.dart';
import 'package:nova_spend/features/settings/presentation/pages/review_page.dart';
import 'package:nova_spend/features/transactions/domain/entities/period_stats_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/presentation/home_period.dart';
import 'package:nova_spend/features/transactions/presentation/pages/transaction_detail_page.dart';
import 'package:nova_spend/features/transactions/presentation/provider/home_provider.dart';
import 'package:nova_spend/features/transactions/presentation/widgets/day_group_header.dart';
import 'package:nova_spend/features/transactions/presentation/widgets/home_skeleton.dart';
import 'package:nova_spend/features/transactions/presentation/widgets/review_banner.dart';
import 'package:nova_spend/features/transactions/presentation/widgets/transaction_list_tile.dart';
import 'package:nova_spend/l10n/app_localizations.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _reviewBannerDismissed = false;

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().uid;
    if (uid == null) {
      return AdaptiveScaffold(
        title: context.l10n.homeTitle,
        body: AppPageLoader(label: context.l10n.authLoading),
      );
    }

    return ChangeNotifierProvider(
      create: (_) {
        final provider = sl<HomeProvider>();
        provider.start(uid);
        return provider;
      },
      child: _HomeView(
        reviewBannerDismissed: _reviewBannerDismissed,
        onDismissReviewBanner: () =>
            setState(() => _reviewBannerDismissed = true),
      ),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView({
    required this.reviewBannerDismissed,
    required this.onDismissReviewBanner,
  });

  final bool reviewBannerDismissed;
  final VoidCallback onDismissReviewBanner;

  static const _sectionGap = AppSpacing.md - AppSpacing.sm; // 28

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final topPad = GlassHeaderBar.contentTopPadding(context);
    // Prefer [read] here — shell chrome must not rebuild on every period change.
    final home = context.read<HomeProvider>();

    return AdaptiveScaffold(
      applySafeArea: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              edgeOffset: GlassHeaderBar.totalHeight(context),
              onRefresh: home.refresh,
              child: CustomScrollView(
                clipBehavior: Clip.none,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      topPad,
                      AppSpacing.md,
                      0,
                    ),
                    sliver: const SliverToBoxAdapter(child: _PeriodToggle()),
                  ),
                  const SliverPadding(
                    padding: EdgeInsets.only(top: _sectionGap),
                    sliver: SliverToBoxAdapter(child: _PeriodBalance()),
                  ),
                  if (!reviewBannerDismissed)
                    SliverToBoxAdapter(
                      child: _ReviewBannerSlot(
                        onDismiss: onDismissReviewBanner,
                      ),
                    ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      _sectionGap,
                      AppSpacing.md,
                      AppSpacing.xxl + PrimaryFab.size,
                    ),
                    sliver: const SliverToBoxAdapter(child: _HomeBody()),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: GlassHeaderBar.totalHeight(context),
            child: GlassHeaderBar(
              title: Text(
                l10n.homeBrandName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.025 * 24,
                  color: AppColors.primaryStrong,
                ),
              ),
            ),
          ),
          Positioned(
            right: AppSpacing.md,
            bottom: AppSpacing.lg,
            child: PrimaryFab(
              tooltip: l10n.homeAddTransaction,
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }
}

/// Only rebuilds when [HomeProvider.period] changes.
class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final period = context.select((HomeProvider p) => p.period);

    return AppSegmentedToggle<HomePeriod>(
      value: period,
      onChanged: context.read<HomeProvider>().setPeriod,
      segments: [
        AppSegment(value: HomePeriod.today, label: l10n.homePeriodToday),
        AppSegment(value: HomePeriod.thisWeek, label: l10n.homePeriodThisWeek),
        AppSegment(
          value: HomePeriod.thisMonth,
          label: l10n.homePeriodThisMonth,
        ),
      ],
    );
  }
}

/// Period overview card — rebuilds when period totals or comparison change.
class _PeriodBalance extends StatelessWidget {
  const _PeriodBalance();

  @override
  Widget build(BuildContext context) {
    final showSkeleton = context.select(
      (HomeProvider p) =>
          (p.isLoading || p.isPeriodStatsLoading) &&
          p.currentPeriodStats == null,
    );
    if (showSkeleton) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: PeriodOverviewSkeleton(),
      );
    }

    final l10n = context.l10n;
    final money = AppCurrencyScope.of(context);
    final snapshot = context.select(
      (HomeProvider p) => (
        p.period,
        p.periodTotals.spent,
        p.periodTotals.received,
        p.periodComparison.spentChangePercent,
        p.periodComparison.receivedChangePercent,
        p.periodComparison.netChangePercent,
      ),
    );
    final (period, spent, received, spentChange, receivedChange, netChange) =
        snapshot;
    final net = received - spent;
    final showTrends = period != HomePeriod.today;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: PeriodOverviewCard(
        title: l10n.homeOverviewTitle(_periodLabel(l10n, period)),
        spentLabel: l10n.homeOverviewSpent,
        spentAmount: money.formatMoney(spent),
        receivedLabel: l10n.homeOverviewReceived,
        receivedAmount: money.formatMoney(received),
        netLabel: l10n.homeOverviewNet,
        netAmount: _formatNet(money, net),
        spentChangePercent: showTrends && spent != 0 ? spentChange : null,
        receivedChangePercent: showTrends && received != 0
            ? receivedChange
            : null,
        netChangePercent: showTrends && net != 0 ? netChange : null,
        trendSuffix: showTrends ? _trendSuffix(l10n, period) : null,
        spentIsZero: spent == 0,
        receivedIsZero: received == 0,
        netIsZero: net == 0,
        netIsNegative: net < 0,
      ),
    );
  }
}

String _formatNet(AppCurrencyController money, double net) {
  final formatted = money.formatMoney(net.abs());
  if (net > 0) return '+$formatted';
  if (net < 0) return '−$formatted';
  return formatted;
}

String _trendSuffix(AppLocalizations l10n, HomePeriod period) {
  return switch (period) {
    HomePeriod.thisWeek => l10n.homeOverviewVsLastWeek,
    HomePeriod.thisMonth => l10n.homeOverviewVsLastMonth,
    HomePeriod.today => '',
  };
}

class _ReviewBannerSlot extends StatelessWidget {
  const _ReviewBannerSlot({required this.onDismiss});

  final VoidCallback onDismiss;

  static const _sectionGap = AppSpacing.xl - AppSpacing.xs;

  @override
  Widget build(BuildContext context) {
    final count = context.select((HomeProvider p) => p.pendingReviewCount);
    if (count <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        _sectionGap,
        AppSpacing.md,
        0,
      ),
      child: ReviewBanner(
        count: count,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const ReviewPage())),
        onDismiss: onDismiss,
      ),
    );
  }
}

/// Highlights + transaction list for the selected period.
class _HomeBody extends StatelessWidget {
  const _HomeBody();

  static const _sectionGap = AppSpacing.lg;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final home = context.watch<HomeProvider>();

    if (home.isLoading && home.items.isEmpty) {
      return const HomeFeedSkeleton();
    }
    if (home.error != null && home.items.isEmpty) {
      return ErrorStateView(
        error: home.error,
        onRetry: home.refresh,
      );
    }
    if (home.items.isEmpty) {
      return EmptyStateView(
        title: l10n.homeEmpty,
        message: l10n.homeEmptyHint,
        actionLabel: l10n.homeEmptySetupCta,
        onActionTap: () => MainShellScope.selectSettingsTab(context),
      );
    }
    if (home.periodItems.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (home.error != null) ...[
            LoadErrorBanner(error: home.error, onRetry: home.refresh),
            const SizedBox(height: _sectionGap),
          ],
          _Highlights(home: home),
          const SizedBox(height: _sectionGap),
          SectionHeader(title: l10n.homeRecentTransactions),
          EmptyStateView(
            title: l10n.homePeriodEmpty,
            message: l10n.homePeriodEmptyHint,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (home.error != null) ...[
          LoadErrorBanner(error: home.error, onRetry: home.refresh),
          const SizedBox(height: _sectionGap),
        ],
        _Highlights(home: home),
        const SizedBox(height: _sectionGap),
        SectionHeader(
          title: l10n.homeRecentTransactions,
          actionLabel: home.hasMore ? l10n.homeViewAll : null,
          onActionTap: home.hasMore
              ? () => _openActivityForPeriod(context, home.period)
              : null,
        ),
        const SizedBox(height: _Highlights._headerGap),
        _dayGroups(context, l10n, home),
        if (home.periodHasMore) ...[
          const SizedBox(height: AppSpacing.lg),
          _ShowMoreButton(
            onPressed: () => _openActivityForPeriod(context, home.period),
          ),
        ],
      ],
    );
  }
}

class _Highlights extends StatelessWidget {
  const _Highlights({required this.home});

  final HomeProvider home;

  static const _headerGap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final period = context.select((HomeProvider p) => p.period);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: _highlightsTitle(l10n, period),
          actionLabel: l10n.homeViewAllInsights,
          onActionTap: () => MainShellScope.selectInsightsTab(context),
          showActionChevron: true,
        ),
        const SizedBox(height: _headerGap),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _highlightCard(
                  context,
                  l10n,
                  highlight: home.highestSpend,
                  label: l10n.homeHighestSpend,
                  iconAsset: 'assets/icons/icon_highest_spend.svg',
                  amountColor: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: AppSpacing.smPlus2),
              Expanded(
                child: _highlightCard(
                  context,
                  l10n,
                  highlight: home.highestReceive,
                  label: l10n.homeHighestReceived,
                  iconAsset: 'assets/icons/icon_highest_received.svg',
                  amountColor: AppColors.primaryStrong,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _highlightCard(
  BuildContext context,
  AppLocalizations l10n, {
  required PeriodHighlight? highlight,
  required String label,
  required String iconAsset,
  required Color amountColor,
}) {
  if (highlight == null) {
    return StatHighlightCard(
      label: label,
      iconAsset: iconAsset,
      amount: '—',
      subtitle: l10n.homeHighlightNone,
    );
  }

  final merchant =
      highlight.merchant.isEmpty ? highlight.category : highlight.merchant;
  final day = relativeDayLabel(
    highlight.transactionDate,
    today: l10n.homePeriodToday,
    yesterday: l10n.commonYesterday,
    includeYear: false,
  );

  return StatHighlightCard(
    label: label,
    iconAsset: iconAsset,
    amount: AppCurrencyScope.of(context).formatMoney(highlight.amount),
    amountColor: amountColor,
    subtitle: l10n.homeHighlightSubtitle(_truncate(merchant, 10), day),
    onTap: highlight.merchant.isEmpty
        ? null
        : () => _openMerchantHighlight(context, highlight),
  );
}

String _truncate(String value, int maxChars) {
  final nameSplit = value.trim().split(" ");
  var trimmed = "";
  for (var i = 0; i < nameSplit.length && i < 2; i++) {
    trimmed = trimmed + nameSplit[i] + " ";
  }
  trimmed = trimmed.trim();
  if (trimmed.length <= maxChars) return trimmed;
  return trimmed.substring(0, maxChars);
}

void _openActivityForPeriod(BuildContext context, HomePeriod period) {
  final preset = switch (period) {
    HomePeriod.today => DateRangePreset.today,
    HomePeriod.thisWeek => DateRangePreset.thisWeek,
    HomePeriod.thisMonth => DateRangePreset.thisMonth,
  };
  context.read<SearchProvider>().setDateRange(resolveDateRange(preset));
  MainShellScope.selectTransactionsTab(context);
}

Widget _dayGroups(
  BuildContext context,
  AppLocalizations l10n,
  HomeProvider home,
) {
  final grouped = home.groupByDay();
  final days = grouped.keys.toList();
  if (days.isEmpty) return const SizedBox.shrink();

  final money = AppCurrencyScope.of(context);

  return TransactionGroupCard.grouped(
    sections: [
      for (final day in days)
        _daySection(
          context,
          l10n,
          day: day,
          txs: grouped[day]!,
          money: money,
        ),
    ],
  );
}

TransactionGroupSection _daySection(
  BuildContext context,
  AppLocalizations l10n, {
  required String day,
  required List<TransactionEntity> txs,
  required AppCurrencyController money,
}) {
  final spent = txs
      .where((t) => t.type != 'credit')
      .fold<double>(0, (sum, t) => sum + t.amount);
  final received = txs
      .where((t) => t.type == 'credit')
      .fold<double>(0, (sum, t) => sum + t.amount);
  final summary = dayGroupSummary(
    spent: spent,
    received: received,
    spentPrefix: l10n.homeDayGroupSpent,
    netPrefix: l10n.homeDayGroupNet,
    formatMoney: money.formatMoney,
  );

  return TransactionGroupSection(
    header: DayGroupHeader(
      label: relativeDayLabel(
        day,
        today: l10n.homePeriodToday,
        yesterday: l10n.commonYesterday,
      ),
      summaryPrefix: summary.prefix,
      summaryAmount: summary.amount,
      summaryAmountColor: summary.amountColor,
      embedded: true,
    ),
    children: [
      for (final tx in txs)
        TransactionListTile(
          transaction: tx,
          onTap: () => _openDetail(context, tx),
          onMerchantTap: tx.merchant.isEmpty
              ? null
              : () => _openMerchant(context, tx),
        ),
    ],
  );
}

class _ShowMoreButton extends StatelessWidget {
  const _ShowMoreButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brightness = Theme.of(context).brightness;

    return Center(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.smPlus,
          ),
          decoration: BoxDecoration(
            color: AppColors.neutralFill(brightness),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: AppColors.border(brightness).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.homeShowMore,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryStrong,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: AppColors.primaryStrong,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _openDetail(BuildContext context, TransactionEntity tx) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TransactionDetailPage(transaction: tx),
    ),
  );
}

void _openMerchant(BuildContext context, TransactionEntity tx) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MerchantPage(
        merchantNormalized: tx.resolvedMerchantKey,
        displayName: tx.merchant,
      ),
    ),
  );
}

void _openMerchantHighlight(BuildContext context, PeriodHighlight highlight) {
  final key = highlight.merchantNormalized.isNotEmpty
      ? highlight.merchantNormalized
      : normalizeMerchantKey(highlight.merchant);
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MerchantPage(
        merchantNormalized: key,
        displayName: highlight.merchant,
      ),
    ),
  );
}

String _highlightsTitle(AppLocalizations l10n, HomePeriod period) {
  return switch (period) {
    HomePeriod.today => l10n.homeDailyHighlights,
    HomePeriod.thisWeek => l10n.homeWeeklyHighlights,
    HomePeriod.thisMonth => l10n.homeMonthlyHighlights,
  };
}

String _periodLabel(AppLocalizations l10n, HomePeriod period) {
  return switch (period) {
    HomePeriod.today => l10n.homePeriodToday,
    HomePeriod.thisWeek => l10n.homePeriodThisWeek,
    HomePeriod.thisMonth => l10n.homePeriodThisMonth,
  };
}
