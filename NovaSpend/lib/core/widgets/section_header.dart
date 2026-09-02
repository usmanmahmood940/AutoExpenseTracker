import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Row with a bold section title and an optional trailing text action.
///
/// Used for "Recent Transactions / View All" style headers across screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.actionLabel,
    this.onActionTap,
    this.showActionChevron = false,
    this.trailing,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final bool showActionChevron;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.01 * 18,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null)
          trailing!
        else if (actionLabel != null && onActionTap != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onActionTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryInk(theme.brightness),
                  ),
                ),
                if (showActionChevron) ...[
                  const SizedBox(width: 1),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 17,
                    color: AppColors.primaryInk(theme.brightness),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
