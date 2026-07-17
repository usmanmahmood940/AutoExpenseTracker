import 'package:flutter/material.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/utils/money_format.dart';
import 'package:nova_spend/core/widgets/adaptive_scaffold.dart';
import 'package:nova_spend/core/widgets/balance_header.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/merchants/presentation/pages/merchant_page.dart';
import 'package:nova_spend/features/settings/presentation/main_shell_scope.dart';
import 'package:nova_spend/features/settings/presentation/pages/review_page.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/presentation/home_period.dart';
import 'package:nova_spend/features/transactions/presentation/pages/transaction_detail_page.dart';
import 'package:nova_spend/features/transactions/presentation/provider/home_provider.dart';
import 'package:nova_spend/features/transactions/presentation/widgets/day_section_header.dart';
import 'package:nova_spend/features/transactions/presentation/widgets/review_banner.dart';
import 'package:nova_spend/features/transactions/presentation/widgets/transaction_filter_sheet.dart';
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
        body: Center(child: Text(context.l10n.authLoading)),
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
        onDismissReviewBanner: () => setState(() => _reviewBannerDismissed = true),
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final home = context.watch<HomeProvider>();
    final grouped = home.groupByDay();
    final days = grouped.keys.toList();
    final totals = home.periodTotals;

    return AdaptiveScaffold(
      title: l10n.homeTitle,
      appBar: AppBar(
        title: Text(l10n.homeTitle),
        actions: [
          IconButton(
            tooltip: l10n.feedFilters,
            onPressed: () async {
              final banks = home.items
                  .map((e) => e.bank)
                  .where((b) => b.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
              final categories = home.items
                  .map((e) => e.category)
                  .where((c) => c.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
              final result = await TransactionFilterSheet.show(
                context,
                initial: home.filter,
                categories: categories,
                banks: banks,
              );
              if (result != null) {
                home.setFilter(result);
              }
            },
            icon: Badge(
              isLabelVisible: home.filter.hasActiveFilters,
              child: const Icon(Icons.filter_list),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _PeriodToggle(
            period: home.period,
            onChanged: home.setPeriod,
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            child: BalanceHeader(
              key: ValueKey(home.period),
              label: _periodLabel(l10n, home.period),
              spentAmount: l10n.homeSpentSummary(
                formatMoney(totals.spent, currency: totals.currency),
              ),
              receivedAmount: l10n.homeReceivedSummary(
                formatMoney(totals.received, currency: totals.currency),
              ),
            ),
          ),
          if (!reviewBannerDismissed && home.pendingReviewCount > 0)
            ReviewBanner(
              count: home.pendingReviewCount,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ReviewPage(),
                  ),
                );
              },
              onDismiss: onDismissReviewBanner,
            ),
          if (home.availableAccounts.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: FilterChip(
                      label: Text(l10n.feedFilterAll),
                      selected: home.filter.accountIdMasked == null,
                      onSelected: (_) => home.setAccountFilter(null),
                    ),
                  ),
                  ...home.availableAccounts.map(
                    (account) => Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: FilterChip(
                        label: Text(account),
                        selected: home.filter.accountIdMasked == account,
                        onSelected: (_) => home.setAccountFilter(account),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: home.refresh,
              child: home.isLoading && home.items.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.3,
                          child: Center(child: Text(l10n.commonLoading)),
                        ),
                      ],
                    )
                  : home.error != null && home.items.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.3,
                              child: Center(child: Text(l10n.errorLoadFailed)),
                            ),
                          ],
                        )
                      : home.items.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.sizeOf(context).height * 0.35,
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(
                                        AppSpacing.lg,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            l10n.homeEmpty,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          const SizedBox(height: AppSpacing.sm),
                                          Text(
                                            l10n.homeEmptyHint,
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.55),
                                                ),
                                          ),
                                          const SizedBox(height: AppSpacing.lg),
                                          FilledButton.tonal(
                                            onPressed: () =>
                                                MainShellScope.selectSettingsTab(
                                              context,
                                            ),
                                            child: Text(l10n.homeEmptySetupCta),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : NotificationListener<ScrollNotification>(
                              onNotification: (n) {
                                if (n.metrics.pixels >=
                                    n.metrics.maxScrollExtent - 200) {
                                  home.loadMore();
                                }
                                return false;
                              },
                              child: ListView.builder(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.xxl,
                                ),
                                itemCount: _itemCount(days, grouped, home),
                                itemBuilder: (context, index) {
                                  return _buildItem(
                                    context,
                                    index,
                                    days,
                                    grouped,
                                    home,
                                  );
                                },
                              ),
                            ),
            ),
          ),
        ],
      ),
    );
  }

  String _periodLabel(AppLocalizations l10n, HomePeriod period) {
    return switch (period) {
      HomePeriod.today => l10n.homePeriodToday,
      HomePeriod.thisWeek => l10n.homePeriodThisWeek,
      HomePeriod.thisMonth => l10n.homePeriodThisMonth,
    };
  }

  int _itemCount(
    List<String> days,
    Map<String, List<TransactionEntity>> grouped,
    HomeProvider home,
  ) {
    var count = 0;
    for (final day in days) {
      count += 1 + grouped[day]!.length;
    }
    if (home.isLoadingMore) count += 1;
    return count;
  }

  Widget _buildItem(
    BuildContext context,
    int index,
    List<String> days,
    Map<String, List<TransactionEntity>> grouped,
    HomeProvider home,
  ) {
    var cursor = 0;
    for (final day in days) {
      if (index == cursor) {
        return DaySectionHeader(dateKey: day);
      }
      cursor++;
      final txs = grouped[day]!;
      for (final tx in txs) {
        if (index == cursor) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: TransactionListTile(
              transaction: tx,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TransactionDetailPage(transaction: tx),
                  ),
                );
              },
              onMerchantTap: tx.merchant.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MerchantPage(
                            merchantNormalized: tx.resolvedMerchantKey,
                            displayName: tx.merchant,
                          ),
                        ),
                      );
                    },
            ),
          );
        }
        cursor++;
      }
    }
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({
    required this.period,
    required this.onChanged,
  });

  final HomePeriod period;
  final ValueChanged<HomePeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: SegmentedButton<HomePeriod>(
        segments: [
          ButtonSegment(
            value: HomePeriod.today,
            label: Text(l10n.homePeriodToday),
          ),
          ButtonSegment(
            value: HomePeriod.thisWeek,
            label: Text(l10n.homePeriodThisWeek),
          ),
          ButtonSegment(
            value: HomePeriod.thisMonth,
            label: Text(l10n.homePeriodThisMonth),
          ),
        ],
        selected: {period},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}
