import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/core/currency/app_currency_scope.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/errors/app_error_mapper.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_motion.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/utils/date_labels.dart';
import 'package:nova_spend/core/widgets/app_loader.dart';
import 'package:nova_spend/core/widgets/app_segmented_toggle.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/categories/presentation/widgets/category_catalog_scope.dart';
import 'package:nova_spend/features/transactions/presentation/provider/manual_log_provider.dart';
import 'package:nova_spend/features/transactions/presentation/widgets/transaction_form_fields.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:provider/provider.dart';

class ManualLogResult {
  const ManualLogResult.created() : created = true, viewTransactionId = null;

  const ManualLogResult.viewExisting(this.viewTransactionId) : created = false;

  final bool created;
  final String? viewTransactionId;
}

class ManualLogSheet extends StatefulWidget {
  const ManualLogSheet({super.key});

  static Future<ManualLogResult?> show(BuildContext context) {
    final uid = context.read<AuthProvider>().uid;
    if (uid == null) return Future<ManualLogResult?>.value(null);

    final currency = AppCurrencyScope.of(context).currency;
    return showModalBottomSheet<ManualLogResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ChangeNotifierProvider(
          create: (_) {
            final provider = sl<ManualLogProvider>();
            provider.configure(uid: uid, currency: currency);
            return provider;
          },
          child: const ManualLogSheet(),
        );
      },
    );
  }

  @override
  State<ManualLogSheet> createState() => _ManualLogSheetState();
}

