import 'package:flutter/material.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/adaptive_scaffold.dart';
import 'package:nova_spend/core/widgets/transaction_group_card.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/merchants/presentation/pages/merchant_page.dart';
import 'package:nova_spend/features/search/presentation/provider/search_provider.dart';
import 'package:nova_spend/features/transactions/presentation/pages/transaction_detail_page.dart';
import 'package:nova_spend/features/transactions/presentation/widgets/transaction_list_tile.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:provider/provider.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().uid;
    if (uid == null) {
      return AdaptiveScaffold(
        title: context.l10n.navSearch,
        body: Center(child: Text(context.l10n.authLoading)),
      );
    }

    return ChangeNotifierProvider(
      create: (_) {
        final p = sl<SearchProvider>();
        p.start(uid);
        return p;
      },
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<SearchProvider>();

    return AdaptiveScaffold(
      title: l10n.navSearch,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: SearchBar(
              controller: _controller,
              hintText: l10n.searchHint,
              leading: const Icon(Icons.search),
              trailing: [
                if (_controller.text.isNotEmpty)
                  IconButton(
                    tooltip: l10n.commonCancel,
                    onPressed: () {
                      _controller.clear();
                      provider.setText('');
                      setState(() {});
                    },
                    icon: const Icon(Icons.close),
                  ),
              ],
              onChanged: (value) {
                provider.setText(value);
                setState(() {});
              },
              onSubmitted: provider.submitText,
            ),
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                  provider.loadMore();
                }
                return false;
              },
              child: ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                children: [
                  if (provider.recentSearches.isNotEmpty &&
                      !provider.hasSearched) ...[
                    _SectionLabel(l10n.searchRecent),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final term in provider.recentSearches)
                            ActionChip(
                              label: Text(term),
                              onPressed: () {
                                _controller.text = term;
                                provider.applyRecent(term);
                                setState(() {});
                              },
                            ),
                          ActionChip(
                            label: Text(l10n.searchClearRecent),
                            onPressed: provider.clearRecent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _SectionLabel(l10n.searchQuickFilters),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        FilterChip(
                          label: Text(l10n.searchFilterThisMonth),
                          selected: provider.query.thisMonth,
                          onSelected: (_) => provider.toggleThisMonth(),
                        ),
                        FilterChip(
                          label: Text(l10n.searchFilterDebits),
                          selected: provider.query.debitsOnly,
                          onSelected: (_) => provider.toggleDebits(),
                        ),
                        FilterChip(
                          label: Text(l10n.searchFilterCredits),
                          selected: provider.query.creditsOnly,
                          onSelected: (_) => provider.toggleCredits(),
                        ),
                        FilterChip(
                          label: Text(l10n.searchFilterSubscriptions),
                          selected: provider.query.subscriptionsOnly,
                          onSelected: (_) => provider.toggleSubscriptions(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (provider.isLoading)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Center(child: Text(l10n.commonLoading)),
                    )
                  else if (provider.error != null)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Center(child: Text(l10n.errorLoadFailed)),
                    )
                  else if (!provider.hasSearched)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        children: [
                          Text(
                            l10n.searchEmptyTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            l10n.searchEmptyHint,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.55),
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else if (provider.results.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Center(
                        child: Text(
                          l10n.searchNoResults,
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Text(
                        l10n.searchResultsCount('${provider.results.length}'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: TransactionGroupCard(
                        children: [
                          for (final tx in provider.results)
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
                              onMerchantTap: tx.merchant.isEmpty
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => MerchantPage(
                                            merchantNormalized:
                                                tx.resolvedMerchantKey,
                                            displayName: tx.merchant,
                                          ),
                                        ),
                                      );
                                    },
                            ),
                        ],
                      ),
                    ),
                    if (provider.isLoadingMore)
                      const Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: Center(child: CircularProgressIndicator()),
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
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
