import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/utils/money_format.dart';
import 'package:nova_spend/core/widgets/adaptive_scaffold.dart';
import 'package:nova_spend/core/widgets/app_card.dart';
import 'package:nova_spend/core/widgets/balance_header.dart';
import 'package:nova_spend/features/analytics/domain/entities/monthly_summary_entity.dart';
import 'package:nova_spend/features/analytics/presentation/provider/insights_provider.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
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
                    _SectionTitle(l10n.insightsCashFlow),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: AppCard(
                        child: SizedBox(
                          height: 180,
                          child: BarChart(
                            BarChartData(
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(),
                                rightTitles: const AxisTitles(),
                                leftTitles: const AxisTitles(),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, _) {
                                      if (value == 0) {
                                        return Text(l10n.insightsSpent);
                                      }
                                      if (value == 1) {
                                        return Text(l10n.insightsIncome);
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                              ),
                              barGroups: [
                                BarChartGroupData(
                                  x: 0,
                                  barRods: [
                                    BarChartRodData(
                                      toY: summary.totalDebit,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.35),
                                      width: 28,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ],
                                ),
                                BarChartGroupData(
                                  x: 1,
                                  barRods: [
                                    BarChartRodData(
                                      toY: summary.totalCredit,
                                      color: AppColors.accent,
                                      width: 28,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionTitle(l10n.insightsByCategory),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: AppCard(
                        child: SizedBox(
                          height: 220,
                          child: _CategoryBars(byCategory: summary.byCategory),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionTitle(l10n.insightsTrends),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: AppCard(
                        child: SizedBox(
                          height: 200,
                          child: _TrendLine(summaries: provider.recent),
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

class _CategoryBars extends StatelessWidget {
  const _CategoryBars({required this.byCategory});

  final Map<String, double> byCategory;

  @override
  Widget build(BuildContext context) {
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(6).toList();
    if (top.isEmpty) {
      return Center(child: Text(context.l10n.insightsEmpty));
    }
    final maxY = top.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: maxY * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= top.length) return const SizedBox.shrink();
                final label = top[i].key;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    label.length > 8 ? '${label.substring(0, 8)}…' : label,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < top.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: top[i].value,
                  color: AppColors.accent,
                  width: 16,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TrendLine extends StatelessWidget {
  const _TrendLine({required this.summaries});

  final List<MonthlySummaryEntity> summaries;

  @override
  Widget build(BuildContext context) {
    final chronological = [...summaries].reversed.toList();
    if (chronological.isEmpty) {
      return Center(child: Text(context.l10n.insightsEmpty));
    }

    final spots = <FlSpot>[
      for (var i = 0; i < chronological.length; i++)
        FlSpot(i.toDouble(), chronological[i].totalDebit),
    ];

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(),
          rightTitles: AxisTitles(),
          leftTitles: AxisTitles(),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.accent,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.accentMuted,
            ),
          ),
        ],
      ),
    );
  }
}
