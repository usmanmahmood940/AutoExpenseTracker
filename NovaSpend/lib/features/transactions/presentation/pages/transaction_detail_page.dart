import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
import 'package:nova_spend/features/transactions/presentation/widgets/edit_transaction_sheet.dart';
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
  List<String> _categories = const [];

  static const double _barHeight = 48;

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

  Future<void> _openEditSheet() async {
    final l10n = context.l10n;
    final saved = await EditTransactionSheet.show(
      context,
      categories: _categories,
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.transactionSaved)),
    );
  }

  double _headerHeight(BuildContext context) {
    return MediaQuery.paddingOf(context).top + _barHeight;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? AppColors.surfaceDark : _DetailColors.pageBg;
    final headerH = _headerHeight(context);
    final provider = context.watch<TransactionDetailProvider>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: pageBg,
        body: Stack(
          children: [
            Positioned.fill(
              child: _buildDetailView(provider, headerH),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _GreenHeader(
                title: l10n.transactionDetail,
                height: headerH,
                barHeight: _barHeight,
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
            Text(
              _metaLine(tx),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: ink.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  offset: const Offset(0, 4),
                  blurRadius: 6,
                  spreadRadius: -1,
                ),
              ],
            ),
            child: FilledButton.icon(
              onPressed: _openEditSheet,
              icon: SvgPicture.asset(
                'assets/icons/icon_edit.svg',
                width: 15,
                height: 15,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
              label: Text(l10n.transactionEditTransaction),
              style: FilledButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppColors.primaryStrong,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 12,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
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

  String _metaLine(TransactionEntity tx) {
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

/// Figma Header — Top App Bar: solid accent green + back + title.
class _GreenHeader extends StatelessWidget {
  const _GreenHeader({
    required this.title,
    required this.height,
    required this.barHeight,
  });

  final String title;
  final double height;
  final double barHeight;

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

    if (transaction.bank.isNotEmpty) {
      rows.add(
        _InfoRow(
          iconAsset: 'assets/icons/icon_bank.svg',
          label: l10n.transactionBank,
          muted: muted,
          value: Text(
            transaction.bank,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _valueStyle(ink),
          ),
        ),
      );
    }

    final account = transaction.accountIdMasked.trim();
    if (account.isNotEmpty) {
      rows.add(
        _InfoRow(
          iconAsset: 'assets/icons/icon_account.svg',
          label: l10n.transactionAccount,
          muted: muted,
          value: Text(
            account,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _valueStyle(ink),
          ),
        ),
      );
    }

    final payment = transaction.paymentMethod.trim();
    if (payment.isNotEmpty) {
      rows.add(
        _InfoRow(
          iconAsset: 'assets/icons/icon_payment_method.svg',
          iconWidth: 20,
          iconHeight: 16,
          label: l10n.transactionPaymentMethod,
          muted: muted,
          value: Text(
            payment,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _valueStyle(ink),
          ),
        ),
      );
    }

    final reference = _referenceId(transaction);
    if (reference != null) {
      rows.add(
        _InfoRow(
          iconAsset: 'assets/icons/icon_reference_id.svg',
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
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.5,
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
    required this.iconAsset,
    required this.label,
    required this.value,
    required this.muted,
    this.iconWidth = 20,
    this.iconHeight = 20,
  });

  final String iconAsset;
  final String label;
  final Widget value;
  final Color muted;
  final double iconWidth;
  final double iconHeight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SvgPicture.asset(
            iconAsset,
            width: iconWidth,
            height: iconHeight,
            colorFilter: ColorFilter.mode(muted, BlendMode.srcIn),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: muted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? AppColors.neutralFillDark : _DetailColors.avatarFill,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 16,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: ink,
        ),
      ),
    );
  }
}
