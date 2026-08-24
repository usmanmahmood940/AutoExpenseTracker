import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/features/search/domain/entities/transaction_sort.dart';
import 'package:nova_spend/l10n/app_strings.dart';

/// Bottom sheet for picking how Activity results are sorted.
class SortBySheet extends StatefulWidget {
  const SortBySheet({this.initial, super.key});

  final TransactionSort? initial;

  static Future<TransactionSort?> show(
    BuildContext context, {
    TransactionSort? initial,
  }) {
    return showModalBottomSheet<TransactionSort>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SortBySheet(initial: initial),
    );
  }

  @override
  State<SortBySheet> createState() => _SortBySheetState();
}

class _SortBySheetState extends State<SortBySheet> {
  late TransactionSort _sort;

  @override
  void initState() {
    super.initState();
    _sort = widget.initial ?? TransactionSort.defaultSort;
  }

  void _select(TransactionSort sort) {
    setState(() => _sort = sort);
  }

  void _apply() {
    Navigator.of(context).pop(_sort);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final sheetBg = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    String labelFor(TransactionSort sort) {
      return switch (sort) {
        TransactionSort.dateNewest => l10n.sortByDateNewest,
        TransactionSort.dateOldest => l10n.sortByDateOldest,
        TransactionSort.amountHighest => l10n.sortByAmountHighest,
        TransactionSort.amountLowest => l10n.sortByAmountLowest,
        TransactionSort.merchantAz => l10n.sortByMerchantAz,
        TransactionSort.merchantZa => l10n.sortByMerchantZa,
      };
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: sheetBg,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: border.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          l10n.sortBySheetTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.02 * 20,
                          ),
                        ),
                      ),
                      Material(
                        color: AppColors.neutralFill(brightness),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).pop(),
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.smPlus2),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final sort in TransactionSort.values)
                            _SortByOption(
                              label: labelFor(sort),
                              selected: _sort == sort,
                              showDefaultBadge:
                                  sort == TransactionSort.defaultSort,
                              onTap: () => _select(sort),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: _apply,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryStrong,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      minimumSize: const Size.fromHeight(52),
                      maximumSize: const Size.fromHeight(52),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: Text(
                      l10n.dateRangeApply,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SortByOption extends StatelessWidget {
  const _SortByOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.showDefaultBadge = false,
  });

  final String label;
  final bool selected;
  final bool showDefaultBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final ink = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final accent = AppColors.primaryStrong;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: selected
            ? AppColors.navActiveFill(brightness)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.smPlus2,
              vertical: AppSpacing.smPlus,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? AppColors.navActiveFill(brightness)
                        : AppColors.neutralFill(
                            brightness,
                          ).withValues(alpha: 0.45),
                    border: Border.all(
                      color: selected
                          ? accent
                          : AppColors.border(brightness).withValues(alpha: 0.7),
                    ),
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/icon_sort.svg',
                    width: 16,
                    height: 16,
                    colorFilter: ColorFilter.mode(
                      selected ? accent : ink,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.smPlus2),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? accent : ink,
                    ),
                  ),
                ),
                if (showDefaultBadge) ...[
                  Text(
                    l10n.sortByDefaultBadge,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? accent : muted,
                    ),
                  ),
                  if (selected) const SizedBox(width: AppSpacing.sm),
                ],
                if (selected)
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryStrong,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
