import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/features/analytics/domain/insights_math.dart';
import 'package:nova_spend/l10n/app_strings.dart';

class InsightsMerchantSortDropdown extends StatelessWidget {
  const InsightsMerchantSortDropdown({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final TopMerchantSort value;
  final ValueChanged<TopMerchantSort> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.border(brightness).withValues(alpha: 0.65),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smPlus2),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<TopMerchantSort>(
            value: value,
            isDense: true,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: muted,
            ),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            style: theme.textTheme.bodySmall?.copyWith(
              color: muted,
              fontWeight: FontWeight.w500,
            ),
            selectedItemBuilder: (context) {
              return TopMerchantSort.values
                  .map((sort) => _label(context, sort))
                  .map(
                    (label) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList();
            },
            items: [
              for (final sort in TopMerchantSort.values)
                DropdownMenuItem(
                  value: sort,
                  child: Text(_label(context, sort)),
                ),
            ],
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
      ),
    );
  }

  String _label(BuildContext context, TopMerchantSort sort) {
    final l10n = context.l10n;
    return switch (sort) {
      TopMerchantSort.amountSpent => l10n.insightsTopMerchantsSortSpent,
      TopMerchantSort.amountReceived => l10n.insightsTopMerchantsSortReceived,
      TopMerchantSort.visits => l10n.insightsTopMerchantsSortVisits,
    };
  }
}
