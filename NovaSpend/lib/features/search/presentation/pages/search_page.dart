import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nova_spend/core/currency/app_currency_controller.dart';
import 'package:nova_spend/core/currency/app_currency_scope.dart';
import 'package:nova_spend/core/widgets/adaptive_scaffold.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/utils/date_labels.dart';
import 'package:nova_spend/core/widgets/app_loader.dart';
import 'package:nova_spend/core/widgets/empty_state_view.dart';
import 'package:nova_spend/core/widgets/error_state_view.dart';
import 'package:nova_spend/core/widgets/glass_header_bar.dart';
import 'package:nova_spend/core/widgets/section_header.dart';
import 'package:nova_spend/core/widgets/skeleton.dart';
import 'package:nova_spend/core/widgets/transaction_group_card.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/categories/presentation/widgets/category_catalog_scope.dart';
import 'package:nova_spend/features/merchants/presentation/pages/merchant_page.dart';
import 'package:nova_spend/features/search/domain/entities/date_range_preset.dart';
import 'package:nova_spend/features/search/presentation/provider/search_provider.dart';
import 'package:nova_spend/features/search/presentation/widgets/category_filter_sheet.dart';
import 'package:nova_spend/features/search/presentation/widgets/date_range_sheet.dart';
import 'package:nova_spend/features/search/presentation/widgets/filter_sheet.dart';
import 'package:nova_spend/features/search/presentation/widgets/sort_by_sheet.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/presentation/pages/transaction_detail_page.dart';
import 'package:nova_spend/features/transactions/presentation/widgets/day_group_header.dart';
import 'package:nova_spend/features/transactions/presentation/widgets/transaction_list_tile.dart';
import 'package:nova_spend/l10n/app_localizations.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:provider/provider.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().uid;
    if (uid == null) {
      return AdaptiveScaffold(
        title: context.l10n.feedTitle,
        body: AppPageLoader(label: context.l10n.authLoading),
      );
    }

    return const _SearchView();
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  late final TextEditingController _controller;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() => _maybeLoadMore();

  void _maybeLoadMore() {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 200) return;
    context.read<SearchProvider>().loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final provider = context.watch<SearchProvider>();
    if (!provider.isLoading && !provider.isLoadingMore && provider.hasMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
    }
    final topPad = GlassHeaderBar.contentTopPadding(context);

    return AdaptiveScaffold(
      applySafeArea: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    topPad,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.feedTitle,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.02 * 24,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (provider.query.hasResettableState)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            provider.resetAllFilters();
                            _controller.clear();
                            setState(() {});
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs,
                            ),
                            child: Text(
                              l10n.activityResetAll,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryStrong,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _ActivityToolbarIcon(
                        emphasized: !provider.query.sort.isDefault,
                        onTap: () => _openSortBySheet(context, provider),
                        child: SvgPicture.asset(
                          'assets/icons/icon_sort.svg',
                          width: 22,
                          height: 22,
                          colorFilter: ColorFilter.mode(
                            !provider.query.sort.isDefault
                                ? AppColors.primaryStrong
                                : theme.colorScheme.onSurface,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xsMax),
                      Expanded(
                        child: SizedBox(
                          height: _ActivitySearchRow.height,
                          child: SearchBar(
                            controller: _controller,
                            hintText: l10n.searchHint,
                            constraints: const BoxConstraints.tightFor(
                              height: _ActivitySearchRow.height,
                            ),
                            elevation: const WidgetStatePropertyAll<double>(0),
                            backgroundColor: WidgetStatePropertyAll<Color>(
                              AppColors.card(brightness),
                            ),
                            side: WidgetStatePropertyAll<BorderSide>(
                              BorderSide(
                                color: AppColors.cardBorder(brightness),
                              ),
                            ),
                            shape: const WidgetStatePropertyAll<OutlinedBorder>(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                              ),
                            ),
                            padding: const WidgetStatePropertyAll<EdgeInsets>(
                              EdgeInsets.symmetric(
                                horizontal: AppSpacing.smPlus2,
                              ),
                            ),
                            leading: Icon(
                              Icons.search_rounded,
                              size: 22,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.55,
                              ),
                            ),
                            hintStyle: WidgetStatePropertyAll<TextStyle?>(
                              theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                            ),
                            trailing: [
                              if (_controller.text.isNotEmpty)
                                IconButton(
                                  tooltip: l10n.commonCancel,
                                  onPressed: () {
                                    _controller.clear();
                                    provider.setText('');
                                    setState(() {});
                                  },
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.65),
                                  ),
                                ),
                            ],
                            onChanged: (value) {
                              provider.setText(value);
                              setState(() {});
                            },
                            onSubmitted: provider.submitText,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xsMax),
                      _ActivityToolbarIcon(
                        emphasized: provider.query.hasSheetFilters,
                        onTap: () => _openFilterSheet(context, provider),
                        child: Icon(
                          Icons.filter_alt_outlined,
                          size: 22,
                          color: provider.query.hasSheetFilters
                              ? AppColors.primaryStrong
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ActivityFilterChip(
                            label: _dateChipLabel(l10n, provider),
                            emphasized: provider.query.hasDateRange,
                            onTap: () => _openDateRangeSheet(context, provider),
                            leading: SvgPicture.asset(
                              'assets/icons/icon_calendar.svg',
                              width: 16,
                              height: 16,
                              colorFilter: ColorFilter.mode(
                                provider.query.hasDateRange
                                    ? AppColors.primaryStrong
                                    : theme.colorScheme.onSurface,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _ActivityFilterChip(
                            label: _categoryChipLabel(l10n, provider),
                            emphasized: provider.query.hasCategories,
                            onTap: () =>
                                _openCategoryFilterSheet(context, provider),
                            leading: Icon(
                              Icons.category_outlined,
                              size: 16,
                              color: provider.query.hasCategories
                                  ? AppColors.primaryStrong
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      if (provider.recentSearches.isNotEmpty &&
                          !provider.hasSearched)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            0,
                            AppSpacing.md,
                            AppSpacing.lg,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SectionHeader(
                                  title: l10n.searchRecent,
                                  actionLabel: l10n.searchClearRecent,
                                  onActionTap: provider.clearRecent,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Wrap(
                                  spacing: AppSpacing.sm,
                                  runSpacing: AppSpacing.sm,
                                  children: [
                                    for (final term in provider.recentSearches
                                        .take(5))
                                      _RecentSearchChip(
                                        label: term,
                                        onTap: () {
                                          _controller.text = term;
                                          provider.applyRecent(term);
                                          setState(() {});
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (provider.isLoading)
                        const SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            0,
                            AppSpacing.md,
                            AppSpacing.xxl,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: SkeletonTransactionList(),
                          ),
                        )
                      else if (provider.error != null &&
                          provider.results.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: ErrorStateView(
                            error: provider.error,
                            onRetry: () =>
                                provider.runSearch(saveRecent: false),
                          ),
                        )
                      else if (!provider.hasSearched)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyStateView(
                            title: l10n.searchEmptyTitle,
                            message: l10n.searchEmptyHint,
                          ),
                        )
                      else if (provider.results.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyStateView(
                            title: provider.query.hasActiveFilters
                                ? l10n.searchNoResultsTitle
                                : l10n.feedEmpty,
                            message: provider.query.hasActiveFilters
                                ? l10n.searchNoResultsHint
                                : l10n.feedEmptyHint,
                          ),
                        )
                      else ...[
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _ResultsCountRow(
                                  count: provider.matchCount,
                                  spent: provider.matchSpent,
                                  received: provider.matchReceived,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                provider.query.sort.groupsByDay
                                    ? _ResultsDayGroups(
                                        results: provider.results,
                                      )
                                    : _ResultsFlatList(
                                        results: provider.results,
                                      ),
                                if (provider.error != null) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  LoadErrorBanner(
                                    error: provider.error,
                                    onRetry: provider.loadMore,
                                  ),
                                ],
                                if (provider.isLoadingMore)
                                  const AppListFooterLoader(),
                                const SizedBox(height: AppSpacing.xxl),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
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
        ],
      ),
    );
  }

  Future<void> _openFilterSheet(
    BuildContext context,
    SearchProvider provider,
  ) async {
    final selected = await FilterSheet.show(
      context,
      initial: provider.query.hasSheetFilters
          ? FilterSheetValue.fromQuery(provider.query)
          : null,
    );
    if (selected == null || !mounted) return;
    if (selected.cleared) {
      provider.clearSheetFilters();
      return;
    }
    provider.applySheetFilters(
      amountMin: selected.value.amountMin,
      amountMax: selected.value.amountMax,
      type: selected.value.type,
      paymentMethods: selected.value.paymentMethods,
      sources: selected.value.sources,
    );
  }

  Future<void> _openSortBySheet(
    BuildContext context,
    SearchProvider provider,
  ) async {
    final selected = await SortBySheet.show(
      context,
      initial: provider.query.sort,
    );
    if (selected == null || !mounted) return;
    provider.setSort(selected);
  }

  Future<void> _openDateRangeSheet(
    BuildContext context,
    SearchProvider provider,
  ) async {
    final q = provider.query;
    final initial = q.hasDateRange
        ? DateRangeValue(
            preset: q.datePreset ?? DateRangePreset.custom,
            from: q.dateFrom!,
            to: q.dateTo!,
          )
        : null;
    final selected = await DateRangeSheet.show(context, initial: initial);
    if (selected == null || !mounted) return;
    if (selected.cleared) {
      provider.clearDateRange();
      return;
    }
    final range = selected.range;
    if (range == null) return;
    provider.setDateRange(range);
  }

  Future<void> _openCategoryFilterSheet(
    BuildContext context,
    SearchProvider provider,
  ) async {
    final selected = await CategoryFilterSheet.show(
      context,
      categories: CategoryCatalogScope.of(context),
      initialSelected: provider.query.categories,
    );
    if (selected == null || !mounted) return;
    if (selected.cleared) {
      provider.clearCategories();
      return;
    }
    provider.setCategories(selected.categories);
  }

  String _categoryChipLabel(AppLocalizations l10n, SearchProvider provider) {
    final selected = provider.query.categories;
    if (selected.isEmpty) return l10n.activityChipAllCategories;
    if (selected.length == 1) return selected.first;
    return l10n.activityChipCategoryCount(selected.length);
  }

  String _dateChipLabel(AppLocalizations l10n, SearchProvider provider) {
    final preset = provider.query.datePreset;
    if (preset == null) return l10n.activityChipDate;
    return switch (preset) {
      DateRangePreset.today => l10n.homePeriodToday,
      DateRangePreset.yesterday => l10n.commonYesterday,
      DateRangePreset.thisWeek => l10n.homePeriodThisWeek,
      DateRangePreset.lastWeek => l10n.dateRangeLastWeek,
      DateRangePreset.thisMonth => l10n.homePeriodThisMonth,
      DateRangePreset.lastMonth => l10n.dateRangeLastMonth,
      DateRangePreset.last3Months => l10n.dateRangeLast3Months,
      DateRangePreset.thisYear => l10n.dateRangeThisYear,
      DateRangePreset.custom => l10n.dateRangeCustom,
    };
  }
}

/// Results count on the left, Spent / Net for the full match set on the right.
class _ResultsCountRow extends StatelessWidget {
  const _ResultsCountRow({
    required this.count,
    required this.spent,
    required this.received,
  });

  final int count;
  final double spent;
  final double received;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final money = AppCurrencyScope.of(context);
    final muted = Color.lerp(
      theme.colorScheme.onSurfaceVariant,
      theme.colorScheme.onSurface,
      1,
    )!;
    final summary = dayGroupSummary(
      spent: spent,
      received: received,
      spentPrefix: l10n.homeDayGroupSpent,
      netPrefix: l10n.homeDayGroupNet,
      formatMoney: money.formatMoney,
    );
    final showSummary =
        summary.prefix != null &&
        summary.amount != null &&
        summary.amount!.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            l10n.searchResultsCount('$count'),
            style: theme.textTheme.titleMedium,
          ),
        ),
        if (showSummary)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: summary.prefix,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: muted,
                  ),
                ),
                TextSpan(
                  text: summary.amount,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.05 * 13,
                    color: summary.amountColor ?? muted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Flat results list (amount / merchant sorts — no day headers).
class _ResultsFlatList extends StatelessWidget {
  const _ResultsFlatList({required this.results});

  final List<TransactionEntity> results;

  @override
  Widget build(BuildContext context) {
    return TransactionGroupCard(
      children: [for (final tx in results) _resultTile(context, tx)],
    );
  }
}

/// Day-grouped results with Spent / Net summaries (same pattern as Home).
/// Only used when sorting by date newest / oldest.
class _ResultsDayGroups extends StatelessWidget {
  const _ResultsDayGroups({required this.results});

  final List<TransactionEntity> results;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final money = AppCurrencyScope.of(context);
    final grouped = _groupByDayPreservingOrder(results);
    final days = grouped.keys.toList();
    if (days.isEmpty) return const SizedBox.shrink();

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
}

Widget _resultTile(BuildContext context, TransactionEntity tx) {
  return TransactionListTile(
    transaction: tx,
    onTap: () {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TransactionDetailPage(transaction: tx),
        ),
      );
    },
    onMerchantTap: tx.displayMerchant.isEmpty
        ? null
        : () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MerchantPage(
                  merchantNormalized: tx.resolvedMerchantKey,
                  displayName: tx.displayMerchant,
                ),
              ),
            );
          },
  );
}

