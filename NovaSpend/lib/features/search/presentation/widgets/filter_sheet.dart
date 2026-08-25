import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nova_spend/core/currency/app_currency_scope.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/sheet_action_footer.dart';
import 'package:nova_spend/features/search/domain/entities/ingestion_source.dart';
import 'package:nova_spend/features/search/domain/entities/search_query.dart';
import 'package:nova_spend/l10n/app_strings.dart';

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
    required List<String> paymentMethods,
    FilterSheetValue? initial,
  }) {
    return showModalBottomSheet<FilterSheetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          FilterSheet(initial: initial, paymentMethods: paymentMethods),
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

  void _selectType(String type) {
    setState(() => _type = _type == type ? null : type);
  }

  void _togglePaymentMethod(String method) {
    setState(() {
      if (_paymentMethods.contains(method)) {
        _paymentMethods.remove(method);
      } else {
        _paymentMethods.add(method);
        if (_paymentMethods.length >= widget.paymentMethods.length) {
          _paymentMethods.clear();
        }
      }
    });
  }

  void _toggleSource(String source) {
    setState(() {
      if (_sources.contains(source)) {
        _sources.remove(source);
      } else {
        _sources.add(source);
        if (_sources.length >= kIngestionSources.length) {
          _sources.clear();
        }
      }
    });
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SectionLabel(label: l10n.filterSheetAmountRange),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _AmountField(
                                  label: l10n.dateRangeStartLabel,
                                  hint: l10n.feedFilterAmountMin,
                                  currency: currency,
                                  controller: _min,
                                  invalid: !_amountValid,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.sm,
                                  28,
                                  AppSpacing.sm,
                                  0,
                                ),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Expanded(
                                child: _AmountField(
                                  label: l10n.dateRangeEndLabel,
                                  hint: l10n.feedFilterAmountMax,
                                  currency: currency,
                                  controller: _max,
                                  invalid: !_amountValid,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _SectionLabel(label: l10n.feedFilterType),
                          const SizedBox(height: AppSpacing.sm),
                          _FilterOption(
                            label: l10n.feedFilterTypeDebit,
                            selected: _type == 'debit',
                            leading: Icons.arrow_downward_rounded,
                            onTap: () => _selectType('debit'),
                          ),
                          _FilterOption(
                            label: l10n.feedFilterTypeCredit,
                            selected: _type == 'credit',
                            leading: Icons.arrow_upward_rounded,
                            onTap: () => _selectType('credit'),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _SectionLabel(label: l10n.transactionPaymentMethod),
                          const SizedBox(height: AppSpacing.sm),
                          for (final method in widget.paymentMethods)
                            _FilterOption(
                              label: paymentMethodLabel(l10n, method),
                              selected: _paymentMethods.contains(method),
                              asset: 'assets/icons/icon_payment_method.svg',
                              multiSelect: true,
                              onTap: () => _togglePaymentMethod(method),
                            ),
                          const SizedBox(height: AppSpacing.md),
                          _SectionLabel(label: l10n.transactionSource),
                          const SizedBox(height: AppSpacing.sm),
                          for (final source in kIngestionSources)
                            _FilterOption(
                              label: ingestionSourceLabel(l10n, source),
                              selected: _sources.contains(source),
                              leading: _sourceIcon(source),
                              multiSelect: true,
                              onTap: () => _toggleSource(source),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.titleSmall?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.02 * 13,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.label,
    required this.hint,
    required this.currency,
    required this.controller,
    required this.invalid,
  });

  final String label;
  final String hint;
  final String currency;
  final TextEditingController controller;
  final bool invalid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final accent = AppColors.primaryStrong;
    final border = AppColors.border(brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
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
            fillColor: AppColors.neutralFill(
              brightness,
            ).withValues(alpha: 0.45),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.smPlus2,
              vertical: AppSpacing.smPlus,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: border.withValues(alpha: 0.7)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(
                color: invalid
                    ? AppColors.warningForeground(brightness)
                    : border.withValues(alpha: 0.7),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(
                color: invalid
                    ? AppColors.warningForeground(brightness)
                    : accent,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterOption extends StatelessWidget {
  const _FilterOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    this.asset,
    this.multiSelect = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? leading;
  final String? asset;
  final bool multiSelect;

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
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? AppColors.navActiveFill(brightness)
                        : AppColors.neutralFill(
                            brightness,
                          ).withValues(alpha: 0.45),
                    border: Border.all(
                      color: selected ? accent : border.withValues(alpha: 0.7),
                    ),
                  ),
                  child: asset != null
                      ? SvgPicture.asset(
                          asset!,
                          width: 18,
                          height: 18,
                          colorFilter: ColorFilter.mode(
                            selected ? accent : ink,
                            BlendMode.srcIn,
                          ),
                        )
                      : Icon(leading, size: 18, color: selected ? accent : ink),
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
                if (multiSelect || selected)
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
