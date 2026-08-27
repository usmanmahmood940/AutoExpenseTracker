import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nova_spend/core/currency/app_currency_scope.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_motion.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/sheet_action_footer.dart';
import 'package:nova_spend/features/search/domain/entities/ingestion_source.dart';
import 'package:nova_spend/features/search/domain/entities/search_query.dart';
import 'package:nova_spend/features/search/presentation/provider/search_provider.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:provider/provider.dart';

/// Outcome of [FilterSheet.show]. `null` means the sheet was dismissed.
class FilterSheetResult {
  const FilterSheetResult.applied(this.value) : cleared = false;
  const FilterSheetResult.cleared()
    : value = const FilterSheetValue(),
      cleared = true;

  final FilterSheetValue value;
  final bool cleared;
}

class FilterSheetValue {
  const FilterSheetValue({
    this.amountMin,
    this.amountMax,
    this.type,
    this.paymentMethods = const [],
    this.sources = const [],
  });

  factory FilterSheetValue.fromQuery(SearchQuery query) {
    return FilterSheetValue(
      amountMin: query.amountMin,
      amountMax: query.amountMax,
      type: query.typeFilter,
      paymentMethods: query.paymentMethods,
      sources: query.sources,
    );
  }

  final double? amountMin;
  final double? amountMax;
  final String? type;
  final List<String> paymentMethods;
  final List<String> sources;

  bool get isEmpty =>
      amountMin == null &&
      amountMax == null &&
      type == null &&
      paymentMethods.isEmpty &&
      sources.isEmpty;
}

/// Bottom sheet for amount, type, payment method, and source filters.
class FilterSheet extends StatefulWidget {
  const FilterSheet({required this.paymentMethods, this.initial, super.key});

  final FilterSheetValue? initial;
  final List<String> paymentMethods;

  static Future<FilterSheetResult?> show(
    BuildContext context, {
    FilterSheetValue? initial,
  }) {
    final search = context.read<SearchProvider>();
    unawaited(search.ensurePaymentMethods());
    return showModalBottomSheet<FilterSheetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider<SearchProvider>.value(
        value: search,
        child: Consumer<SearchProvider>(
          builder: (_, provider, _) => FilterSheet(
            initial: initial,
            paymentMethods: provider.paymentMethods,
          ),
        ),
      ),
    );
  }

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late final TextEditingController _min;
  late final TextEditingController _max;
  late final Set<String> _paymentMethods;
  late final Set<String> _sources;
  String? _type;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _min = TextEditingController(text: _formatAmount(initial?.amountMin));
    _max = TextEditingController(text: _formatAmount(initial?.amountMax));
    _min.addListener(_onAmountChanged);
    _max.addListener(_onAmountChanged);
    _type = initial?.type;
    _paymentMethods = {...?initial?.paymentMethods};
    _sources = {...?initial?.sources};
  }

  @override
  void dispose() {
    _min
      ..removeListener(_onAmountChanged)
      ..dispose();
    _max
      ..removeListener(_onAmountChanged)
      ..dispose();
    super.dispose();
  }

  void _onAmountChanged() => setState(() {});

  bool get _isDefault {
    return _parseAmount(_min.text) == null &&
        _parseAmount(_max.text) == null &&
        _type == null &&
        _paymentMethods.isEmpty &&
        _sources.isEmpty;
  }

  bool get _hasInitialFilter =>
      widget.initial != null && !widget.initial!.isEmpty;

  bool get _canClear => !_isDefault;

  bool get _amountValid {
    final min = _parseAmount(_min.text);
    final max = _parseAmount(_max.text);
    if (min != null && max != null && min > max) return false;
    return true;
  }

  void _selectType(String? type) {
    HapticFeedback.selectionClick();
    setState(() => _type = _type == type ? null : type);
  }

  void _togglePaymentMethod(String method) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_paymentMethods.remove(method)) _paymentMethods.add(method);
      if (_paymentMethods.length >= widget.paymentMethods.length) {
        _paymentMethods.clear();
      }
    });
  }

  void _toggleSource(String source) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_sources.remove(source)) _sources.add(source);
      if (_sources.length >= kIngestionSources.length) _sources.clear();
    });
  }

  void _clearPaymentMethods() {
    if (_paymentMethods.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(_paymentMethods.clear);
  }

  void _clearSources() {
    if (_sources.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(_sources.clear);
  }

  bool get _canApply {
    if (!_amountValid) return false;
    if (_isDefault) return _hasInitialFilter;
    return true;
  }

  void _apply() {
    if (!_canApply) return;
    final value = FilterSheetValue(
      amountMin: _parseAmount(_min.text),
      amountMax: _parseAmount(_max.text),
      type: _type,
      paymentMethods: _paymentMethods.toList(growable: false),
      sources: _sources.toList(growable: false),
    );
    Navigator.of(context).pop(
      value.isEmpty
          ? const FilterSheetResult.cleared()
          : FilterSheetResult.applied(value),
    );
  }

  void _clear() {
    _min.clear();
    _max.clear();
    setState(() {
      _type = null;
      _paymentMethods.clear();
      _sources.clear();
    });
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
    final currency = AppCurrencyScope.of(context).currency;

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
                          l10n.feedFilters,
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
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _FilterSection(
                            label: l10n.filterSheetAmountRange,
                            child: _AmountRange(
                              min: _min,
                              max: _max,
                              currency: currency,
                              invalid: !_amountValid,
                              errorText: l10n.filterSheetAmountInvalid,
                            ),
                          ),
                          _FilterSection(
                            label: l10n.feedFilterType,
                            child: Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                _FilterChip(
                                  label: l10n.feedFilterTypeAll,
                                  selected: _type == null,
                                  onTap: () => _selectType(null),
                                ),
                                _FilterChip(
                                  label: l10n.feedFilterTypeDebit,
                                  selected: _type == 'debit',
                                  icon: Icons.arrow_outward_rounded,
                                  onTap: () => _selectType('debit'),
                                ),
                                _FilterChip(
                                  label: l10n.feedFilterTypeCredit,
                                  selected: _type == 'credit',
                                  icon: Icons.south_west_rounded,
                                  onTap: () => _selectType('credit'),
                                ),
                              ],
                            ),
                          ),
                          _FilterSection(
                            label: l10n.transactionPaymentMethod,
                            selectedCount: _paymentMethods.length,
                            child: Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                _FilterChip(
                                  label: l10n.commonAll,
                                  selected: _paymentMethods.isEmpty,
                                  onTap: _clearPaymentMethods,
                                ),
                                for (final method in widget.paymentMethods)
                                  _FilterChip(
                                    label: paymentMethodLabel(l10n, method),
                                    selected: _paymentMethods.contains(method),
                                    onTap: () => _togglePaymentMethod(method),
                                  ),
                              ],
                            ),
                          ),
                          _FilterSection(
                            label: l10n.transactionSource,
                            selectedCount: _sources.length,
                            isLast: true,
                            child: Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                _FilterChip(
                                  label: l10n.commonAll,
                                  selected: _sources.isEmpty,
                                  onTap: _clearSources,
                                ),
                                for (final source in kIngestionSources)
                                  _FilterChip(
                                    label: ingestionSourceLabel(l10n, source),
                                    selected: _sources.contains(source),
                                    icon: _sourceIcon(source),
                                    onTap: () => _toggleSource(source),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SheetActionFooter(
                    showClear: _canClear,
                    onClear: _clear,
                    onApply: _apply,
                    applyEnabled: _canApply,
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

/// Section label (with an optional selected count) above a group of controls.
class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.label,
    required this.child,
    this.selectedCount = 0,
    this.isLast = false,
  });

  final String label;
  final Widget child;
  final int selectedCount;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.02 * 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (selectedCount > 0)
                Text(
                  l10n.filterSheetSelectedCount(selectedCount),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryStrong,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.smPlus),
          child,
        ],
      ),
    );
  }
}

