import 'package:flutter/material.dart';
import 'package:nova_spend/core/currency/app_currency_controller.dart';
import 'package:nova_spend/core/currency/app_currency_scope.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/adaptive_scaffold.dart';
import 'package:nova_spend/core/widgets/app_loader.dart';
import 'package:nova_spend/core/widgets/app_segmented_toggle.dart';
import 'package:nova_spend/core/widgets/empty_state_view.dart';
import 'package:nova_spend/core/widgets/error_state_view.dart';
import 'package:nova_spend/core/widgets/glass_header_bar.dart';
import 'package:nova_spend/core/widgets/hero_wash.dart';
import 'package:nova_spend/features/analytics/domain/insights_math.dart';
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
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';
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

    return ChangeNotifierProvider(
      create: (_) {
        final provider = sl<AskProvider>();
        provider.start(uid);
        return provider;
      },
      child: const _AskView(),
    );
  }
}

class _AskChrome extends StatelessWidget {
  const _AskChrome({required this.body});

  final Widget body;

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
            child: const ShellGlassHeaderBar(),
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

  void _openActivity(String answer) {
    final term = navigationFilterTerm(answer);
    if (term != null && term.isNotEmpty) {
      context.read<SearchProvider>().submitText(term);
    }
    MainShellScope.selectTransactionsTab(context);
  }

  Future<void> _openCitation(ChatCitationEntity citation) async {
    final id = citation.transactionId;
    final uid = context.read<AuthProvider>().uid;
    if (id == null || id.isEmpty || uid == null) return;
    final l10n = context.l10n;
    try {
      final tx = await sl<TransactionRepository>().getTransaction(uid, id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TransactionDetailPage(transaction: tx),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorLoadFailed)));
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
      body: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                GlassHeaderBar.contentTopPadding(context),
                AppSpacing.md,
                0,
              ),
              child: AppSegmentedToggle<InsightsPeriodPreset>(
                value: provider.preset,
                onChanged: provider.setPreset,
                segments: [
                  AppSegment(
                    value: InsightsPeriodPreset.thisMonth,
                    label: l10n.insightsThisMonth,
                  ),
                  AppSegment(
                    value: InsightsPeriodPreset.lastMonth,
                    label: l10n.insightsLastMonth,
                  ),
                  AppSegment(
                    value: InsightsPeriodPreset.thisYear,
                    label: l10n.insightsThisYear,
                  ),
                ],
              ),
            ),
            Expanded(child: _buildConversation(context, provider, money)),
            AskSuggestionChips(
              suggestions: provider.suggestions,
              enabled: !asking,
              onSelected: _send,
            ),
            AskInputBar(
              controller: _input,
              enabled: !asking,
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
      return EmptyStateView(
        iconAsset: 'assets/icons/icon_nav_ask.svg',
        title: l10n.askPlaceholderTitle,
        message: l10n.askPlaceholderBody,
      );
    }

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
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
              onRetry: isLast && turn.error != null ? provider.retryLast : null,
              onOpenActivity: turn.answer?.isNavigation == true
                  ? () => _openActivity(turn.answer!.answer)
                  : null,
              onCitationTap: _openCitation,
            ),
          ],
        );
      },
    );
  }
}
