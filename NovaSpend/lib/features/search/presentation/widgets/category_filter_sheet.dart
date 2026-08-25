import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/category_avatar.dart';
import 'package:nova_spend/core/widgets/sheet_action_footer.dart';
import 'package:nova_spend/features/categories/domain/entities/category_entity.dart';
import 'package:nova_spend/l10n/app_strings.dart';

/// Outcome of [CategoryFilterSheet.show]. `null` means the sheet was dismissed.
class CategoryFilterSheetResult {
  const CategoryFilterSheetResult.applied(this.categories) : cleared = false;
  const CategoryFilterSheetResult.cleared()
    : categories = const [],
      cleared = true;

  final List<String> categories;
  final bool cleared;
}

/// Bottom sheet for picking one or more transaction categories.
class CategoryFilterSheet extends StatefulWidget {
  const CategoryFilterSheet({
    required this.categories,
    this.initialSelected = const [],
    super.key,
  });

  final List<CategoryEntity> categories;
  final List<String> initialSelected;

  static Future<CategoryFilterSheetResult?> show(
    BuildContext context, {
    required List<CategoryEntity> categories,
    List<String> initialSelected = const [],
  }) {
    return showModalBottomSheet<CategoryFilterSheetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CategoryFilterSheet(
        categories: categories,
        initialSelected: initialSelected,
      ),
    );
  }

  @override
  State<CategoryFilterSheet> createState() => _CategoryFilterSheetState();
}

class _CategoryFilterSheetState extends State<CategoryFilterSheet> {
  late final Set<String> _selected;
  late final List<CategoryEntity> _sorted;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initialSelected};
    _sorted = [...widget.categories]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  bool get _allSelected => _selected.isEmpty;

  bool get _canClear => _selected.isNotEmpty;

  void _selectAll() {
    if (_allSelected) return;
    setState(_selected.clear);
  }

  void _toggle(CategoryEntity category) {
    setState(() {
      if (_selected.contains(category.name)) {
        _selected.remove(category.name);
      } else {
        _selected.add(category.name);
        if (_selected.length >= _sorted.length) {
          _selected.clear();
        }
      }
    });
  }

  void _apply() {
    Navigator.of(context).pop(
      _selected.isEmpty
          ? const CategoryFilterSheetResult.cleared()
          : CategoryFilterSheetResult.applied(
              _selected.toList(growable: false),
            ),
    );
  }

  void _clear() {
    setState(_selected.clear);
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
                          l10n.categorySheetTitle,
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
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _sorted.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _AllCategoriesOption(
                            label: l10n.categorySheetAll,
                            selected: _allSelected,
                            onTap: _selectAll,
                          );
                        }
                        final category = _sorted[index - 1];
                        return _CategoryOption(
                          label: category.name,
                          selected: _selected.contains(category.name),
                          leading: CategoryAvatar(
                            category: category.name,
                            colorHex: category.color,
                            size: 40,
                            circular: true,
                          ),
                          onTap: () => _toggle(category),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SheetActionFooter(
                    showClear: _canClear,
                    onClear: _clear,
                    onApply: _apply,
                    clearLabel: l10n.feedClearFilters,
                    applyLabel: l10n.dateRangeApply,
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

class _AllCategoriesOption extends StatelessWidget {
  const _AllCategoriesOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final ink = theme.colorScheme.onSurface;
    final accent = AppColors.primaryStrong;
    final border = AppColors.border(brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.smPlus2,
                AppSpacing.sm,
                AppSpacing.smPlus2,
                AppSpacing.smPlus,
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? accent : Colors.transparent,
                      border: selected
                          ? null
                          : Border.all(color: border.withValues(alpha: 0.85)),
                    ),
                    child: selected
                        ? const SizedBox(
                            width: 8,
                            height: 8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : null,
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
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.smPlus2,
            right: AppSpacing.smPlus2,
            bottom: AppSpacing.sm,
          ),
          child: Divider(
            height: 1,
            thickness: 1,
            color: border.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.label,
    required this.selected,
    required this.leading,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Widget leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final ink = theme.colorScheme.onSurface;
    final accent = AppColors.primaryStrong;
    final border = AppColors.border(brightness);

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
                leading,
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
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? accent : Colors.transparent,
                    border: selected
                        ? null
                        : Border.all(color: border.withValues(alpha: 0.85)),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
