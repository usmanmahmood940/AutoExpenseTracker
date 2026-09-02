import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_motion.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/utils/category_visuals.dart';
import 'package:nova_spend/core/widgets/app_card.dart';
import 'package:nova_spend/core/widgets/category_avatar.dart';
import 'package:nova_spend/core/widgets/category_color_scope.dart';
import 'package:nova_spend/features/analytics/domain/insights_math.dart';
import 'package:nova_spend/features/categories/domain/entities/category_entity.dart';
import 'package:nova_spend/features/categories/presentation/widgets/category_catalog_scope.dart';

class InsightsCategoryBars extends StatelessWidget {
  const InsightsCategoryBars({
    required this.byCategory,
    required this.totalSpent,
    required this.formatMoney,
    required this.otherLabel,
    this.onCategoryTap,
    this.onOtherTap,
    super.key,
  });

  final Map<String, double> byCategory;
  final double totalSpent;
  final String Function(double amount) formatMoney;
  final String otherLabel;
  final void Function(String categoryKey, String displayName)? onCategoryTap;
  final VoidCallback? onOtherTap;

  @override
  Widget build(BuildContext context) {
    final top = topEntries(byCategory);
    final other = otherCategorySpend(byCategory, totalSpent);
    if (top.isEmpty) {
      return const SizedBox.shrink();
    }

    final catalog = CategoryCatalogScope.of(context);

    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < top.length; i++) ...[
            if (i != 0) const SizedBox(height: AppSpacing.smPlus2),
            _CategoryBarRow(
              categoryKey: top[i].key,
              displayName: categoryDisplayName(catalog, top[i].key),
              amountLabel: formatMoney(top[i].value),
              amount: top[i].value,
              totalSpent: totalSpent,
              animationIndex: i,
              onTap: onCategoryTap,
            ),
          ],
          if (other != null) ...[
            const SizedBox(height: AppSpacing.smPlus2),
            _OtherCategoryRow(
              label: otherLabel,
              amountLabel: formatMoney(other.amount),
              share: other.share,
              animationIndex: top.length,
              onTap: onOtherTap,
            ),
          ],
        ],
      ),
    );
  }
}

String categoryDisplayName(List<CategoryEntity> catalog, String key) {
  for (final category in catalog) {
    if (category.id == key ||
        category.name.toLowerCase() == key.toLowerCase()) {
      return category.name;
    }
  }
  return key;
}

class _CategoryBarRow extends StatelessWidget {
  const _CategoryBarRow({
    required this.categoryKey,
    required this.displayName,
    required this.amountLabel,
    required this.amount,
    required this.totalSpent,
    required this.animationIndex,
    required this.onTap,
  });

  final String categoryKey;
  final String displayName;
  final String amountLabel;
  final double amount;
  final double totalSpent;
  final int animationIndex;
  final void Function(String categoryKey, String displayName)? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final share = shareOfTotal(amount, totalSpent);
    final storedHex =
        CategoryColorScope.maybeOf(context)?.hexFor(categoryKey);
    final color = categoryColor(categoryKey, storedHex: storedHex);
    final percent = (share * 100).round();
    final semanticsLabel =
        '$displayName, $percent percent of spend, $amountLabel';

    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(categoryKey, displayName),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Row(
          children: [
            CategoryAvatar(category: categoryKey, size: 36),
            const SizedBox(width: AppSpacing.smPlus2),
            Expanded(
              child: _AnimatedCategoryShare(
                share: share,
                animationIndex: animationIndex,
                percentStyle: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
                barColor: color,
                barBackgroundColor:
                    theme.colorScheme.onSurface.withValues(alpha: 0.08),
                displayName: displayName,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: Text(
                amountLabel,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtherCategoryRow extends StatelessWidget {
  const _OtherCategoryRow({
    required this.label,
    required this.amountLabel,
    required this.share,
    required this.animationIndex,
    required this.onTap,
  });

  final String label;
  final String amountLabel;
  final double share;
  final int animationIndex;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (share * 100).round();
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return Semantics(
      label: '$label, $percent percent of spend, $amountLabel',
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              child: Icon(Icons.more_horiz, size: 18, color: muted),
            ),
            const SizedBox(width: AppSpacing.smPlus2),
            Expanded(
              child: _AnimatedCategoryShare(
                share: share,
                animationIndex: animationIndex,
                percentStyle: theme.textTheme.bodySmall?.copyWith(color: muted),
                barColor: muted,
                barBackgroundColor:
                    theme.colorScheme.onSurface.withValues(alpha: 0.08),
                displayName: label,
                displayNameStyle:
                    theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: Text(
                amountLabel,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedCategoryShare extends StatefulWidget {
  const _AnimatedCategoryShare({
    required this.share,
    required this.animationIndex,
    required this.percentStyle,
    required this.barColor,
    required this.barBackgroundColor,
    required this.displayName,
    this.displayNameStyle,
  });

  final double share;
  final int animationIndex;
  final TextStyle? percentStyle;
  final Color barColor;
  final Color barBackgroundColor;
  final String displayName;
  final TextStyle? displayNameStyle;

  @override
  State<_AnimatedCategoryShare> createState() => _AnimatedCategoryShareState();
}

class _AnimatedCategoryShareState extends State<_AnimatedCategoryShare>
    with SingleTickerProviderStateMixin {
  static const _staggerStep = Duration(milliseconds: 60);

  late final AnimationController _controller;
  late Animation<double> _animation;
  bool _scheduledInitial = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.standard,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduledInitial) return;
    _scheduledInitial = true;
    _scheduleAnimation();
  }

  @override
  void didUpdateWidget(covariant _AnimatedCategoryShare oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.share != widget.share ||
        oldWidget.animationIndex != widget.animationIndex) {
      _controller.reset();
      _scheduleAnimation();
    }
  }

  void _scheduleAnimation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
        return;
      }
      final delay = _staggerStep * widget.animationIndex;
      Future<void>.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clampedShare = widget.share.clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final progress = clampedShare * _animation.value;
        final percent = (clampedShare * 100 * _animation.value).round();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: widget.displayNameStyle ?? theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('$percent%', style: widget.percentStyle),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: widget.barBackgroundColor,
                color: widget.barColor,
              ),
            ),
          ],
        );
      },
    );
  }
}
