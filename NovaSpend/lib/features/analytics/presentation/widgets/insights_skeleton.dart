import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/app_card.dart';
import 'package:nova_spend/core/widgets/skeleton.dart';
import 'package:nova_spend/features/transactions/presentation/widgets/home_skeleton.dart';

/// Skeleton for the 2×2 KPI grid while insights summary is loading.
class InsightsKpiSkeleton extends StatelessWidget {
  const InsightsKpiSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          HighlightCardsSkeleton(),
          SizedBox(height: AppSpacing.smPlus2),
          HighlightCardsSkeleton(),
        ],
      ),
    );
  }
}

/// Skeleton for the green narrative card while AI copy loads.
class InsightsNarrativeSkeleton extends StatelessWidget {
  const InsightsNarrativeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: SkeletonCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SkeletonBox(width: 40, height: 40, radius: AppRadius.pill),
              SizedBox(width: AppSpacing.smPlus2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 148, height: 14),
                    SizedBox(height: AppSpacing.sm),
                    SkeletonBox(width: double.infinity, height: 11),
                    SizedBox(height: AppSpacing.xs),
                    SkeletonBox(width: 220, height: 11),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for the spending trend chart while extras load.
class InsightsTrendSkeleton extends StatelessWidget {
  const InsightsTrendSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: SkeletonCard(child: SizedBox(height: 180)),
      ),
    );
  }
}

/// Skeleton for category bar rows while summary is loading.
class InsightsCategorySkeleton extends StatelessWidget {
  const InsightsCategorySkeleton({super.key, this.rowCount = 4});

  final int rowCount;

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: SkeletonCard(
          child: Column(
            children: [
              for (var i = 0; i < rowCount; i++) ...[
                if (i != 0) const SizedBox(height: AppSpacing.smPlus2),
                const Row(
                  children: [
                    SkeletonBox(width: 36, height: 36, radius: AppRadius.pill),
                    SizedBox(width: AppSpacing.smPlus2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: SkeletonBox(width: 100, height: 13),
                              ),
                              SizedBox(width: AppSpacing.sm),
                              SkeletonBox(width: 28, height: 11),
                            ],
                          ),
                          SizedBox(height: AppSpacing.xs),
                          SkeletonBox(width: double.infinity, height: 8),
                        ],
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    SkeletonBox(width: 56, height: 13),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline empty message for an insights section card.
class InsightsSectionEmpty extends StatelessWidget {
  const InsightsSectionEmpty({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.lg,
            horizontal: AppSpacing.sm,
          ),
          child: Center(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: muted,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton for top merchant rows while extras load.
class InsightsMerchantListSkeleton extends StatelessWidget {
  const InsightsMerchantListSkeleton({super.key, this.rowCount = 4});

  final int rowCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: SkeletonCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          children: [
            for (var i = 0; i < rowCount; i++) ...[
              if (i != 0)
                Divider(
                  height: 1,
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.35),
                ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.smPlus2),
                child: Row(
                  children: [
                    SkeletonBox(width: 40, height: 40, radius: AppRadius.pill),
                    SizedBox(width: AppSpacing.smPlus2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 120, height: 13),
                          SizedBox(height: AppSpacing.xs),
                          SkeletonBox(width: 88, height: 11),
                        ],
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    SkeletonBox(width: 64, height: 14),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
