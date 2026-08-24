import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_spacing.dart';

/// Centered "nothing here" placeholder — illustration, title, optional hint
/// and optional call to action.
///
/// ```dart
/// EmptyStateView(
///   title: l10n.searchNoResultsTitle,
///   message: l10n.searchNoResultsHint,
/// )
/// ```
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    required this.title,
    this.message,
    this.iconAsset = defaultIconAsset,
    this.illustration,
    this.illustrationSize = 132,
    this.actionLabel,
    this.onActionTap,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.xl,
    ),
    super.key,
  });

  static const String defaultIconAsset = 'assets/icons/icon_empty_state.svg';

  final String title;
  final String? message;

  /// SVG tinted with the muted ink color. Ignored when [illustration] is set.
  final String iconAsset;

  /// Overrides [iconAsset] when a screen needs its own artwork.
  final Widget? illustration;

  final double illustrationSize;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final artColor = cs.onSurface.withValues(alpha: 0.85);

    return Padding(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              illustration ??
                  SvgPicture.asset(
                    iconAsset,
                    width: illustrationSize,
                    colorFilter: ColorFilter.mode(artColor, BlendMode.srcIn),
                  ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
              if (actionLabel != null && onActionTap != null) ...[
                const SizedBox(height: AppSpacing.lg),
                FilledButton.tonal(
                  onPressed: onActionTap,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
