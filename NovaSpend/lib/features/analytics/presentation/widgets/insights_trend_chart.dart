import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_gradients.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/app_card.dart';
import 'package:nova_spend/features/analytics/domain/entities/trend_point_entity.dart';
import 'package:nova_spend/features/analytics/domain/insights_math.dart';

class InsightsTrendChart extends StatelessWidget {
  const InsightsTrendChart({
    required this.points,
    required this.formatMoney,
    this.previousValues = const [],
    super.key,
  });

  final List<TrendPointEntity> points;
  final List<double> previousValues;
  final String Function(double amount) formatMoney;

  @override
  Widget build(BuildContext context) {
    if (!hasTrendChartContent(points)) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final alignedPrevious = previousValues;
    final showPrevious = alignedPrevious.any((value) => value > 0.0001);
    final maxY = [
      ...points.map((point) => point.debit),
      if (showPrevious) ...alignedPrevious,
    ].fold<double>(0, (max, value) => value > max ? value : max);
    final yInterval = compactYAxisInterval(maxY).toDouble();
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].debit),
    ];
    final previousSpots = <FlSpot>[
      for (var i = 0; i < alignedPrevious.length; i++)
        FlSpot(i.toDouble(), alignedPrevious[i]),
    ];
    final labelEvery = (points.length / 4).ceil().clamp(1, points.length);
    final totalSpend = points.fold<double>(0, (sum, point) => sum + point.debit);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Semantics(
        label: 'Spend over time, total ${formatMoney(totalSpend)}',
        child: AppCard(
          child: SizedBox(
            height: 180,
            child: Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
              ),
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY <= 0 ? 1 : maxY * 1.1,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: yInterval,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: yInterval,
                        getTitlesWidget: (value, meta) {
                          if (value <= 0) {
                            return Text(
                              '0',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.45),
                              ),
                            );
                          }
                          return Text(
                            compactAxisLabel(value),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.45),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: labelEvery.toDouble(),
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if (index < 0 || index >= points.length) {
                            return const SizedBox.shrink();
                          }
                          if (index % labelEvery != 0 &&
                              index != points.length - 1) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              DateFormat.MMMd().format(points[index].date),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.45),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touched) {
                        return [
                          for (final spot in touched)
                            LineTooltipItem(
                              formatMoney(spot.y),
                              TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                        ];
                      },
                    ),
                  ),
                  lineBarsData: [
                    if (showPrevious)
                      LineChartBarData(
                        spots: previousSpots,
                        isCurved: true,
                        preventCurveOverShooting: true,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        dashArray: const [6, 4],
                      ),
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: AppColors.positiveAmount(theme.brightness),
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: !showPrevious,
                        gradient: AppGradients.chartArea(theme.brightness),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