class _ManualLogSheetState extends State<ManualLogSheet> {
  late final TextEditingController _paste;
  late final TextEditingController _merchant;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  String? _clipboardMessage;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ManualLogProvider>();
    _paste = TextEditingController(text: provider.pasteText);
    _merchant = TextEditingController(text: provider.merchant);
    _amount = TextEditingController(text: provider.amountText);
    _note = TextEditingController(text: provider.note);
  }

  @override
  void dispose() {
    _paste.dispose();
    _merchant.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _syncControllers(ManualLogProvider provider) {
    if (_paste.text != provider.pasteText) {
      _paste.value = TextEditingValue(
        text: provider.pasteText,
        selection: TextSelection.collapsed(offset: provider.pasteText.length),
      );
    }
    if (_merchant.text != provider.merchant) {
      _merchant.value = TextEditingValue(
        text: provider.merchant,
        selection: TextSelection.collapsed(offset: provider.merchant.length),
      );
    }
    if (_amount.text != provider.amountText) {
      _amount.value = TextEditingValue(
        text: provider.amountText,
        selection: TextSelection.collapsed(offset: provider.amountText.length),
      );
    }
    if (_note.text != provider.note) {
      _note.value = TextEditingValue(
        text: provider.note,
        selection: TextSelection.collapsed(offset: provider.note.length),
      );
    }
  }

  Future<void> _pasteClipboard() async {
    final l10n = context.l10n;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) {
      setState(() => _clipboardMessage = l10n.manualLogClipboardEmpty);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _clipboardMessage = null);
    context.read<ManualLogProvider>().setPasteText(text);
  }

  Future<void> _pickDate() async {
    final provider = context.read<ManualLogProvider>();
    final parsed =
        DateTime.tryParse(provider.transactionDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    provider.setTransactionDate(DateFormat('yyyy-MM-dd').format(picked));
  }

  Future<void> _pickTime() async {
    final provider = context.read<ManualLogProvider>();
    final initial =
        _parseTimeOfDay(provider.transactionTime) ?? TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;
    provider.setTransactionTime(
      '${picked.hour.toString().padLeft(2, '0')}:'
      '${picked.minute.toString().padLeft(2, '0')}',
    );
  }

  TimeOfDay? _parseTimeOfDay(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final iso = DateTime.tryParse(value);
    if (iso != null) {
      final local = iso.isUtc ? iso.toLocal() : iso;
      return TimeOfDay(hour: local.hour, minute: local.minute);
    }
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _onPrimary() async {
    final provider = context.read<ManualLogProvider>();
    if (provider.mode == ManualLogMode.paste) {
      final ok = await provider.parse();
      if (!mounted) return;
      _showActionError(provider);
      if (ok || provider.bannerMessage != null) {
        HapticFeedback.selectionClick();
      }
      return;
    }

    final saved = await provider.save();
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(const ManualLogResult.created());
      return;
    }
    _showActionError(provider);
  }

  void _showActionError(ManualLogProvider provider) {
    final error = provider.actionError;
    if (error == null) return;
    final message = AppErrorMapper.message(context.l10n, error);
    provider.clearActionError();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _viewExisting(String id) {
    Navigator.of(context).pop(ManualLogResult.viewExisting(id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<ManualLogProvider>();
    _syncControllers(provider);

    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final colorScheme = theme.colorScheme;
    final sheetBg = AppColors.surface(brightness);
    final ink = colorScheme.onSurface;
    final muted = colorScheme.onSurfaceVariant;
    final fieldFill = AppColors.neutralFill(brightness);
    final border = AppColors.border(brightness);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenH = MediaQuery.sizeOf(context).height;
    final keyboardOpen = bottomInset > 0;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion ? Duration.zero : AppMotion.normal;

    final categories =
        CategoryCatalogScope.of(context).map((c) => c.name).toSet().toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.deferToChild,
      child: SizedBox(
        height: (screenH * 0.94).clamp(280.0, screenH),
        child: Material(
          color: sheetBg,
          elevation: 0,
          shadowColor: Colors.black26,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Column(
                children: [
                  _DragHandle(color: border),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                    child: _SheetHeader(
                      title: l10n.manualLogTitle,
                      ink: ink,
                      closeFill: fieldFill,
                      onClose: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: AppSegmentedToggle<ManualLogMode>(
                      value: provider.mode,
                      onChanged: provider.setMode,
                      segments: [
                        AppSegment(
                          value: ManualLogMode.paste,
                          label: l10n.manualLogPaste,
                        ),
                        AppSegment(
                          value: ManualLogMode.form,
                          label: l10n.manualLogForm,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: duration,
                      switchInCurve: AppMotion.standard,
                      switchOutCurve: AppMotion.exit,
                      child: provider.mode == ManualLogMode.paste
                          ? _PasteBody(
                              key: const ValueKey('paste'),
                              controller: _paste,
                              muted: muted,
                              ink: ink,
                              fieldFill: fieldFill,
                              border: border,
                              busy: provider.isParsing,
                              pasteError: provider.pasteError == null
                                  ? null
                                  : l10n.manualLogPasteRequired,
                              clipboardMessage: _clipboardMessage,
                              keyboardInset: bottomInset,
                              onChanged: provider.setPasteText,
                              onPasteClipboard: _pasteClipboard,
                            )
                          : _FormBody(
                              key: const ValueKey('form'),
                              provider: provider,
                              merchant: _merchant,
                              amount: _amount,
                              note: _note,
                              categories: categories,
                              ink: ink,
                              muted: muted,
                              fieldFill: fieldFill,
                              border: border,
                              keyboardInset: bottomInset,
                              onPickDate: _pickDate,
                              onPickTime: _pickTime,
                              onViewExisting:
                                  provider.duplicateTransactionId == null
                                  ? null
                                  : () => _viewExisting(
                                      provider.duplicateTransactionId!,
                                    ),
                            ),
                    ),
                  ),
                  if (!keyboardOpen)
                    _FooterButton(
                      label: provider.mode == ManualLogMode.paste
                          ? (provider.isParsing
                                ? l10n.manualLogReading
                                : l10n.manualLogReadMessage)
                          : l10n.manualLogSave,
                      enabled: provider.mode == ManualLogMode.paste
                          ? provider.canParse
                          : provider.canSave,
                      busy: provider.mode == ManualLogMode.paste
                          ? provider.isParsing
                          : provider.isSaving,
                      onPressed: _onPrimary,
                    ),
                ],
              ),
              if (provider.isSaving) const AppBlockingLoaderOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasteBody extends StatelessWidget {
  const _PasteBody({
    required this.controller,
    required this.muted,
    required this.ink,
    required this.fieldFill,
    required this.border,
    required this.busy,
    required this.onChanged,
    required this.onPasteClipboard,
    this.pasteError,
    this.clipboardMessage,
    this.keyboardInset = 0,
    super.key,
  });

  final TextEditingController controller;
  final Color muted;
  final Color ink;
  final Color fieldFill;
  final Color border;
  final bool busy;
  final String? pasteError;
  final String? clipboardMessage;
  final double keyboardInset;
  final ValueChanged<String> onChanged;
  final VoidCallback onPasteClipboard;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 16 + keyboardInset),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        AppBusyContent(
          busy: busy,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TransactionFilledTextField(
                controller: controller,
                fill: fieldFill,
                ink: ink,
                border: border,
                minLines: 6,
                maxLines: 10,
                hintText: l10n.manualLogPasteHint,
                onChanged: onChanged,
              ),
              if (pasteError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  pasteError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  onPressed: onPasteClipboard,
                  avatar: SvgPicture.asset(
                    'assets/icons/icon_clipboard.svg',
                    width: 16,
                    height: 16,
                    colorFilter: ColorFilter.mode(
                      AppColors.primaryInk(Theme.of(context).brightness),
                      BlendMode.srcIn,
                    ),
                  ),
                  label: Text(l10n.manualLogClipboard),
                  backgroundColor: fieldFill,
                  side: BorderSide(color: border),
                ),
              ),
              if (clipboardMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  clipboardMessage!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.manualLogPasteExample,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.provider,
    required this.merchant,
    required this.amount,
    required this.note,
    required this.categories,
    required this.ink,
    required this.muted,
    required this.fieldFill,
    required this.border,
    required this.onPickDate,
    required this.onPickTime,
    this.onViewExisting,
    this.keyboardInset = 0,
    super.key,
  });

  final ManualLogProvider provider;
  final TextEditingController merchant;
  final TextEditingController amount;
  final TextEditingController note;
  final List<String> categories;
  final Color ink;
  final Color muted;
  final Color fieldFill;
  final Color border;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final VoidCallback? onViewExisting;
  final double keyboardInset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brightness = Theme.of(context).brightness;
    final error = Theme.of(context).colorScheme.error;

    return ListView(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 16 + keyboardInset),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (provider.bannerMessage != null) ...[
          _InlineBanner(
            message: provider.bannerIsDuplicate
                ? l10n.manualLogDuplicate
                : l10n.manualLogParseFailed,
            actionLabel: provider.bannerIsDuplicate
                ? l10n.manualLogViewExisting
                : null,
            onAction: onViewExisting,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (provider.parseConfidence != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: provider.hasLowConfidence
                    ? AppColors.warningBackground(brightness)
                    : AppColors.navActiveFill(brightness),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                provider.hasLowConfidence
                    ? l10n.manualLogLowConfidence
                    : l10n.manualLogConfidence(
                        ((provider.parseConfidence ?? 0) * 100)
                            .round()
                            .toString(),
                      ),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: provider.hasLowConfidence
                      ? AppColors.warningForeground(brightness)
                      : AppColors.primaryInk(brightness),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        TransactionAmountField(
          label: l10n.transactionAmountLabel,
          controller: amount,
          currency: AppCurrencyScope.of(context).currency,
          muted: muted,
          fieldFill: fieldFill,
          border: border,
          hintText: l10n.manualLogAmountHint,
          onChanged: provider.setAmountText,
        ),
        if (provider.amountError != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.manualLogAmountRequired,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: error),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        TransactionFormLabeledField(
          label: l10n.transactionMerchant,
          muted: muted,
          child: TransactionFilledTextField(
            controller: merchant,
            fill: fieldFill,
            ink: ink,
            border: border,
            textStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: ink,
            ),
            onChanged: provider.setMerchant,
          ),
        ),
        if (provider.merchantError != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.manualLogMerchantRequired,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: error),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        TransactionFormLabeledField(
          label: l10n.transactionCategory,
          muted: muted,
          child: TransactionCategoryDropdown(
            categories: categories,
            value: provider.category,
            fill: fieldFill,
            ink: ink,
            muted: muted,
            border: border,
            hintText: l10n.manualLogCategoryRequired,
            onChanged: provider.setCategory,
          ),
        ),
        if (provider.categoryError != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.manualLogCategoryRequired,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: error),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        TransactionFormLabeledField(
          label: l10n.transactionType,
          muted: muted,
          child: TransactionTypeSegmentedControl(
            value: provider.type,
            fill: fieldFill,
            muted: muted,
            border: border,
            debitLabel: l10n.feedFilterTypeDebit,
            creditLabel: l10n.feedFilterTypeCredit,
            onChanged: provider.setType,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TransactionFormLabeledField(
          label: l10n.transactionDate,
          muted: muted,
          child: TransactionPickerField(
            value: _formatDateDisplay(provider.transactionDate),
            fill: fieldFill,
            ink: ink,
            muted: muted,
            border: border,
            icon: Icons.calendar_today_outlined,
            onTap: onPickDate,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TransactionFormLabeledField(
          label: l10n.labelOptional(l10n.transactionPaymentMethod),
          muted: muted,
          child: TransactionPaymentMethodDropdown(
            value: provider.paymentMethod,
            fill: fieldFill,
            ink: ink,
            muted: muted,
            border: border,
            onChanged: provider.setPaymentMethod,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TransactionFormLabeledField(
          label: l10n.labelOptional(l10n.transactionTime),
          muted: muted,
          child: TransactionPickerField(
            value: formatClockTime(provider.transactionTime).isEmpty
                ? provider.transactionTime
                : formatClockTime(provider.transactionTime),
            fill: fieldFill,
            ink: ink,
            muted: muted,
            border: border,
            icon: Icons.schedule_outlined,
            onTap: onPickTime,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TransactionFormLabeledField(
          label: l10n.labelOptional(l10n.manualLogNote),
          muted: muted,
          child: TransactionFilledTextField(
            controller: note,
            fill: fieldFill,
            ink: ink,
            border: border,
            minLines: 2,
            maxLines: 4,
            onChanged: provider.setNote,
          ),
        ),
      ],
    );
  }

  String _formatDateDisplay(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat.yMMMd().format(parsed);
  }
}

class _InlineBanner extends StatelessWidget {
  const _InlineBanner({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final cs = theme.colorScheme;

    return Material(
      color: AppColors.neutralFill(brightness),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 20, color: cs.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.label,
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: FilledButton(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryStrong,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.primaryStrong.withValues(
              alpha: 0.5,
            ),
            minimumSize: const Size.fromHeight(52),
            maximumSize: const Size.fromHeight(52),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          child: busy
              ? const AppLoader(size: AppLoaderSize.small, color: Colors.white)
              : Text(label),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.ink,
    required this.closeFill,
    required this.onClose,
  });

  final String title;
  final Color ink;
  final Color closeFill;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.33,
              letterSpacing: -0.18,
              color: ink,
            ),
          ),
        ),
        Material(
          color: closeFill,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onClose,
            child: SizedBox(
              width: 30,
              height: 30,
              child: Icon(Icons.close_rounded, size: 18, color: ink),
            ),
          ),
        ),
      ],
    );
  }
}
