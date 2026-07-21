import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Primary circular action button — emerald fill, soft shadow, white plus icon.
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
    final fab = Material(
      elevation: 0,
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.primaryStrong,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 15,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );

    if (tooltip == null) return fab;
    return Tooltip(
      message: tooltip!,
      child: fab,
    );
  }
}
