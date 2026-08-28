import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_shadows.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';

class InsightsKpiRow extends StatelessWidget {
  const InsightsKpiRow({
    required this.spentLabel,
    required this.spentValue,
    required this.receivedLabel,
    required this.receivedValue,
    required this.netLabel,
    required this.netValue,
    required this.countLabel,
    required this.countValue,
    required this.trendSuffix,
    this.spentChangePercent,
    this.receivedChangePercent,
    this.netChangePercent,
    this.transactionCountChange,
    this.netAmountColor,
    super.key,
  });

  final String spentLabel;
  final String spentValue;
  final String receivedLabel;
  final String receivedValue;
  final String netLabel;
  final String netValue;
  final String countLabel;
  final String countValue;
  final String trendSuffix;
  final double? spentChangePercent;
  final double? receivedChangePercent;
  final double? netChangePercent;
  final int? transactionCountChange;
  final Color? netAmountColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _InsightsStatCard(
                    label: spentLabel,
                    value: spentValue,
                    iconAsset: 'assets/icons/icon_highest_spend.svg',
                    changePercent: spentChangePercent,
                    trendSuffix: trendSuffix,
                    positiveIsGood: false,
                  ),
                ),
                const SizedBox(width: AppSpacing.smPlus2),
                Expanded(
                  child: _InsightsStatCard(
                    label: receivedLabel,
                    value: receivedValue,
                    iconAsset: 'assets/icons/icon_highest_received.svg',
                    changePercent: receivedChangePercent,
                    trendSuffix: trendSuffix,
                    positiveIsGood: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.smPlus2),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _InsightsStatCard(
                    label: netLabel,
                    value: netValue,
                    iconAsset: 'assets/icons/icon_net_flow.svg',
                    changePercent: netChangePercent,
                    trendSuffix: trendSuffix,
                    positiveIsGood: true,
                    amountColor: netAmountColor,
                  ),
                ),
                const SizedBox(width: AppSpacing.smPlus2),
                Expanded(
                  child: _InsightsStatCard(
                    label: countLabel,
                    value: countValue,
                    iconAsset: 'assets/icons/icon_transactions.svg',
                    countChange: transactionCountChange,
                    trendSuffix: trendSuffix,
                    positiveIsGood: true,
                    countChangeNeutral: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsStatCard extends StatelessWidget {
  const _InsightsStatCard({
    required this.label,
    required this.value,
    required this.iconAsset,
    required this.trendSuffix,
    this.changePercent,
    this.countChange,
    this.positiveIsGood = false,
    this.countChangeNeutral = false,
    this.amountColor,
  });

  final String label;
  final String value;
  final String iconAsset;
  final String trendSuffix;
  final double? changePercent;
  final int? countChange;
  final bool positiveIsGood;
  final bool countChangeNeutral;
  final Color? amountColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card(brightness),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.smPlus3),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.cardBorder(brightness)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.95,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                SvgPicture.asset(iconAsset, width: 28, height: 28),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.02 * 16,
                height: 1.2,
                color: amountColor ?? theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            const SizedBox(height: AppSpacing.sm),
            _InsightsChangeCaption(
              percent: changePercent,
              countChange: countChange,
              suffix: trendSuffix,
              positiveIsGood: positiveIsGood,
              countChangeNeutral: countChangeNeutral,
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightsChangeCaption extends StatelessWidget {
  const _InsightsChangeCaption({
    required this.suffix,
    required this.positiveIsGood,
    this.percent,
    this.countChange,
    this.countChangeNeutral = false,
  });

  final double? percent;
  final int? countChange;
  final String suffix;
  final bool positiveIsGood;
  final bool countChangeNeutral;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);

    final value = percent;
    final count = countChange;
    final isFlat = (value != null && value.abs() < 0.5) || count == 0;
    if (value == null && count == null) {
      return Text(
        '—',
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 11,
          color: muted,
        ),
      );
    }
    if (isFlat) {
      return Text(
        suffix,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: muted,
        ),
      );
    }

    final isUp = value != null ? value >= 0 : count! >= 0;
    final isGood = countChangeNeutral ? true : (positiveIsGood ? isUp : !isUp);
    final trendColor = countChangeNeutral
        ? muted
        : (isGood ? AppColors.primaryStrong : AppColors.spend);
    final display = value != null
        ? '${value.abs().round()}%'
        : '${count!.abs()}';

    return Row(
      children: [
        Icon(
          isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 12,
          color: trendColor,
        ),
        const SizedBox(width: 2),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: display,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: trendColor,
                  ),
                ),
                TextSpan(
                  text: ' $suffix',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                    color: muted,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
