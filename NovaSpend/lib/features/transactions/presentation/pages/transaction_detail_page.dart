import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/core/currency/app_currency_scope.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/utils/category_visuals.dart';
import 'package:nova_spend/core/utils/date_labels.dart';
import 'package:nova_spend/core/widgets/category_avatar.dart';
import 'package:nova_spend/core/widgets/category_color_scope.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/categories/domain/repositories/category_repository.dart';
import 'package:nova_spend/features/merchants/presentation/pages/merchant_page.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:nova_spend/features/transactions/domain/usecases/update_transaction.dart';
import 'package:nova_spend/features/transactions/presentation/provider/transaction_detail_provider.dart';
import 'package:nova_spend/features/transactions/presentation/widgets/edit_transaction_sheet.dart';
import 'package:nova_spend/l10n/app_localizations.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:provider/provider.dart';

class TransactionDetailPage extends StatelessWidget {
  const TransactionDetailPage({required this.transaction, super.key});

  final TransactionEntity transaction;

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.transactionDetail)),
        body: Center(child: Text(context.l10n.errorGeneric)),
      );
    }

    return ChangeNotifierProvider(
      create: (_) {
        final provider = TransactionDetailProvider(
          uid: uid,
          transaction: transaction,
          updateTransaction: sl<UpdateTransaction>(),
          repository: sl<TransactionRepository>(),
        );
        provider.loadMerchantRememberState();
        return provider;
      },
      child: const _DetailView(),
    );
  }
}

class _DetailView extends StatefulWidget {
  const _DetailView();

