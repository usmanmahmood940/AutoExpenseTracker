import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/utils/money_format.dart';
import 'package:nova_spend/core/widgets/adaptive_scaffold.dart';
import 'package:nova_spend/core/widgets/app_card.dart';
import 'package:nova_spend/core/widgets/balance_header.dart';
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
        body: Center(child: Text(context.l10n.authLoading)),
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
    final currency = summary?.currency ?? 'PKR';

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
      body: provider.isLoading
          ? Center(child: Text(l10n.commonLoading))
          : summary == null
              ? Center(child: Text(l10n.insightsEmpty))
              : ListView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                  children: [
                    BalanceHeader(
                      label: l10n.insightsNet,
                      amount: formatMoney(summary.net, currency: currency),
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
                              value: formatMoney(
                                summary.totalDebit,
                                currency: currency,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _StatCard(
                              label: l10n.insightsIncome,
                              value: formatMoney(
                                summary.totalCredit,
                                currency: currency,
                              ),
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
                          currency: currency,
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
                                    formatMoney(e.value, currency: currency),
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
    );
  }

  List<MapEntry<String, double>> _topEntries(Map<String, double> map) {
    final list = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list.take(5).toList();
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
  const _HorizontalCategoryBars({
    required this.byCategory,
    required this.currency,
  });

  final Map<String, double> byCategory;
  final String currency;

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
            amount: formatMoney(entry.value, currency: currency),
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
