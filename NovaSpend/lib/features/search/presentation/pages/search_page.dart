import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/adaptive_scaffold.dart';
import 'package:nova_spend/core/widgets/glass_header_bar.dart';
import 'package:nova_spend/core/widgets/section_header.dart';
import 'package:nova_spend/core/widgets/transaction_group_card.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/merchants/presentation/pages/merchant_page.dart';
import 'package:nova_spend/features/search/domain/entities/date_range_preset.dart';
import 'package:nova_spend/features/search/presentation/provider/search_provider.dart';
import 'package:nova_spend/features/search/presentation/widgets/date_range_sheet.dart';
import 'package:nova_spend/features/search/presentation/widgets/sort_by_sheet.dart';
import 'package:nova_spend/features/transactions/presentation/pages/transaction_detail_page.dart';
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
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final provider = context.watch<SearchProvider>();
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
                  child: Align(
                    alignment: Alignment.centerLeft,
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
                      const _ActivityToolbarIcon(
                        child: Icon(
                          Icons.filter_alt_outlined,
                          size: 22,
                          color: AppColors.primaryStrong,
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
                            label: l10n.activityChipAllCategories,
                            leading: Icon(
                              Icons.category_outlined,
                              size: 16,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              0,
                              AppSpacing.md,
                              AppSpacing.sm,
                            ),
                            child: SectionHeader(
                              title: l10n.searchRecent,
                              actionLabel: l10n.searchClearRecent,
                              onActionTap: provider.clearRecent,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            child: Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                for (final term in provider.recentSearches.take(
                                  5,
                                ))
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
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
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
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  l10n.searchEmptyHint,
                                  style: Theme.of(context).textTheme.bodyMedium
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
                              l10n.searchResultsCount(
                                '${provider.results.length}',
                              ),
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
                                          builder: (_) => TransactionDetailPage(
                                            transaction: tx,
                                          ),
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
