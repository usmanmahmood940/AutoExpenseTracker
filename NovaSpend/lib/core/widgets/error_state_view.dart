import 'package:flutter/material.dart';
import 'package:nova_spend/core/errors/app_error_mapper.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/empty_state_view.dart';
import 'package:nova_spend/l10n/app_strings.dart';

/// Full-page load failure with a retry action.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    this.error,
    this.onRetry,
    super.key,
  });

  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return EmptyStateView(
      title: AppErrorMapper.isNetwork(error)
          ? l10n.errorNetwork
          : l10n.errorLoadFailed,
      message: l10n.errorLoadFailedHint,
      actionLabel: onRetry != null ? l10n.errorRetry : null,
      onActionTap: onRetry,
    );
  }
}

/// Inline banner when a refresh or pagination request fails but data remains.
class LoadErrorBanner extends StatelessWidget {
  const LoadErrorBanner({
    this.error,
    this.onRetry,
    super.key,
  });

  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final cs = theme.colorScheme;
    final title = AppErrorMapper.isNetwork(error)
        ? l10n.errorNetwork
        : l10n.errorLoadFailed;

    return Material(
      color: AppColors.neutralFill(brightness),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 20, color: cs.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(l10n.errorRetry),
              ),
          ],
        ),
      ),
    );
  }
}