  @override
  State<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<_DetailView> {
  List<String> _categories = const [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final repo = sl<CategoryRepository>();
    final uid = context.read<AuthProvider>().uid;
    final defaults = await repo.watchDefaults().first;
    if (!mounted) return;
    final custom = uid == null
        ? <dynamic>[]
        : await repo.watchUserCategories(uid).first;
    if (!mounted) return;
    final names = <String>{
      ...defaults.map((c) => c.name),
      ...custom.map((c) => c.name),
    }.toList()..sort();
    setState(() => _categories = names);
  }

  Future<void> _openEditSheet() async {
    final l10n = context.l10n;
    final saved = await EditTransactionSheet.show(
      context,
      categories: _categories,
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.transactionSaved)));
  }

  Future<void> _confirmDelete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.transactionDeleteConfirmTitle),
        content: Text(l10n.transactionDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.spend),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await context
        .read<TransactionDetailProvider>()
        .deleteTransaction();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.transactionDeleted)));
      Navigator.of(context).maybePop();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
    }
  }

  void _openMerchant(TransactionEntity tx) {
    if (tx.merchant.trim().isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MerchantPage(
          merchantNormalized: tx.resolvedMerchantKey,
          displayName: tx.merchant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;
    final pageBg = AppColors.surface(brightness);
    final provider = context.watch<TransactionDetailProvider>();
    final overlay = isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: pageBg,
        appBar: AppBar(
          backgroundColor: pageBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: Text(
            l10n.transactionDetail,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            IconButton(
              tooltip: l10n.commonDelete,
              onPressed: provider.isSaving ? null : _confirmDelete,
              icon: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        body: _buildBody(provider),
      ),
    );
  }

  Widget _buildBody(TransactionDetailProvider provider) {
    final theme = Theme.of(context);
    final tx = provider.transaction;
    final ink = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: [
        // 1 — Most important
        _HeroCard(
          transaction: tx,
          ink: ink,
          muted: muted,
          onMerchantTap: () => _openMerchant(tx),
        ),
        const SizedBox(height: AppSpacing.md),
        _EditButton(onPressed: _openEditSheet),
        const SizedBox(height: AppSpacing.md),

        // 2 — Payment details
        _DetailSectionCard(
          children: _paymentRows(tx, ink: ink, muted: muted),
        ),
        const SizedBox(height: AppSpacing.md),

        // 3 — Secondary meta
        _DetailSectionCard(
          children: _metaRows(tx, ink: ink, muted: muted),
        ),

        // 4 — Original SMS last
        if (tx.smsSource.raw.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _SmsExpandableCard(rawSms: tx.smsSource.raw, muted: muted),
        ],
      ],
    );
  }

  List<Widget> _paymentRows(
    TransactionEntity tx, {
    required Color ink,
    required Color muted,
  }) {
    final l10n = context.l10n;
    final rows = <Widget>[];

    void add(String label, String value, {required IconData icon}) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      rows.add(
        _InfoRow(
          icon: icon,
          label: label,
          muted: muted,
          value: Text(
            trimmed,
            maxLines: 1,
            overflow: TextOverflow.clip,
            textAlign: TextAlign.end,
            style: _valueStyle(ink),
          ),
        ),
      );
    }

    add(l10n.transactionBank, tx.bank, icon: Icons.account_balance_outlined);
    add(
      l10n.transactionBranch,
      tx.branch ?? '',
      icon: Icons.location_city_outlined,
    );
    add(
      l10n.transactionAccount,
      tx.accountIdMasked,
      icon: Icons.wallet_outlined,
    );
    add(
      l10n.transactionPaymentMethod,
      paymentMethodLabel(l10n, tx.paymentMethod),
      icon: Icons.credit_card_outlined,
    );

    final reference = _referenceId(tx);
    if (reference != null) {
      rows.add(
        _InfoRow(
          icon: Icons.tag_outlined,
          label: l10n.transactionReferenceId,
          muted: muted,
          value: _ReferenceBadge(
            value: reference,
            ink: ink,
            onCopy: () async {
              await Clipboard.setData(ClipboardData(text: reference));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.transactionReferenceCopied)),
              );
            },
          ),
        ),
      );
    }

    return rows;
  }

  List<Widget> _metaRows(
    TransactionEntity tx, {
    required Color ink,
    required Color muted,
  }) {
    final l10n = context.l10n;
    final rows = <Widget>[];

    void add(
      String label,
      String value, {
      required IconData icon,
      int maxLines = 1,
    }) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      rows.add(
        _InfoRow(
          icon: icon,
          label: label,
          muted: muted,
          value: Text(
            trimmed,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: _valueStyle(ink),
          ),
        ),
      );
    }

    final isCredit = tx.type == 'credit';
    add(
      l10n.transactionType,
      isCredit ? l10n.feedFilterTypeCredit : l10n.feedFilterTypeDebit,
      icon: isCredit ? Icons.south_west_rounded : Icons.north_east_rounded,
    );
    add(
      l10n.transactionMerchantDetails,
      tx.merchantDetails ?? '',
      icon: Icons.storefront_outlined,
      maxLines: 3,
    );
    add(
      l10n.transactionStatus,
      _statusLabel(l10n, tx),
      icon: Icons.info_outline,
    );

    final confidencePercent = (tx.parseConfidence * 100)
        .clamp(0, 100)
        .round()
        .toString();
    add(
      l10n.transactionConfidence,
      l10n.transactionConfidenceValue(confidencePercent),
      icon: Icons.verified_outlined,
    );
    add(
      l10n.transactionSource,
      tx.isAutoDetected || tx.smsSource.source.toLowerCase() != 'manual'
          ? l10n.transactionSourceSms
          : l10n.transactionSourceManual,
      icon: Icons.sms_outlined,
    );

    return rows;
  }

  TextStyle _valueStyle(Color ink) {
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: ink,
    );
  }

  String _statusLabel(AppLocalizations l10n, TransactionEntity tx) {
    if (tx.status == 'deleted') return l10n.transactionStatusDeleted;
    if (tx.needsConfidenceReview) return l10n.transactionStatusNeedsReview;
    return l10n.transactionStatusCleared;
  }

  String? _referenceId(TransactionEntity tx) {
    final external = tx.externalId?.trim();
    if (external == null || external.isEmpty) return null;
    return external.startsWith('#') ? external : '#$external';
  }
}

// ─── Shared surfaces ─────────────────────────────────────────────────────────

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final border = AppColors.border(brightness);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card(brightness),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark ? border : border.withValues(alpha: 0.45),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _DetailSectionCard extends StatelessWidget {
  const _DetailSectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final dividerColor = AppColors.border(
      Theme.of(context).brightness,
    ).withValues(alpha: 0.35);

    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, indent: 56, color: dividerColor),
            children[i],
          ],
        ],
      ),
    );
  }
}

