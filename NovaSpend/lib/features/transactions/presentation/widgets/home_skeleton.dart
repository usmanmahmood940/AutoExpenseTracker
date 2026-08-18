import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_shadows.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/skeleton.dart';

/// Skeleton for [PeriodOverviewCard] while home data is loading.
class PeriodOverviewSkeleton extends StatelessWidget {
  const PeriodOverviewSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: _CardShell(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: SkeletonBox(width: 148, height: 14)),
                  SkeletonBox(width: 18, height: 18, radius: AppRadius.pill),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              _OverviewRowBones(),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewRowBones extends StatelessWidget {
  const _OverviewRowBones();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(width: 64, height: 10),
        SizedBox(height: AppSpacing.xs),
        SkeletonBox(width: 112, height: 18),
      ],
    );
  }
}

/// Skeleton for highlights + recent transaction list on first home load.
class HomeFeedSkeleton extends StatelessWidget {
  const HomeFeedSkeleton({super.key});

  static const _rowCount = 4;

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeaderBones(titleWidth: 140, actionWidth: 96),
          const SizedBox(height: AppSpacing.sm),
          const Row(
            children: [
              Expanded(child: _HighlightCardBones()),
              SizedBox(width: AppSpacing.smPlus2),
              Expanded(child: _HighlightCardBones()),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionHeaderBones(titleWidth: 168, actionWidth: 56),
          const SizedBox(height: AppSpacing.sm),
          _CardShell(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _DayHeaderBones(),
                for (var i = 0; i < _rowCount; i++) ...[
                  const _TransactionRowBones(),
                  if (i != _rowCount - 1) _rowDivider(context),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowDivider(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Divider(
      height: 1,
      thickness: 1,
      indent: AppSpacing.md,
      endIndent: AppSpacing.md,
      color: AppColors.border(brightness),
    );
  }
}

class _SectionHeaderBones extends StatelessWidget {
  const _SectionHeaderBones({
    required this.titleWidth,
    required this.actionWidth,
  });

  final double titleWidth;
  final double actionWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SkeletonBox(width: titleWidth, height: 16),
        SkeletonBox(width: actionWidth, height: 12),
      ],
    );
  }
}

class _HighlightCardBones extends StatelessWidget {
  const _HighlightCardBones();

  @override
  Widget build(BuildContext context) {
    return const _CardShell(
      padding: EdgeInsets.all(AppSpacing.smPlus3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 88, height: 11),
          SizedBox(height: AppSpacing.sm),
          SkeletonBox(width: 72, height: 14),
          SizedBox(height: AppSpacing.xs),
          SkeletonBox(width: 108, height: 10),
        ],
      ),
    );
  }
}

class _DayHeaderBones extends StatelessWidget {
  const _DayHeaderBones();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return ColoredBox(
      color: AppColors.neutralFill(brightness).withValues(alpha: 0.45),
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.smPlus,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SkeletonBox(width: 72, height: 11),
            SkeletonBox(width: 88, height: 11),
          ],
        ),
      ),
    );
  }
}

class _TransactionRowBones extends StatelessWidget {
  const _TransactionRowBones();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          SkeletonBox(width: 44, height: 44, radius: AppRadius.sm),
          SizedBox(width: AppSpacing.smPlus),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120, height: 13),
                SizedBox(height: AppSpacing.xs),
                SkeletonBox(width: 72, height: 11),
                SizedBox(height: AppSpacing.xs),
                SkeletonBox(width: 48, height: 10),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          SkeletonBox(width: 64, height: 14),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card(brightness),
      ),
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.card(brightness),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.cardBorder(brightness)),
        ),
        child: child,
      ),
    );
  }
}
