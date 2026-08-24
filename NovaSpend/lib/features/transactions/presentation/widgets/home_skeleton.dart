import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/skeleton.dart';

/// Skeleton for [PeriodOverviewCard] while home data is loading.
class PeriodOverviewSkeleton extends StatelessWidget {
  const PeriodOverviewSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.md),
        child: SkeletonCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: SkeletonBox(width: 148, height: 14)),
                  SkeletonBox(width: 18, height: 18, radius: AppRadius.pill),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              SkeletonBox(width: 64, height: 10),
              SizedBox(height: AppSpacing.xs),
              SkeletonBox(width: 112, height: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for highlights + recent transaction list on first home load.
class HomeFeedSkeleton extends StatelessWidget {
  const HomeFeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          SkeletonSectionHeader(titleWidth: 140, actionWidth: 96),
          SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: _HighlightCardBones()),
              SizedBox(width: AppSpacing.smPlus2),
              Expanded(child: _HighlightCardBones()),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          SkeletonSectionHeader(titleWidth: 168, actionWidth: 56),
          SizedBox(height: AppSpacing.sm),
          SkeletonTransactionList(groupCount: 1, rowsPerGroup: 4),
        ],
      ),
    );
  }
}

class _HighlightCardBones extends StatelessWidget {
  const _HighlightCardBones();

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
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
