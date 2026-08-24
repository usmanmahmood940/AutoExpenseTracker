import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

/// Soft opacity pulse over skeleton bones (the usual placeholder animation).
///
/// Honors reduced-motion: when animations are disabled, children render static.
/// Nesting is safe — an inner pulse defers to the one already animating above
/// it, so composed skeletons never double-fade.
class SkeletonPulse extends StatelessWidget {
  const SkeletonPulse({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context) ||
        _SkeletonPulseScope.isPulsing(context)) {
      return child;
    }

    return _SkeletonPulseScope(child: _Pulse(child: child));
  }
}

class _SkeletonPulseScope extends InheritedWidget {
  const _SkeletonPulseScope({required super.child});

  static bool isPulsing(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_SkeletonPulseScope>() !=
        null;
  }

  @override
  bool updateShouldNotify(_SkeletonPulseScope oldWidget) => false;
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  static const _duration = Duration(milliseconds: 900);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.4, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

/// Rounded bone used inside skeleton layouts.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    this.width,
    this.height,
    this.radius = AppRadius.sm,
    super.key,
  });

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.neutralFill(Theme.of(context).brightness),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Card surface that skeleton bones sit on — mirrors [AppCard] chrome.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card(brightness),
      ),
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.card(brightness),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.cardBorder(brightness)),
        ),
        child: child,
      ),
    );
  }
}

/// Bones for a `SectionHeader` (title + optional trailing action).
class SkeletonSectionHeader extends StatelessWidget {
  const SkeletonSectionHeader({
    this.titleWidth = 160,
    this.actionWidth,
    super.key,
  });

  final double titleWidth;
  final double? actionWidth;

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SkeletonBox(width: titleWidth, height: 16),
          if (actionWidth != null) SkeletonBox(width: actionWidth, height: 12),
        ],
      ),
    );
  }
}

/// Bones for a day group header inside a transaction card.
class SkeletonDayHeader extends StatelessWidget {
  const SkeletonDayHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return ColoredBox(
      color: AppColors.neutralFill(brightness).withValues(alpha: 0.45),
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.smPlus,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SkeletonBox(width: 72, height: 11),
            SkeletonBox(width: 88, height: 11),
          ],
        ),
      ),
    );
  }
}

/// Bones matching one `TransactionListTile`.
class SkeletonTransactionRow extends StatelessWidget {
  const SkeletonTransactionRow({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          SkeletonBox(width: 44, height: 44, radius: AppRadius.sm),
          SizedBox(width: AppSpacing.smPlus),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120, height: 13),
                SizedBox(height: AppSpacing.xs),
                SkeletonBox(width: 72, height: 11),
                SizedBox(height: AppSpacing.xs),
                SkeletonBox(width: 48, height: 10),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          SkeletonBox(width: 64, height: 14),
        ],
      ),
    );
  }
}

/// Day-grouped transaction list placeholder — the standard first-load state
/// for any screen that lists transactions.
class SkeletonTransactionList extends StatelessWidget {
  const SkeletonTransactionList({
    this.groupCount = 2,
    this.rowsPerGroup = 3,
    super.key,
  });

  final int groupCount;
  final int rowsPerGroup;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return SkeletonPulse(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var group = 0; group < groupCount; group++) ...[
            if (group != 0) const SizedBox(height: AppSpacing.md),
            SkeletonCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SkeletonDayHeader(),
                  for (var row = 0; row < rowsPerGroup; row++) ...[
                    const SkeletonTransactionRow(),
                    if (row != rowsPerGroup - 1)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: AppSpacing.md,
                        endIndent: AppSpacing.md,
                        color: AppColors.border(brightness),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Stack of generic text cards — for card lists that aren't transactions.
class SkeletonCardList extends StatelessWidget {
  const SkeletonCardList({this.cardCount = 3, this.linesPerCard = 3, super.key});

  final int cardCount;
  final int linesPerCard;

  static const _lineWidths = [180.0, 120.0, 96.0, 148.0];

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var card = 0; card < cardCount; card++) ...[
            if (card != 0) const SizedBox(height: AppSpacing.sm),
            SkeletonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var line = 0; line < linesPerCard; line++) ...[
                    if (line != 0) const SizedBox(height: AppSpacing.sm),
                    SkeletonBox(
                      width: _lineWidths[line % _lineWidths.length],
                      height: line == 0 ? 14 : 11,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
