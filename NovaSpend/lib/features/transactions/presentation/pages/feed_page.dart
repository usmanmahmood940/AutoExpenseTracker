import 'package:flutter/material.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/adaptive_scaffold.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/presentation/pages/transaction_detail_page.dart';
import 'package:nova_spend/features/transactions/presentation/provider/feed_provider.dart';
import 'package:nova_spend/features/transactions/presentation/widgets/day_section_header.dart';
import 'package:nova_spend/features/transactions/presentation/widgets/transaction_filter_sheet.dart';
import 'package:nova_spend/features/transactions/presentation/widgets/transaction_list_tile.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:provider/provider.dart';

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().uid;
    if (uid == null) {
      return AdaptiveScaffold(
        title: context.l10n.feedTitle,
        body: Center(child: Text(context.l10n.authLoading)),
      );
    }

    return ChangeNotifierProvider(
      create: (_) {
        final provider = sl<FeedProvider>();
        provider.start(uid);
        return provider;
      },
      child: const _FeedView(),
    );
  }
}

class _FeedView extends StatelessWidget {
  const _FeedView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final feed = context.watch<FeedProvider>();
    final grouped = feed.groupByDay();
    final days = grouped.keys.toList();

    return AdaptiveScaffold(
      title: l10n.feedTitle,
      appBar: AppBar(
        title: Text(l10n.feedTitle),
        actions: [
          IconButton(
            tooltip: l10n.feedFilters,
            onPressed: () async {
              final banks = feed.items
                  .map((e) => e.bank)
                  .where((b) => b.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
              final categories = feed.items
                  .map((e) => e.category)
                  .where((c) => c.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
              final result = await TransactionFilterSheet.show(
                context,
                initial: feed.filter,
                categories: categories,
                banks: banks,
              );
              if (result != null) {
                feed.setFilter(result);
              }
            },
            icon: Badge(
              isLabelVisible: feed.filter.hasActiveFilters,
              child: const Icon(Icons.filter_list),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (feed.availableAccounts.isNotEmpty)
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
                      selected: feed.filter.accountIdMasked == null,
                      onSelected: (_) => feed.setAccountFilter(null),
                    ),
                  ),
                  ...feed.availableAccounts.map(
                    (account) => Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: FilterChip(
                        label: Text(account),
                        selected: feed.filter.accountIdMasked == account,
                        onSelected: (_) => feed.setAccountFilter(account),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: feed.refresh,
              child: feed.isLoading && feed.items.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.4,
                          child: Center(child: Text(l10n.commonLoading)),
                        ),
                      ],
                    )
                  : feed.error != null && feed.items.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.4,
                              child: Center(child: Text(l10n.errorLoadFailed)),
                            ),
                          ],
                        )
                      : feed.items.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.sizeOf(context).height * 0.4,
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(AppSpacing.lg),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            l10n.feedEmpty,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          const SizedBox(height: AppSpacing.sm),
                                          Text(
                                            l10n.feedEmptyHint,
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
                                  feed.loadMore();
                                }
                                return false;
                              },
                              child: ListView.builder(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.xxl,
                                ),
                                itemCount: _itemCount(days, grouped, feed),
                                itemBuilder: (context, index) {
                                  return _buildItem(
                                    context,
                                    index,
                                    days,
                                    grouped,
                                    feed,
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

  int _itemCount(
    List<String> days,
    Map<String, List<TransactionEntity>> grouped,
    FeedProvider feed,
  ) {
    var count = 0;
    for (final day in days) {
      count += 1 + grouped[day]!.length;
    }
    if (feed.isLoadingMore) count += 1;
    return count;
  }

  Widget _buildItem(
    BuildContext context,
    int index,
    List<String> days,
    Map<String, List<TransactionEntity>> grouped,
    FeedProvider feed,
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
