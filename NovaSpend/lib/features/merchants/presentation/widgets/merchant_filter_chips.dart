import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/features/merchants/presentation/provider/merchant_time_filter.dart';
import 'package:nova_spend/l10n/app_strings.dart';

class MerchantFilterChips extends StatelessWidget {
  const MerchantFilterChips({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final MerchantTimeFilter selected;
  final ValueChanged<MerchantTimeFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          _MerchantFilterChip(
            label: l10n.merchantFilterAll,
            selected: selected == MerchantTimeFilter.all,
            onTap: () => onSelected(MerchantTimeFilter.all),
          ),
          const SizedBox(width: AppSpacing.sm),
          _MerchantFilterChip(
            label: l10n.merchantFilterThisMonth,
            selected: selected == MerchantTimeFilter.thisMonth,
            onTap: () => onSelected(MerchantTimeFilter.thisMonth),
          ),
          const SizedBox(width: AppSpacing.sm),
          _MerchantFilterChip(
            label: l10n.merchantFilterLast3Months,
            selected: selected == MerchantTimeFilter.last3Months,
            onTap: () => onSelected(MerchantTimeFilter.last3Months),
          ),
        ],
      ),
    );
  }
}

class _MerchantFilterChip extends StatelessWidget {
  const _MerchantFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final ink = theme.colorScheme.onSurface;
    final accent = AppColors.primaryInk(brightness);

    return Material(
      color: selected
          ? AppColors.navActiveFill(brightness)
          : AppColors.neutralFill(brightness).withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? accent : AppColors.border(brightness),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.smPlus2,
              vertical: AppSpacing.smPlus,
            ),
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? accent : ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
