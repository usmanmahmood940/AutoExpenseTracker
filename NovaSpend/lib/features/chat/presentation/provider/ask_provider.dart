import 'dart:async';

import 'package:nova_spend/core/provider/safe_change_notifier.dart';
import 'package:nova_spend/features/analytics/domain/insights_math.dart';
import 'package:nova_spend/features/chat/domain/entities/agent_proposal_entity.dart';
import 'package:nova_spend/features/chat/domain/entities/chat_answer_entity.dart';
import 'package:nova_spend/features/chat/domain/entities/chat_suggestion_entity.dart';
import 'package:nova_spend/features/chat/domain/repositories/chat_repository.dart';

const askDefaultLookbackDays = 365;

class AskTurn {
  const AskTurn({
    required this.question,
    this.from,
    this.to,
    this.answer,
    this.error,
    this.isLoading = false,
  });

  final String question;
  final DateTime? from;
  final DateTime? to;
  final ChatAnswerEntity? answer;
  final Object? error;
  final bool isLoading;
}

class AskProvider extends SafeChangeNotifier {
  AskProvider({required ChatRepository repository}) : _repository = repository;

  final ChatRepository _repository;

  List<ChatSuggestionEntity> suggestions = const [];
  List<AskTurn> turns = const [];
  bool isLoadingSuggestions = false;
  bool showMoreSuggestions = false;
  Object? suggestionsError;
  String? _uid;
  int _suggestionToken = 0;
  int _askToken = 0;

  bool get isAsking => turns.any((turn) => turn.isLoading);

  bool get hasConversation => turns.isNotEmpty;

  ({DateTime from, DateTime to}) get range {
    final to = dateOnly(DateTime.now());
    final from = to.subtract(const Duration(days: askDefaultLookbackDays));
    return (from: from, to: to);
  }

  void start(String uid) {
    if (_uid == uid) return;
    _uid = uid;
    unawaited(loadSuggestions());
  }

  void clearThread() {
    if (!hasConversation && !showMoreSuggestions) return;
    _askToken++;
    turns = const [];
    showMoreSuggestions = false;
    notifyListeners();
  }

  void toggleMoreSuggestions() {
    showMoreSuggestions = !showMoreSuggestions;
    notifyListeners();
  }

  Future<void> loadSuggestions() async {
    final uid = _uid;
    if (uid == null) return;
    final token = ++_suggestionToken;
    isLoadingSuggestions = true;
    suggestionsError = null;
    notifyListeners();
    try {
      final bounds = range;
      final items = await _repository.getSuggestions(
        uid,
        from: bounds.from,
        to: bounds.to,
      );
      if (token != _suggestionToken) return;
      suggestions = items;
    } catch (error) {
      if (token != _suggestionToken) return;
      suggestionsError = error;
      suggestions = const [];
    } finally {
      if (token == _suggestionToken) {
        isLoadingSuggestions = false;
        notifyListeners();
      }
    }
  }

  Future<void> submit(String question, {DateTime? from, DateTime? to}) async {
    final uid = _uid;
    final text = question.trim();
    if (uid == null || text.isEmpty || isAsking) return;
    final history = [
      for (final turn in turns)
        if (turn.answer != null && turn.answer!.answer.trim().isNotEmpty)
          (question: turn.question, answer: turn.answer!.answer),
    ];
    final prior = history.length > 3
        ? history.sublist(history.length - 3)
        : history;
    final token = ++_askToken;
    showMoreSuggestions = false;
    final bounds = range;
    final usedFrom = from ?? bounds.from;
    final usedTo = to ?? bounds.to;
    turns = [
      ...turns,
      AskTurn(question: text, from: usedFrom, to: usedTo, isLoading: true),
    ];
    notifyListeners();
    try {
      final answer = await _repository.ask(
        uid,
        question: text,
        from: usedFrom,
        to: usedTo,
        history: prior,
      );
      if (token != _askToken) return;
      turns = [
        ...turns.sublist(0, turns.length - 1),
        AskTurn(question: text, from: usedFrom, to: usedTo, answer: answer),
      ];
    } catch (error) {
      if (token != _askToken) return;
      turns = [
        ...turns.sublist(0, turns.length - 1),
        AskTurn(question: text, from: usedFrom, to: usedTo, error: error),
      ];
    } finally {
      if (token == _askToken) notifyListeners();
    }
  }

  Future<bool> confirmProposal(String proposalId) async {
    final key =
        'confirm-${proposalId}-${DateTime.now().microsecondsSinceEpoch}';
    await _repository.confirmProposal(
      proposalId: proposalId,
      idempotencyKey: key,
    );
    turns = [
      for (final turn in turns)
        if (turn.answer?.proposal?.proposalId == proposalId)
          AskTurn(
            question: turn.question,
            from: turn.from,
            to: turn.to,
            answer: ChatAnswerEntity(
              answer: turn.answer!.answer,
              citations: turn.answer!.citations,
              confidence: turn.answer!.confidence,
              source: turn.answer!.source,
              model: turn.answer!.model,
              filterTerm: turn.answer!.filterTerm,
              windowFrom: turn.answer!.windowFrom,
              windowTo: turn.answer!.windowTo,
              proposal: AgentProposalEntity(
                proposalId: proposalId,
                status: 'executed',
                intent: turn.answer!.proposal!.intent,
                steps: turn.answer!.proposal!.steps,
                summary: turn.answer!.proposal!.summary,
                expiresAt: turn.answer!.proposal!.expiresAt,
                model: turn.answer!.proposal!.model,
              ),
            ),
          )
        else
          turn,
    ];
    notifyListeners();
    return true;
  }

  Future<void> rejectProposal(String proposalId) async {
    await _repository.rejectProposal(proposalId: proposalId);
    turns = [
      for (final turn in turns)
        if (turn.answer?.proposal?.proposalId == proposalId)
          AskTurn(
            question: turn.question,
            from: turn.from,
            to: turn.to,
            answer: ChatAnswerEntity(
              answer: turn.answer!.answer,
              citations: turn.answer!.citations,
              confidence: turn.answer!.confidence,
              source: turn.answer!.source,
              model: turn.answer!.model,
              filterTerm: turn.answer!.filterTerm,
              windowFrom: turn.answer!.windowFrom,
              windowTo: turn.answer!.windowTo,
            ),
          )
        else
          turn,
    ];
    notifyListeners();
  }

  Future<void> retryLast() async {
    if (turns.isEmpty || isAsking) return;
    final last = turns.last;
    if (last.error == null) return;
    turns = turns.sublist(0, turns.length - 1);
    await submit(last.question, from: last.from, to: last.to);
  }
}
