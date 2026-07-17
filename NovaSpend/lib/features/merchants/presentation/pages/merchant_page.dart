import 'package:flutter/material.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/utils/money_format.dart';
import 'package:nova_spend/core/widgets/adaptive_scaffold.dart';
import 'package:nova_spend/core/widgets/app_card.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/merchants/presentation/provider/merchant_provider.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/presentation/pages/transaction_detail_page.dart';
import 'package:nova_spend/features/transactions/presentation/widgets/day_section_header.dart';
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
        body: Center(child: Text(context.l10n.authLoading)),
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
    final currency = summary?.currency ?? 'PKR';
    final grouped = _groupByDay(provider.items);
    final days = grouped.keys.toList();

    return AdaptiveScaffold(
      title: title,
      appBar: AppBar(
        title: Text(title),
      ),
      body: provider.isLoading
          ? Center(child: Text(l10n.commonLoading))
          : provider.error != null && provider.items.isEmpty
              ? Center(child: Text(l10n.errorLoadFailed))
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
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.lg,
                            AppSpacing.md,
                            AppSpacing.sm,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              if (summary != null) ...[
                                Text(
                                  l10n.merchantTotalVisits(
                                    formatMoney(
                                      summary.totalSpent,
                                      currency: currency,
                                    ),
                                    '${summary.visitCount}',
                                  ),
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  l10n.merchantAverage(
                                    formatMoney(
                                      summary.averageSpent,
                                      currency: currency,
                                    ),
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (summary != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            child: AppCard(
                              child: Text(
                                l10n.merchantThisMonth(
                                  formatMoney(
                                    summary.thisMonthSpent,
                                    currency: currency,
                                  ),
                                  '${summary.thisMonthVisits}',
                                ),
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          ),
                        const SizedBox(height: AppSpacing.lg),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: Text(
                            l10n.merchantAllTransactions,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (provider.items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Center(child: Text(l10n.merchantEmpty)),
                          )
                        else
                          ..._buildListItems(context, days, grouped, provider),
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
    return map;
  }

  List<Widget> _buildListItems(
    BuildContext context,
    List<String> days,
    Map<String, List<TransactionEntity>> grouped,
    MerchantProvider provider,
  ) {
    final widgets = <Widget>[];
    for (final day in days) {
      widgets.add(DaySectionHeader(dateKey: day));
      for (final tx in grouped[day]!) {
        widgets.add(
          Padding(
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
          ),
        );
      }
    }
    if (provider.isLoadingMore) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return widgets;
  }
}