// ─── Hero ────────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.transaction,
    required this.ink,
    required this.muted,
    required this.onMerchantTap,
  });

  final TransactionEntity transaction;
  final Color ink;
  final Color muted;
  final VoidCallback onMerchantTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tx = transaction;
    final isCredit = tx.type == 'credit';
    final merchantLabel = tx.merchant.isEmpty
        ? l10n.transactionMerchant
        : tx.merchant;
    final amountColor = isCredit ? AppColors.accent : AppColors.spend;
    final sign = isCredit ? '+ ' : '− ';
    final currency = AppCurrencyScope.of(context);
    final amountText = '$sign${currency.formatMoney(tx.amount)}';
    final canOpenMerchant = tx.merchant.trim().isNotEmpty;
    final meta = _metaLine(context, tx);

    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          CategoryAvatar(
            category: tx.category,
            size: 56,
            circular: true,
            showBorder: true,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.transactionAmount,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: muted,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            amountText,
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              height: 1.15,
              color: amountColor,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          InkWell(
            onTap: canOpenMerchant ? onMerchantTap : null,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      merchantLabel,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        height: 1.25,
                        color: ink,
                      ),
                    ),
                  ),
                  if (canOpenMerchant) ...[
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppColors.primaryStrong,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (tx.category.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              tx.category,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: categoryColor(
                  tx.category,
                  storedHex: CategoryColorScope.maybeOf(context)
                      ?.hexFor(tx.category),
                ),
              ),
            ),
          ],
          if (meta.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _DateTimePill(label: meta, muted: muted),
          ],
          if (_hasStatusBadges(tx)) ...[
            const SizedBox(height: AppSpacing.sm),
            _StatusBadges(transaction: tx),
          ],
        ],
      ),
    );
  }

  bool _hasStatusBadges(TransactionEntity tx) {
    return tx.needsConfidenceReview ||
        tx.isEdited ||
        tx.isDuplicate ||
        tx.isRecurring;
  }

  String _metaLine(BuildContext context, TransactionEntity tx) {
    final l10n = context.l10n;
    final date = _formatShortDate(tx.transactionDate);
    final time = formatClockTime(tx.transactionTime);
    if (date.isEmpty && time.isEmpty) return '';
    if (date.isNotEmpty && time.isNotEmpty) {
      return l10n.transactionMetaLine(date, time);
    }
    return date.isNotEmpty ? date : time;
  }

  String _formatShortDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat.MMMd().format(parsed);
  }
}

class _DateTimePill extends StatelessWidget {
  const _DateTimePill({required this.label, required this.muted});

  final String label;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.neutralFill(brightness)
            : AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 14,
            color: AppColors.primaryStrong,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.2,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: SvgPicture.asset(
          'assets/icons/icon_edit.svg',
          width: 16,
          height: 16,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
        label: Text(l10n.transactionEditTransaction),
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: AppColors.primaryStrong,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

// ─── Status badges ───────────────────────────────────────────────────────────

class _StatusBadges extends StatelessWidget {
  const _StatusBadges({required this.transaction});

  final TransactionEntity transaction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final chips = <Widget>[];

    if (transaction.needsConfidenceReview) {
      final percent = (transaction.parseConfidence * 100)
          .clamp(0, 100)
          .round()
          .toString();
      final brightness = theme.brightness;
      chips.add(
        _StatusChip(
          label: l10n.reviewConfidence(percent),
          foreground: AppColors.warningForeground(brightness),
          background: AppColors.warningBackground(brightness),
          icon: Icons.warning_amber_rounded,
        ),
      );
    }
    if (transaction.isEdited) {
      chips.add(
        _StatusChip(
          label: l10n.transactionEdited,
          foreground: theme.colorScheme.onSurfaceVariant,
          background: AppColors.neutralFill(theme.brightness),
        ),
      );
    }
    if (transaction.isDuplicate) {
      chips.add(
        _StatusChip(
          label: l10n.transactionDuplicate,
          foreground: AppColors.spend,
          background: AppColors.spend.withValues(alpha: 0.12),
          icon: Icons.copy_all_outlined,
        ),
      );
    }
    if (transaction.isRecurring) {
      chips.add(
        _StatusChip(
          label: l10n.transactionRecurring,
          foreground: AppColors.primaryStrong,
          background: AppColors.accentMuted,
          icon: Icons.repeat,
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: chips,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
  });

  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info rows ───────────────────────────────────────────────────────────────

class _DetailIconTile extends StatelessWidget {
  const _DetailIconTile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.neutralFill(brightness)
            : AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: AppColors.primaryStrong),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.muted,
  });

  final IconData icon;
  final String label;
  final Widget value;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _DetailIconTile(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.visible,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: muted,
              ),
            ),
          ),
          Flexible(
            child: Align(alignment: Alignment.centerRight, child: value),
          ),
        ],
      ),
    );
  }
}

class _ReferenceBadge extends StatelessWidget {
  const _ReferenceBadge({
    required this.value,
    required this.ink,
    required this.onCopy,
  });

  final String value;
  final Color ink;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCopy,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.neutralFill(brightness),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                    color: ink,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.copy_outlined,
                size: 14,
                color: AppColors.primaryStrong,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── SMS (last) ──────────────────────────────────────────────────────────────

class _SmsExpandableCard extends StatelessWidget {
  const _SmsExpandableCard({required this.rawSms, required this.muted});

  final String rawSms;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          leading: _DetailIconTile(icon: Icons.sms_outlined),
          title: Text(
            l10n.transactionRawSms.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.3,
              letterSpacing: 0.6,
              color: muted,
            ),
          ),
          iconColor: AppColors.primaryStrong,
          collapsedIconColor: AppColors.primaryStrong,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                rawSms,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  color: muted,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
