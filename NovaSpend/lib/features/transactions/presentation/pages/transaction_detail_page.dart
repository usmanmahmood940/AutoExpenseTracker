import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/utils/date_labels.dart';
import 'package:nova_spend/core/utils/money_format.dart';
import 'package:nova_spend/core/widgets/category_avatar.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/categories/domain/repositories/category_repository.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:nova_spend/features/transactions/domain/usecases/update_transaction.dart';
import 'package:nova_spend/features/transactions/presentation/provider/transaction_detail_provider.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:provider/provider.dart';

/// Figma palette extras for Transaction Detail (node 2103:67).
abstract final class _DetailColors {
  static const Color pageBg = Color(0xFFFAFAFA);
  static const Color ink = Color(0xFF1A1C1C);
  static const Color muted = Color(0xFF3C4A42);
  static const Color avatarFill = Color(0xFFEEEEEE);
  static const Color debit = Color(0xFFBA1A1A);
  static const Color cardFill = Color(0xFFF9F9F9);
}

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
      create: (_) => TransactionDetailProvider(
        uid: uid,
        transaction: transaction,
        updateTransaction: sl<UpdateTransaction>(),
        repository: sl<TransactionRepository>(),
      ),
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
  late final TextEditingController _merchant;
  late final TextEditingController _amount;
  List<String> _categories = const [];
  bool _editing = false;

  static const double _barHeight = 48;

  @override
  void initState() {
    super.initState();
    final tx = context.read<TransactionDetailProvider>().transaction;
    _merchant = TextEditingController(text: tx.merchant);
    _amount = TextEditingController(text: formatAmount(tx.amount));
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final repo = sl<CategoryRepository>();
    final uid = context.read<AuthProvider>().uid;
    final defaults = await repo.watchDefaults().first;
    if (!mounted) return;
    final custom =
        uid == null ? <dynamic>[] : await repo.watchUserCategories(uid).first;
    if (!mounted) return;
    final names = <String>{
      ...defaults.map((c) => c.name),
      ...custom.map((c) => c.name),
    }.toList()
      ..sort();
    setState(() => _categories = names);
  }

  @override
  void dispose() {
    _merchant.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _enterEdit() {
    final tx = context.read<TransactionDetailProvider>().transaction;
    _merchant.text = tx.merchant;
    _amount.text = formatAmount(tx.amount);
    setState(() => _editing = true);
  }

  void _cancelEdit() {
    final provider = context.read<TransactionDetailProvider>();
    final tx = provider.transaction;
    _merchant.text = tx.merchant;
    _amount.text = formatAmount(tx.amount);
    provider.setMerchant(tx.merchant);
    provider.setAmount(tx.amount);
    provider.setCategory(tx.category);
    provider.setType(tx.type);
    provider.setRememberForMerchant(false);
    setState(() => _editing = false);
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final provider = context.read<TransactionDetailProvider>();
    provider.setMerchant(_merchant.text);
    provider.setAmount(double.tryParse(_amount.text) ?? provider.amount);
    final ok = await provider.save();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.transactionSaved)),
      );
      setState(() => _editing = false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorGeneric)),
      );
    }
  }

  double _headerHeight(BuildContext context) {
    return MediaQuery.paddingOf(context).top + _barHeight;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<TransactionDetailProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? AppColors.surfaceDark : _DetailColors.pageBg;
    final headerH = _headerHeight(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: pageBg,
        body: Stack(
          children: [
            Positioned.fill(
              child: _editing
                  ? _buildEditForm(provider, headerH)
                  : _buildDetailView(provider, headerH),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _GreenHeader(
                title: l10n.transactionDetail,
                height: headerH,
                barHeight: _barHeight,
                actions: _editing
                    ? [
                        TextButton(
                          onPressed: provider.isSaving ? null : _cancelEdit,
                          style: TextButton.styleFrom(
                            foregroundColor: _DetailColors.ink,
                          ),
                          child: Text(l10n.transactionCancel),
                        ),
                        TextButton(
                          onPressed: provider.isSaving ? null : _save,
                          style: TextButton.styleFrom(
                            foregroundColor: _DetailColors.ink,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: Text(l10n.transactionSave),
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailView(
    TransactionDetailProvider provider,
    double headerH,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tx = provider.transaction;
    final isCredit = tx.type == 'credit';
    final merchantLabel =
        tx.merchant.isEmpty ? l10n.transactionMerchant : tx.merchant;
    final amountColor = isCredit ? AppColors.accent : _DetailColors.debit;
    final sign = isCredit ? '+' : '−';
    final amountText =
        '$sign${formatMoney(tx.amount, currency: tx.currency)}';
    final ink = isDark ? theme.colorScheme.onSurface : _DetailColors.ink;
    final muted = isDark
        ? theme.colorScheme.onSurfaceVariant
        : _DetailColors.muted;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        headerH + AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: [
        Column(
          children: [
            CategoryAvatar(
              category: tx.category,
              size: 44,
              circular: true,
              showBorder: true,
              backgroundColor:
                  isDark ? AppColors.neutralFillDark : _DetailColors.avatarFill,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              merchantLabel,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                height: 1.25,
                color: ink,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              amountText,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                height: 1.25,
                color: amountColor,
              ),
            ),
            if (tx.category.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _CategoryChip(label: tx.category, muted: muted),
            ],
            const SizedBox(height: AppSpacing.md),
            Opacity(
              opacity: 0.7,
              child: Text(
                _metaLine(tx),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  height: 1.35,
                  color: muted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: OutlinedButton.icon(
            onPressed: _enterEdit,
            icon: const Icon(Icons.edit_outlined, size: 14),
            label: Text(l10n.transactionEdit),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.spend,
              backgroundColor: Colors.transparent,
              side: const BorderSide(color: AppColors.spend, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (tx.smsSource.raw.trim().isNotEmpty) ...[
          _SmsExpandableCard(rawSms: tx.smsSource.raw, muted: muted),
          const SizedBox(height: AppSpacing.md),
        ],
        _InfoCard(transaction: tx, muted: muted, ink: ink),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.transactionReportThanks)),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: muted,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.help_outline, size: 13, color: muted),
                const SizedBox(width: 4),
                Text(
                  l10n.transactionReportIssue,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    height: 1.35,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditForm(
    TransactionDetailProvider provider,
    double headerH,
  ) {
    final l10n = context.l10n;
    final tx = provider.transaction;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        headerH + AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: [
        TextField(
          controller: _merchant,
          decoration: InputDecoration(labelText: l10n.transactionMerchant),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l10n.transactionAmount),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: _categories.contains(provider.category)
              ? provider.category
              : null,
          decoration: InputDecoration(labelText: l10n.transactionCategory),
          items: [
            if (!_categories.contains(provider.category))
              DropdownMenuItem(
                value: provider.category,
                child: Text(provider.category),
              ),
            ..._categories.map(
              (c) => DropdownMenuItem(value: c, child: Text(c)),
            ),
          ],
          onChanged: (v) {
            if (v != null) provider.setCategory(v);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: provider.type,
          decoration: InputDecoration(labelText: l10n.transactionType),
          items: [
            DropdownMenuItem(
              value: 'debit',
              child: Text(l10n.feedFilterTypeDebit),
            ),
            DropdownMenuItem(
              value: 'credit',
              child: Text(l10n.feedFilterTypeCredit),
            ),
          ],
          onChanged: (v) {
            if (v != null) provider.setType(v);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.transactionAlsoOverride),
          value: provider.rememberForMerchant,
          onChanged: provider.setRememberForMerchant,
        ),
        const SizedBox(height: AppSpacing.lg),
        _MetaRow(label: l10n.transactionBank, value: tx.bank),
        _MetaRow(label: l10n.transactionAccount, value: tx.accountIdMasked),
        _MetaRow(label: l10n.transactionDate, value: tx.transactionDate),
        _MetaRow(
          label: l10n.transactionConfidence,
          value: '${(tx.parseConfidence * 100).round()}%',
        ),
      ],
    );
  }

  String _metaLine(TransactionEntity tx) {
    final l10n = context.l10n;
    final date = _formatShortDate(tx.transactionDate);
    final time = formatClockTime(tx.transactionTime);
    final bankAccount = [
      if (tx.bank.isNotEmpty) tx.bank,
      if (tx.accountIdMasked.isNotEmpty) tx.accountIdMasked,
    ].join(' ');

    final parts = <String>[
      if (date.isNotEmpty) date,
      if (time.isNotEmpty) time,
      if (bankAccount.isNotEmpty) bankAccount,
    ];
    if (parts.isEmpty) return '';
    if (parts.length == 3) {
      return l10n.transactionMetaLine(parts[0], parts[1], parts[2]);
    }
    return parts.join(' · ');
  }

  String _formatShortDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat.MMMd().format(parsed);
  }
}

/// Figma Header — Top App Bar: solid accent green + back + title.
class _GreenHeader extends StatelessWidget {
  const _GreenHeader({
    required this.title,
    required this.height,
    required this.barHeight,
    this.actions,
  });

  final String title;
  final double height;
  final double barHeight;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Material(
      color: AppColors.accent,
      elevation: 0,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Column(
          children: [
            SizedBox(height: topInset),
            SizedBox(
              height: barHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back),
                      color: AppColors.primaryStrong,
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                          color: _DetailColors.ink,
                        ),
                      ),
                    ),
                    ...?actions,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Flat Figma detail surface — #F9F9F9, 12px radius, 1px border, no shadow.
class _FigmaCard extends StatelessWidget {
  const _FigmaCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : _DetailColors.cardFill,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: child,
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.muted});

  final String label;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.neutralFillDark : _DetailColors.avatarFill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          height: 1.3,
          color: muted,
        ),
      ),
    );
  }
}

class _SmsExpandableCard extends StatelessWidget {
  const _SmsExpandableCard({
    required this.rawSms,
    required this.muted,
  });

  final String rawSms;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return _FigmaCard(
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Icon(Icons.sms_outlined, size: 16, color: muted),
          title: Opacity(
            opacity: 0.6,
            child: Text(
              l10n.transactionRawSms.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.3,
                letterSpacing: 0.5,
                color: muted,
              ),
            ),
          ),
          iconColor: muted,
          collapsedIconColor: muted,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                rawSms,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: muted,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.transaction,
    required this.muted,
    required this.ink,
  });

  final TransactionEntity transaction;
  final Color muted;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rows = <Widget>[];

    final payment = transaction.paymentMethod.trim();
    if (payment.isNotEmpty) {
      rows.add(
        _InfoRow(
          label: l10n.transactionPaymentMethod,
          muted: muted,
          value: Text(payment, style: _valueStyle(ink)),
        ),
      );
    }

    if (transaction.bank.isNotEmpty) {
      rows.add(
        _InfoRow(
          label: l10n.transactionBank,
          muted: muted,
          value: Text(transaction.bank, style: _valueStyle(ink)),
        ),
      );
    }

    final reference = _referenceId(transaction);
    if (reference != null) {
      rows.add(
        _InfoRow(
          label: l10n.transactionReferenceId,
          muted: muted,
          value: _ReferenceBadge(value: reference, ink: ink),
        ),
      );
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return _FigmaCard(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: AppColors.borderLight.withValues(alpha: 0.3),
              ),
            rows[i],
          ],
        ],
      ),
    );
  }

  TextStyle _valueStyle(Color ink) {
    return TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.3,
      color: ink,
    );
  }

  String? _referenceId(TransactionEntity tx) {
    final external = tx.externalId?.trim();
    if (external != null && external.isNotEmpty) {
      return external.startsWith('#') ? external : '#$external';
    }
    if (tx.id.isNotEmpty) {
      final short = tx.id.length > 10 ? tx.id.substring(0, 10) : tx.id;
      return '#$short';
    }
    return null;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.muted,
  });

  final String label;
  final Widget value;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.3,
                color: muted,
              ),
            ),
          ),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: value,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceBadge extends StatelessWidget {
  const _ReferenceBadge({required this.value, required this.ink});

  final String value;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? AppColors.neutralFillDark : _DetailColors.avatarFill,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w400,
          height: 1.3,
          color: ink,
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
                  ),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }
}
