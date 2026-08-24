import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';

/// Fixed spinner sizes so progress indicators match across the app.
enum AppLoaderSize {
  /// Inside buttons, fields and list footers.
  small,

  /// Default for inline panels.
  medium,

  /// Full-screen / page-level waits.
  large,
}

/// The app's only spinner. Always accent-tinted unless [color] overrides it
/// (e.g. white on a filled button).
class AppLoader extends StatelessWidget {
  const AppLoader({this.size = AppLoaderSize.medium, this.color, super.key});

  final AppLoaderSize size;
  final Color? color;

  double get _dimension => switch (size) {
    AppLoaderSize.small => 18,
    AppLoaderSize.medium => 26,
    AppLoaderSize.large => 34,
  };

  double get _strokeWidth => switch (size) {
    AppLoaderSize.small => 2,
    AppLoaderSize.medium => 2.5,
    AppLoaderSize.large => 3,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _dimension,
      height: _dimension,
      child: CircularProgressIndicator(
        strokeWidth: _strokeWidth,
        strokeCap: StrokeCap.round,
        color: color ?? AppColors.primaryStrong,
      ),
    );
  }
}

/// Centered loader for gates and pages that have no content to show yet.
///
/// Screens that render a list or cards should prefer a skeleton instead —
/// see `skeleton.dart`.
class AppPageLoader extends StatelessWidget {
  const AppPageLoader({this.label, super.key});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppLoader(size: AppLoaderSize.large),
          if (label != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              label!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Footer under a paginated list while the next page is being fetched.
class AppListFooterLoader extends StatelessWidget {
  const AppListFooterLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Center(child: AppLoader(size: AppLoaderSize.small)),
    );
  }
}

/// Dims and freezes content that is already on screen while it is being
/// re-queried, so the list does not collapse into a spinner on every keystroke.
class AppBusyContent extends StatelessWidget {
  const AppBusyContent({
    required this.busy,
    required this.child,
    super.key,
  });

  final bool busy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: busy,
      child: AnimatedOpacity(
        opacity: busy ? 0.4 : 1,
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        child: child,
      ),
    );
  }
}

/// Scrim + spinner over a whole screen during a blocking submit.
class AppBlockingLoaderOverlay extends StatelessWidget {
  const AppBlockingLoaderOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.35),
        child: const Center(
          child: AppLoader(size: AppLoaderSize.large, color: Colors.white),
        ),
      ),
    );
  }
}