/// Groups by `transactionDate`, keeping day and within-day order from [items]
/// (so the active sort still applies).
Map<String, List<TransactionEntity>> _groupByDayPreservingOrder(
  List<TransactionEntity> items,
) {
  final map = <String, List<TransactionEntity>>{};
  for (final t in items) {
    map.putIfAbsent(t.transactionDate, () => []).add(t);
  }
  return map;
}

({double spent, double received}) _spendTotals(List<TransactionEntity> txs) {
  var spent = 0.0;
  var received = 0.0;
  for (final t in txs) {
    if (t.type == 'credit') {
      received += t.amount;
    } else {
      spent += t.amount;
    }
  }
  return (spent: spent, received: received);
}

TransactionGroupSection _daySection(
  BuildContext context,
  AppLocalizations l10n, {
  required String day,
  required List<TransactionEntity> txs,
  required AppCurrencyController money,
}) {
  final totals = _spendTotals(txs);
  final summary = dayGroupSummary(
    spent: totals.spent,
    received: totals.received,
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
    children: [for (final tx in txs) _resultTile(context, tx)],
  );
}

class _ActivityToolbarIcon extends StatelessWidget {
  const _ActivityToolbarIcon({
    required this.child,
    this.emphasized = false,
    this.onTap,
  });

  final Widget child;
  final bool emphasized;
  final VoidCallback? onTap;

