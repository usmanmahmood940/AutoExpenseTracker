import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Pinned sheet footer: optional Clear + primary Apply.
///
/// When [showClear] flips, Clear fades/clips in or out and Apply smoothly
/// grows or shrinks to fill the remaining width.
class SheetActionFooter extends StatefulWidget {
  const SheetActionFooter({
    required this.showClear,
    required this.onClear,
    required this.onApply,
    required this.clearLabel,
    required this.applyLabel,
    this.applyEnabled = true,
    super.key,
  });

  final bool showClear;
  final VoidCallback onClear;
  final VoidCallback onApply;
  final String clearLabel;
  final String applyLabel;
  final bool applyEnabled;

  @override
  State<SheetActionFooter> createState() => _SheetActionFooterState();
}

class _SheetActionFooterState extends State<SheetActionFooter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.fast,
      value: widget.showClear ? 1 : 0,
    );
    _t = CurvedAnimation(parent: _controller, curve: AppMotion.standard);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disable = MediaQuery.disableAnimationsOf(context);
    _controller.duration = disable ? Duration.zero : AppMotion.fast;
  }

  @override
  void didUpdateWidget(SheetActionFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showClear == oldWidget.showClear) return;
    if (widget.showClear) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final applyEnabled = widget.applyEnabled;

    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) {
        final t = _t.value;
        return Row(
          children: [
            ClipRect(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: t,
                child: Opacity(
                  opacity: t,
                  child: IgnorePointer(
                    ignoring: t == 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: widget.onClear,
                          style: TextButton.styleFrom(
                            foregroundColor:
                                theme.colorScheme.onSurfaceVariant,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.smPlus2,
                            ),
                          ),
                          child: Text(
                            widget.clearLabel,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: child!),
          ],
        );
      },
      child: FilledButton(
        onPressed: applyEnabled ? widget.onApply : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryStrong,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.neutralFill(brightness),
          disabledForegroundColor: theme.colorScheme.onSurface.withValues(
            alpha: 0.4,
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          minimumSize: const Size.fromHeight(52),
          maximumSize: const Size.fromHeight(52),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: Text(
          widget.applyLabel,
          style: theme.textTheme.titleMedium?.copyWith(
            color: applyEnabled
                ? Colors.white
                : theme.colorScheme.onSurface.withValues(alpha: 0.4),
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
