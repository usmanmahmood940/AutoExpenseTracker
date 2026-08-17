import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

/// Compact stat tile: icon badge, label, headline value, and muted subtitle.
///
/// Two of these sit side by side under the highlights header
/// ("Highest spend" / "Highest received"), but it's reusable for any KPI pair.
class StatHighlightCard extends StatelessWidget {
  const StatHighlightCard({
    required this.label,
    required this.iconAsset,
    required this.amount,
    required this.subtitle,
    this.amountColor,
    this.onTap,
    super.key,
  });

  final String label;
  final String iconAsset;
  final String amount;
  final String subtitle;
  final Color? amountColor;
  final VoidCallback? onTap;

  static const _iconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;

    final content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: AppShadows.card(brightness),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.smPlus3),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.cardBorder(brightness)),
        ),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.95,
                          ),
                          height: 1.3,
                        ),
                      ),
                    ),
                    // const SizedBox(width: AppSpacing.xs),
                    // SvgPicture.asset(
                    //   iconAsset,
                    //   width: _iconSize,
                    //   height: _iconSize,
                    // ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xsMini),
                Text(
                  amount,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.01 * 18,
                    color: amountColor ?? theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xsMini),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.85,
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                ),
              ],
            ),
          ),
          SvgPicture.asset(iconAsset, width: _iconSize, height: _iconSize),
        ],
      ),
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: content,
      ),
    );
  }
}
