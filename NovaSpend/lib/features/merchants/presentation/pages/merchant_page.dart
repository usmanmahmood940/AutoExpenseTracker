import 'package:flutter/material.dart';
import 'package:nova_spend/core/currency/app_currency_scope.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/utils/date_labels.dart';
import 'package:nova_spend/core/widgets/adaptive_scaffold.dart';
import 'package:nova_spend/core/widgets/app_loader.dart';
import 'package:nova_spend/core/widgets/error_state_view.dart';
import 'package:nova_spend/core/widgets/skeleton.dart';
import 'package:nova_spend/core/widgets/transaction_group_card.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/merchants/presentation/provider/merchant_provider.dart';
import 'package:nova_spend/features/merchants/presentation/widgets/merchant_filter_chips.dart';
import 'package:nova_spend/features/merchants/presentation/widgets/merchant_hero_card.dart';
import 'package:nova_spend/features/merchants/presentation/widgets/merchant_month_stats_card.dart';
import 'package:nova_spend/features/merchants/presentation/widgets/merchant_remember_category_card.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/presentation/pages/transaction_detail_page.dart';
import 'package:nova_spend/features/transactions/presentation/widgets/day_group_header.dart';
import 'package:nova_spend/features/transactions/presentation/widgets/transaction_list_tile.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:provider/provider.dart';

class MerchantPage extends StatelessWidget {
  const MerchantPage({
    required this.merchantNormalized,
    this.displayName,
    super.key,
  });

  final String merchantNormalized;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().uid;
    final title = displayName ?? merchantNormalized;

    if (uid == null) {
      return AdaptiveScaffold(
        title: title,
        body: AppPageLoader(label: context.l10n.authLoading),
      );
    }

    return ChangeNotifierProvider(
      create: (_) {
        final p = sl<MerchantProvider>();
        p.start(
          uid: uid,
          merchantNormalized: merchantNormalized,
          displayNameHint: displayName,
        );
        return p;
      },
      child: _MerchantView(fallbackTitle: title),
    );
  }
}

class _MerchantView extends StatelessWidget {
  const _MerchantView({required this.fallbackTitle});

  final String fallbackTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<MerchantProvider>();
    final summary = provider.summary;
    final title = summary?.displayName ?? fallbackTitle;
    final money = AppCurrencyScope.of(context);
    final visibleItems = provider.filteredItems;
    final grouped = _groupByDay(visibleItems);
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return AdaptiveScaffold(
      title: title,
      body: provider.isLoading && provider.items.isEmpty
          ? const _MerchantSkeleton()
          : provider.error != null && provider.items.isEmpty
              ? ErrorStateView(
                  error: provider.error,
                  onRetry: provider.refresh,
                )
              : RefreshIndicator(
                  onRefresh: provider.refresh,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.pixels >=
                          n.metrics.maxScrollExtent - 200) {
                        provider.loadMore();
                      }
                      return false;
                    },
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                      children: [
                        if (summary != null) ...[
                          MerchantHeroCard(
                            summary: summary,
                            formatMoney: money.formatMoney,
                          ),
                          MerchantMonthStatsCard(
                            summary: summary,
                            formatMoney: money.formatMoney,
                          ),
                          MerchantInsightLine(
                            summary: summary,
                            formatMoney: money.formatMoney,
                          ),
                        ],
                        const MerchantRememberCategoryCard(),
                        MerchantFilterChips(
                          selected: provider.filter,
                          onSelected: provider.setFilter,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.md,
                            AppSpacing.sm,
                          ),
                          child: Text(
                            l10n.merchantAllTransactions,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (provider.items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Center(child: Text(l10n.merchantEmpty)),
                          )
                        else if (visibleItems.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Center(child: Text(l10n.merchantFilterEmpty)),
                          )
                        else
                          ..._buildListItems(
                            context,
                            days,
                            grouped,
                            provider,
                            money.formatMoney,
                          ),
                        if (provider.error != null && provider.items.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              AppSpacing.md,
                              AppSpacing.md,
                              0,
                            ),
                            child: LoadErrorBanner(
                              error: provider.error,
                              onRetry: provider.loadMore,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Map<String, List<TransactionEntity>> _groupByDay(
    List<TransactionEntity> items,
  ) {
    final map = <String, List<TransactionEntity>>{};
    for (final t in items) {
      map.putIfAbsent(t.transactionDate, () => []).add(t);
    }
    for (final txs in map.values) {
      txs.sort(TransactionEntity.compareNewestFirst);
    }
    return map;
  }

  List<Widget> _buildListItems(
    BuildContext context,
    List<String> days,
    Map<String, List<TransactionEntity>> grouped,
    MerchantProvider provider,
    String Function(double amount) formatMoney,
  ) {
    final l10n = context.l10n;
    final widgets = <Widget>[];
    for (final day in days) {
      final txs = grouped[day]!;
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
        formatMoney: formatMoney,
      );

      widgets
        ..add(
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md + AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.md + AppSpacing.xs,
              AppSpacing.sm,
            ),
            child: DayGroupHeader(
              label: relativeDayLabel(
                day,
                today: l10n.homePeriodToday,
                yesterday: l10n.commonYesterday,
              ),
              summaryPrefix: summary.prefix,
              summaryAmount: summary.amount,
              summaryAmountColor: summary.amountColor,
            ),
          ),
        )
        ..add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: TransactionGroupCard(
              children: [
                for (final tx in txs)
                  TransactionListTile(
                    transaction: tx,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              TransactionDetailPage(transaction: tx),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
    }
    if (provider.isLoadingMore) {
      widgets.add(const AppListFooterLoader());
    }
    return widgets;
  }
}

/// First-load placeholder mirroring the merchant header + transaction list.
class _MerchantSkeleton extends StatelessWidget {
  const _MerchantSkeleton();

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
        children: const [
          SkeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 48, height: 48),
                SizedBox(height: AppSpacing.md),
                SkeletonBox(width: 120, height: 12),
                SizedBox(height: AppSpacing.xs),
                SkeletonBox(width: 160, height: 28),
                SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 36)),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(child: SkeletonBox(height: 36)),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.md),
          SkeletonCard(
            child: Row(
              children: [
                Expanded(child: SkeletonBox(height: 40)),
                SizedBox(width: AppSpacing.sm),
                Expanded(child: SkeletonBox(height: 40)),
                SizedBox(width: AppSpacing.sm),
                Expanded(child: SkeletonBox(height: 40)),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          SkeletonSectionHeader(titleWidth: 132),
          SizedBox(height: AppSpacing.sm),
          SkeletonTransactionList(),
        ],
      ),
    );
  }
}
