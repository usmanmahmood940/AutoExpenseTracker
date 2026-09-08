import 'package:flutter/material.dart';
import 'package:nova_spend/core/currency/app_currency_controller.dart';
import 'package:nova_spend/core/currency/app_currency_scope.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/adaptive_scaffold.dart';
import 'package:nova_spend/core/widgets/app_loader.dart';
import 'package:nova_spend/core/widgets/error_state_view.dart';
import 'package:nova_spend/core/widgets/glass_header_bar.dart';
import 'package:nova_spend/core/widgets/hero_wash.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/chat/domain/entities/chat_citation_entity.dart';
import 'package:nova_spend/features/chat/presentation/ask_error_mapper.dart';
import 'package:nova_spend/features/chat/presentation/provider/ask_provider.dart';
import 'package:nova_spend/features/chat/presentation/widgets/ask_input_bar.dart';
import 'package:nova_spend/features/chat/presentation/widgets/ask_suggestion_chips.dart';
import 'package:nova_spend/features/chat/presentation/widgets/ask_turn_views.dart';
import 'package:nova_spend/features/search/presentation/provider/search_provider.dart';
import 'package:nova_spend/features/settings/presentation/main_shell_scope.dart';
import 'package:nova_spend/features/settings/presentation/widgets/shell_glass_header_bar.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/presentation/pages/transaction_detail_page.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:provider/provider.dart';

class AskPage extends StatelessWidget {
  const AskPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().uid;
    if (uid == null) {
      return _AskChrome(body: AppPageLoader(label: context.l10n.authLoading));
    }

    return const _AskView();
  }
}

class _AskChrome extends StatelessWidget {
  const _AskChrome({required this.body, this.leadingActions = const []});

  final Widget body;
  final List<Widget> leadingActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdaptiveScaffold(
      applySafeArea: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          const Positioned(top: 0, left: 0, right: 0, child: HeroWash()),
          Positioned.fill(child: body),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: GlassHeaderBar.totalHeight(context),
            child: ShellGlassHeaderBar(leadingActions: leadingActions),
          ),
        ],
      ),
    );
  }
}

class _AskView extends StatefulWidget {
  const _AskView();

  @override
  State<_AskView> createState() => _AskViewState();
}

class _AskViewState extends State<_AskView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  var _draft = '';
  var _openingCitation = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.read<AuthProvider>().uid;
    if (uid != null) context.read<AskProvider>().start(uid);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    _input.clear();
    setState(() => _draft = '');
    await context.read<AskProvider>().submit(text);
    if (!mounted) return;
    _scrollToEnd();
  }

  void _openActivity(String answer, {String? filterTerm}) {
    final term = navigationFilterTerm(answer, filterTerm: filterTerm);
    if (term != null && term.isNotEmpty) {
      context.read<SearchProvider>().submitText(term);
    }
    MainShellScope.selectTransactionsTab(context);
  }

  Future<void> _openCitation(ChatCitationEntity citation) async {
    if (_openingCitation) return;
    final id = citation.transactionId;
    final uid = context.read<AuthProvider>().uid;
    if (id == null || id.isEmpty || uid == null) return;

    _openingCitation = true;
    final preview = _transactionPreviewFromCitation(
      uid: uid,
      citation: citation,
      currency: AppCurrencyScope.of(context).currency,
    );
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TransactionDetailPage(transaction: preview),
        ),
      );
    } finally {
      _openingCitation = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<AskProvider>();
    final money = AppCurrencyScope.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final asking = provider.isAsking;
    final canSend = _draft.trim().isNotEmpty && !asking;

    return _AskChrome(
      leadingActions: [
        if (provider.hasConversation)
          _AskClearButton(onPressed: provider.clearThread),
      ],
      body: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Column(
          children: [
            Expanded(child: _buildConversation(context, provider, money)),
            if (provider.hasConversation && provider.suggestions.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: TextButton(
                    onPressed: provider.toggleMoreSuggestions,
                    child: Text(l10n.askMoreQuestions),
                  ),
                ),
              ),
            if (provider.hasConversation && provider.showMoreSuggestions)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: AskSuggestionChips(
                  suggestions: provider.suggestions,
                  enabled: !asking,
                  onSelected: _send,
                ),
              ),
            AskInputBar(
              controller: _input,
              canSend: canSend,
              onChanged: (value) => setState(() => _draft = value),
              onSend: () => _send(_input.text),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversation(
    BuildContext context,
    AskProvider provider,
    AppCurrencyController money,
  ) {
    final l10n = context.l10n;
    if (!provider.hasConversation) {
      if (provider.suggestionsError != null && provider.suggestions.isEmpty) {
        return ErrorStateView(
          error: provider.suggestionsError,
          onRetry: provider.loadSuggestions,
        );
      }
      return ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          GlassHeaderBar.contentTopPadding(context),
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [
          Text(
            l10n.askPlaceholderTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.askPlaceholderBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (provider.isLoadingSuggestions)
            const AskSuggestionChipsSkeleton()
          else
            AskSuggestionChips(
              suggestions: provider.suggestions,
              enabled: !provider.isAsking,
              onSelected: _send,
            ),
        ],
      );
    }

    return ListView.separated(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        GlassHeaderBar.contentTopPadding(context),
        AppSpacing.md,
        AppSpacing.md,
      ),
      itemCount: provider.turns.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final turn = provider.turns[index];
        final isLast = index == provider.turns.length - 1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AskUserBubble(question: turn.question),
            const SizedBox(height: AppSpacing.smPlus2),
            AskAssistantCard(
              turn: turn,
              formatMoney: money.formatMoney,
              periodLabel: askPeriodLabel(
                l10n,
                windowFrom: turn.answer?.windowFrom,
                windowTo: turn.answer?.windowTo,
              ),
              onRetry: isLast && turn.error != null ? provider.retryLast : null,
              onOpenActivity: turn.answer?.isNavigation == true
                  ? () => _openActivity(
                      turn.answer!.answer,
                      filterTerm: turn.answer!.filterTerm,
                    )
                  : null,
              onCitationTap: _openCitation,
            ),
          ],
        );
      },
    );
  }
}

/// Header "Clear" control sized to the 20px settings icon beside it.
class _AskClearButton extends StatelessWidget {
  const _AskClearButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = AppColors.primaryInk(Theme.of(context).brightness);

    return Semantics(
      button: true,
      label: l10n.askClearThread,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          child: Text(
            l10n.askClearThread,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 16,
              height: 1.25,
            ),
          ),
        ),
      ),
    );
  }
}

/// Enough of a transaction for Ask citations to open detail immediately.
/// [TransactionDetailPage] then loads the full record (SMS, bank, etc.).
TransactionEntity _transactionPreviewFromCitation({
  required String uid,
  required ChatCitationEntity citation,
  required String currency,
}) {
  return TransactionEntity(
    id: citation.transactionId ?? '',
    userId: uid,
    amount: citation.amount ?? 0,
    currency: currency,
    type: 'debit',
    merchant: citation.merchant?.trim() ?? '',
    category: citation.category?.trim() ?? '',
    categorySource: '',
    paymentMethod: '',
    bank: '',
    accountId: '',
    accountIdMasked: '',
    transactionTime: '',
    transactionDate: citation.date ?? '',
    day: '',
    externalIdType: 'unknown',
    dedupKey: '',
    smsSource: const SmsSourceEntity(raw: '', source: ''),
    parseConfidence: 1,
    isAutoDetected: false,
    isEdited: false,
    isDuplicate: false,
    status: 'active',
  );
}
