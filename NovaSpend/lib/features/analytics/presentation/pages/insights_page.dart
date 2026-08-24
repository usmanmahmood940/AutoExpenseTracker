import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/currency/app_currency_scope.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/adaptive_scaffold.dart';
import 'package:nova_spend/core/widgets/app_card.dart';
import 'package:nova_spend/core/widgets/app_loader.dart';
import 'package:nova_spend/core/widgets/balance_header.dart';
import 'package:nova_spend/core/widgets/error_state_view.dart';
import 'package:nova_spend/core/widgets/skeleton.dart';
import 'package:nova_spend/features/analytics/presentation/provider/insights_provider.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/merchants/presentation/pages/merchant_page.dart';
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
      appBar: AppBar(
        title: Text(l10n.insightsTitle),
        actions: [
          IconButton(
            tooltip: l10n.insightsPrevMonth,
            onPressed: provider.previousMonth,
            icon: const Icon(Icons.chevron_left),
          ),
          Center(
            child: Text(
              DateFormat.yMMMM().format(provider.month),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          IconButton(
            tooltip: l10n.insightsNextMonth,
            onPressed: provider.nextMonth,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      body: provider.isLoading && summary == null
          ? const _InsightsSkeleton()
          : provider.error != null && summary == null
              ? ErrorStateView(
                  error: provider.error,
                  onRetry: provider.retry,
                )
              : summary == null
              ? Center(child: Text(l10n.insightsEmpty))
              : AppBusyContent(
                  busy: provider.isLoading,
                  child: ListView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                  children: [
                    BalanceHeader(
                      label: l10n.insightsNet,
                      amount: money.formatMoney(summary.net),
                      subtitle: l10n.insightsThisMonth,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: l10n.insightsSpent,
                              value: money.formatMoney(summary.totalDebit),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _StatCard(
                              label: l10n.insightsIncome,
                              value: money.formatMoney(summary.totalCredit),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionTitle(l10n.insightsByCategory),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: AppCard(
                        child: _HorizontalCategoryBars(
                          byCategory: summary.byCategory,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionTitle(l10n.insightsTopMerchants),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: AppCard(
                        child: Column(
                          children: _topEntries(summary.byMerchant)
                              .map(
                                (e) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(e.key),
                                  trailing: Text(
                                    money.formatMoney(e.value),
                                  ),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => MerchantPage(
                                          merchantNormalized:
                                              normalizeMerchantKey(e.key),
                                          displayName: e.key,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                  ),
                ),
    );
  }

  List<MapEntry<String, double>> _topEntries(Map<String, double> map) {
    final list = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list.take(5).toList();
  }
}

/// First-load placeholder mirroring the insights layout.
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
              Expanded(child: _StatCardBones()),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: _StatCardBones()),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const SkeletonSectionHeader(titleWidth: 124),
          const SizedBox(height: AppSpacing.sm),
          SkeletonCard(
            child: Column(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i != 0) const SizedBox(height: AppSpacing.smPlus2),
                  const _CategoryBarBones(),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SkeletonSectionHeader(titleWidth: 148),
          const SizedBox(height: AppSpacing.sm),
          const SkeletonCardList(cardCount: 1, linesPerCard: 4),
        ],
      ),
    );
  }
}

class _StatCardBones extends StatelessWidget {
  const _StatCardBones();

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 64, height: 11),
          SizedBox(height: AppSpacing.xs),
          SkeletonBox(width: 96, height: 16),
        ],
      ),
    );
  }
}

class _CategoryBarBones extends StatelessWidget {
  const _CategoryBarBones();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SkeletonBox(width: 104, height: 12),
            Spacer(),
            SkeletonBox(width: 56, height: 10),
          ],
        ),
        SizedBox(height: AppSpacing.xs),
        SkeletonBox(height: 8, radius: 4),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

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
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55),
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _HorizontalCategoryBars extends StatelessWidget {
  const _HorizontalCategoryBars({required this.byCategory});

  final Map<String, double> byCategory;

  @override
  Widget build(BuildContext context) {
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(5).toList();

    if (top.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(child: Text(context.l10n.insightsEmpty)),
      );
    }

    final maxValue = top.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        for (final entry in top) ...[
          _CategoryBarRow(
            label: entry.key,
            amount: AppCurrencyScope.of(context).formatMoney(entry.value),
            fraction: maxValue > 0 ? entry.value / maxValue : 0,
          ),
          if (entry != top.last) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _CategoryBarRow extends StatelessWidget {
  const _CategoryBarRow({
    required this.label,
    required this.amount,
    required this.fraction,
  });

  final String label;
  final String amount;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(amount, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.08),
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}
