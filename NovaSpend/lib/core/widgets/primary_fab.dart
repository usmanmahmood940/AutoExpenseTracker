import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Primary circular action button — emerald fill, circular Material elevation.
///
/// Used on Home for adding a transaction; reusable anywhere a single primary
/// floating action is needed.
class PrimaryFab extends StatelessWidget {
  const PrimaryFab({
    required this.onPressed,
    this.tooltip,
    super.key,
  });

  final VoidCallback? onPressed;
  final String? tooltip;

  /// Diameter — matches Figma (56px).
  static const double size = 56;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppColors.primaryStrong,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: size,
          height: size,
          child: Icon(
            Icons.add,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(
      message: tooltip!,
      child: button,
    );
  }
}