/// Min / max amount inputs with an inline range error.
class _AmountRange extends StatelessWidget {
  const _AmountRange({
    required this.min,
    required this.max,
    required this.currency,
    required this.invalid,
    required this.errorText,
  });

  final TextEditingController min;
  final TextEditingController max;
  final String currency;
  final bool invalid;
  final String errorText;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _AmountField(
                label: l10n.filterSheetAmountMin,
                currency: currency,
                controller: min,
                invalid: invalid,
                isLast: false,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Container(
                width: 10,
                height: 1.5,
                decoration: BoxDecoration(
                  color: AppColors.border(
                    theme.brightness,
                  ).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            Expanded(
              child: _AmountField(
                label: l10n.filterSheetAmountMax,
                currency: currency,
                controller: max,
                invalid: invalid,
                isLast: true,
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : AppMotion.fast,
          curve: AppMotion.standard,
          alignment: Alignment.topLeft,
          child: invalid
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 14,
                        color: AppColors.warningForeground(theme.brightness),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          errorText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.warningForeground(
                              theme.brightness,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.label,
    required this.currency,
    required this.controller,
    required this.invalid,
    required this.isLast,
  });

  final String label;
  final String currency;
  final TextEditingController controller;
  final bool invalid;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final accent = AppColors.primaryStrong;
    final border = AppColors.border(brightness);
    final warning = AppColors.warningForeground(brightness);

    OutlineInputBorder outline(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      style: theme.textTheme.bodyMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        labelStyle: theme.textTheme.labelSmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: l10n.filterSheetAmountAny,
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        prefixText: '$currency  ',
        prefixStyle: theme.textTheme.bodySmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        filled: true,
        fillColor: AppColors.neutralFill(brightness).withValues(alpha: 0.45),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.smPlus2,
          vertical: AppSpacing.smPlus2,
        ),
        border: outline(border.withValues(alpha: 0.7)),
        enabledBorder: outline(
          invalid ? warning : border.withValues(alpha: 0.7),
        ),
        focusedBorder: outline(invalid ? warning : accent, width: 1.5),
      ),
    );
  }
}

/// Pill chip used for single- and multi-select filter values.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final ink = theme.colorScheme.onSurface;
    final accent = AppColors.primaryStrong;
    final border = AppColors.border(brightness);

    return Material(
      color: selected
          ? AppColors.navActiveFill(brightness)
          : AppColors.neutralFill(brightness).withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? accent : border.withValues(alpha: 0.7),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.smPlus2,
              vertical: AppSpacing.smPlus,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: selected ? accent : ink),
                  const SizedBox(width: AppSpacing.xsMax),
                ],
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? accent : ink,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _sourceIcon(String source) {
  return switch (source) {
    'ios_shortcut' => Icons.phone_iphone_rounded,
    'gmail' => Icons.mail_outline_rounded,
    _ => Icons.edit_outlined,
  };
}

String _formatAmount(double? value) {
  if (value == null) return '';
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

double? _parseAmount(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  return double.tryParse(text);
}