  static const double size = _ActivitySearchRow.height;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = AppColors.primaryStrong;

    return SizedBox(
      width: (size * 85) / 100,
      height: size,
      child: Material(
        color: emphasized
            ? AppColors.navActiveFill(brightness)
            : AppColors.card(brightness),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: emphasized ? accent : AppColors.cardBorder(brightness),
              ),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

abstract final class _ActivitySearchRow {
  static const double height = 44;
}

class _ActivityFilterChip extends StatelessWidget {
  const _ActivityFilterChip({
    required this.label,
    required this.leading,
    this.emphasized = false,
    this.onTap,
  });

  final String? label;
  final Widget leading;
  final bool emphasized;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final ink = theme.colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: emphasized
                ? AppColors.navActiveFill(brightness)
                : AppColors.card(brightness),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: emphasized
                  ? AppColors.primaryStrong
                  : AppColors.cardBorder(brightness),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.smPlus2,
              vertical: AppSpacing.smPlus,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                leading,
                if (label != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      label!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: emphasized ? AppColors.primaryStrong : ink,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: emphasized ? AppColors.primaryStrong : ink,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentSearchChip extends StatelessWidget {
  const _RecentSearchChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.neutralFill(brightness),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.smPlus2,
            vertical: AppSpacing.smPlus,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/icons/icon_clock.svg',
                width: 14,
                height: 14,
                colorFilter: ColorFilter.mode(muted, BlendMode.srcIn),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
