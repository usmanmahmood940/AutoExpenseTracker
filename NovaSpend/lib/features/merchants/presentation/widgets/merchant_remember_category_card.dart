import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/app_card.dart';
import 'package:nova_spend/core/widgets/app_loader.dart';
import 'package:nova_spend/core/widgets/category_avatar.dart';
import 'package:nova_spend/features/merchants/presentation/provider/merchant_provider.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:provider/provider.dart';

class MerchantRememberCategoryCard extends StatelessWidget {
  const MerchantRememberCategoryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchantProvider>();
    final category = provider.rememberCategoryLabel;
    if (category.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = context.l10n;
    final ink = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;
    final merchantName = provider.summary?.displayName ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.smPlus2,
        ),
        child: Row(
          children: [
            CategoryAvatar(category: category, size: 40),
            const SizedBox(width: AppSpacing.smPlus2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.transactionRememberMerchant,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.transactionAutoCategorizeHint(merchantName),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
            if (provider.isLoadingRememberState || provider.isSavingRemember)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: AppLoader(size: AppLoaderSize.small),
              )
            else
              Switch.adaptive(
                value: provider.rememberCategory,
                activeTrackColor: AppColors.primaryStrong.withValues(alpha: 0.5),
                activeThumbColor: AppColors.primaryStrong,
                onChanged: (value) async {
                  final ok = await provider.setRememberCategory(value);
                  if (!context.mounted || ok) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.errorGeneric)),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
