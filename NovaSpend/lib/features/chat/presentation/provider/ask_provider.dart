import 'dart:async';

import 'package:nova_spend/core/provider/safe_change_notifier.dart';
import 'package:nova_spend/features/analytics/domain/insights_math.dart';
import 'package:nova_spend/features/chat/domain/entities/chat_answer_entity.dart';
import 'package:nova_spend/features/chat/domain/entities/chat_suggestion_entity.dart';
import 'package:nova_spend/features/chat/domain/repositories/chat_repository.dart';

class AskTurn {
  const AskTurn({
    required this.question,
    this.answer,
    this.error,
    this.isLoading = false,
  });

  final String question;
  final ChatAnswerEntity? answer;
  final Object? error;
  final bool isLoading;
}

class AskProvider extends SafeChangeNotifier {
  AskProvider({required ChatRepository repository}) : _repository = repository;

  final ChatRepository _repository;

  InsightsPeriodPreset preset = InsightsPeriodPreset.thisMonth;
  List<ChatSuggestionEntity> suggestions = const [];
  List<AskTurn> turns = const [];
  bool isLoadingSuggestions = false;
  Object? suggestionsError;
  String? _uid;
  int _suggestionToken = 0;
  int _askToken = 0;

  bool get isAsking => turns.any((turn) => turn.isLoading);

  bool get hasConversation => turns.isNotEmpty;

  ({DateTime from, DateTime to}) get range {
    return insightsRange(preset: preset, now: DateTime.now());
  }

  void start(String uid) {
    if (_uid == uid) return;
    _uid = uid;
    unawaited(loadSuggestions());
  }

  void setPreset(InsightsPeriodPreset next) {
    if (preset == next) return;
    preset = next;
    notifyListeners();
    unawaited(loadSuggestions());
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

  Future<void> submit(String question) async {
    final uid = _uid;
    final text = question.trim();
    if (uid == null || text.isEmpty || isAsking) return;
    final token = ++_askToken;
    turns = [...turns, AskTurn(question: text, isLoading: true)];
    notifyListeners();
    try {
      final bounds = range;
      final answer = await _repository.ask(
        uid,
        question: text,
        from: bounds.from,
        to: bounds.to,
      );
      if (token != _askToken) return;
      turns = [
        ...turns.sublist(0, turns.length - 1),
        AskTurn(question: text, answer: answer),
      ];
    } catch (error) {
      if (token != _askToken) return;
      turns = [
        ...turns.sublist(0, turns.length - 1),
        AskTurn(question: text, error: error),
      ];
    } finally {
      if (token == _askToken) notifyListeners();
    }
  }

  Future<void> retryLast() async {
    if (turns.isEmpty || isAsking) return;
    final last = turns.last;
    if (last.error == null) return;
    turns = turns.sublist(0, turns.length - 1);
    await submit(last.question);
  }
}
