import 'package:flutter_test/flutter_test.dart';
import 'package:nova_spend/core/errors/failures.dart';
import 'package:nova_spend/features/chat/domain/entities/agent_proposal_entity.dart';
import 'package:nova_spend/features/chat/domain/entities/chat_answer_entity.dart';
import 'package:nova_spend/features/chat/domain/entities/chat_citation_entity.dart';
import 'package:nova_spend/features/chat/domain/entities/chat_suggestion_entity.dart';
import 'package:nova_spend/features/chat/domain/repositories/chat_repository.dart';
import 'package:nova_spend/features/chat/presentation/ask_error_mapper.dart';
import 'package:nova_spend/features/chat/presentation/provider/ask_provider.dart';
import 'package:nova_spend/features/chat/presentation/widgets/ask_turn_views.dart';
import 'package:nova_spend/l10n/app_localizations_en.dart';

class FakeChatRepository implements ChatRepository {
  List<ChatSuggestionEntity> suggestions = const [];
  ChatAnswerEntity? answer;
  Object? askError;
  Object? suggestionsError;
  String? lastQuestion;
  List<({String question, String answer})> lastHistory = const [];

  DateTime? lastFrom;
  DateTime? lastTo;

  @override
  Future<List<ChatSuggestionEntity>> getSuggestions(
    String uid, {
    required DateTime from,
    required DateTime to,
  }) async {
    if (suggestionsError != null) throw suggestionsError!;
    return suggestions;
  }

  @override
  Future<ChatAnswerEntity> ask(
    String uid, {
    required String question,
    DateTime? from,
    DateTime? to,
    List<({String question, String answer})> history = const [],
  }) async {
    lastQuestion = question;
    lastHistory = history;
    lastFrom = from;
    lastTo = to;
    if (askError != null) throw askError!;
    return answer!;
  }

  @override
  Future<AgentProposalEntity> confirmProposal({
    required String proposalId,
    required String idempotencyKey,
  }) async {
    return AgentProposalEntity(
      proposalId: proposalId,
      status: 'executed',
      intent: '',
      steps: const [],
      summary: '',
    );
  }

  @override
  Future<void> rejectProposal({required String proposalId}) async {}
}

void main() {
  test('start loads suggestions', () async {
    final repo = FakeChatRepository()
      ..suggestions = const [
        ChatSuggestionEntity(
          question: 'Why did food spending jump?',
          signalType: 'category_spike',
        ),
      ];
    final provider = AskProvider(repository: repo);
    provider.start('user-1');
    await Future<void>.delayed(Duration.zero);
    expect(provider.suggestions, hasLength(1));
    expect(provider.suggestions.first.question, contains('food'));
    provider.dispose();
  });

  test('submit appends a cited answer', () async {
    final repo = FakeChatRepository()
      ..answer = const ChatAnswerEntity(
        answer: 'Food spending rose because of KFC.',
        citations: [ChatCitationEntity(transactionId: 'tx-1', merchant: 'KFC')],
        confidence: 'high',
        source: 'rag',
      );
    final provider = AskProvider(repository: repo);
    provider.start('user-1');
    await provider.submit('Why did food spending jump?');
    expect(repo.lastQuestion, 'Why did food spending jump?');
    expect(provider.turns, hasLength(1));
    expect(provider.turns.first.answer?.citations, hasLength(1));
    expect(provider.isAsking, isFalse);
    provider.dispose();
  });

  test('submit override from/to is sent to the repository', () async {
    final repo = FakeChatRepository()
      ..answer = const ChatAnswerEntity(
        answer: 'Food spending rose because of KFC.',
        confidence: 'high',
        source: 'rag',
      );
    final provider = AskProvider(repository: repo);
    provider.start('user-1');
    final from = DateTime(2026, 8, 1);
    final to = DateTime(2026, 8, 31);
    await provider.submit('Why did food spending jump?', from: from, to: to);
    expect(repo.lastFrom, from);
    expect(repo.lastTo, to);
    provider.dispose();
  });

  test('clearThread drops turns', () async {
    final repo = FakeChatRepository()
      ..answer = const ChatAnswerEntity(
        answer: 'Food spending rose because of KFC.',
        confidence: 'high',
        source: 'rag',
      );
    final provider = AskProvider(repository: repo);
    provider.start('user-1');
    await provider.submit('Why did food spending jump?');
    provider.clearThread();
    expect(provider.turns, isEmpty);
    expect(provider.hasConversation, isFalse);
    provider.dispose();
  });

  test('submit records server failures on the turn', () async {
    final repo = FakeChatRepository()
      ..askError = const ServerFailure('nope', 'chat_off_topic');
    final provider = AskProvider(repository: repo);
    provider.start('user-1');
    await provider.submit('What is the weather?');
    expect(provider.turns, hasLength(1));
    expect(provider.turns.first.error, isA<ServerFailure>());
    provider.dispose();
  });

  test('AskErrorMapper maps chat codes', () {
    final l10n = AppLocalizationsEn();
    expect(
      AskErrorMapper.message(l10n, const ServerFailure('x', 'chat_off_topic')),
      l10n.askErrorOffTopic,
    );
    expect(
      AskErrorMapper.message(
        l10n,
        const ServerFailure('x', 'insufficient_data'),
      ),
      l10n.askErrorInsufficientData,
    );
    expect(
      AskErrorMapper.message(l10n, const ServerFailure('x', 'rate_limited')),
      l10n.askErrorRateLimited,
    );
    expect(
      AskErrorMapper.message(l10n, const ServerFailure('x', 'range_mismatch')),
      l10n.askErrorRangeMismatch,
    );
  });

  test('navigationFilterTerm reads quoted merchant', () {
    expect(
      navigationFilterTerm('Use the Activity screen and filter by “KFC”.'),
      'KFC',
    );
    expect(navigationFilterTerm('filter by "Daraz"'), 'Daraz');
    expect(navigationFilterTerm('no quotes'), isNull);
  });

  test('navigationFilterTerm prefers structured filter_term', () {
    expect(
      navigationFilterTerm('filter by “KFC”', filterTerm: 'Daraz'),
      'Daraz',
    );
    expect(navigationFilterTerm('no quotes', filterTerm: '  KFC  '), 'KFC');
  });

  test('submit sends prior turns as history', () async {
    final repo = FakeChatRepository()
      ..answer = const ChatAnswerEntity(
        answer: 'Food spending rose because of KFC.',
        confidence: 'high',
        source: 'rag',
      );
    final provider = AskProvider(repository: repo);
    provider.start('user-1');
    await provider.submit('Why did food spending jump?');
    expect(repo.lastHistory, isEmpty);
    await provider.submit('What about Daraz?');
    expect(repo.lastHistory, hasLength(1));
    expect(repo.lastHistory.single.question, 'Why did food spending jump?');
    expect(repo.lastHistory.single.answer, contains('KFC'));
    provider.dispose();
  });

  test('askPeriodLabel uses a narrowed window', () {
    final l10n = AppLocalizationsEn();
    expect(
      askPeriodLabel(l10n, windowFrom: '2026-09-07', windowTo: '2026-09-07'),
      'Sep 7',
    );
    expect(askPeriodLabel(l10n), l10n.askLast12Months);
  });
}
