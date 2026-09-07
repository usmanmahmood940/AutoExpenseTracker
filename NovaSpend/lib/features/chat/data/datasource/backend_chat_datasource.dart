import 'package:nova_spend/core/http/api_client.dart';
import 'package:nova_spend/core/http/api_json.dart';
import 'package:nova_spend/features/chat/domain/entities/chat_answer_entity.dart';
import 'package:nova_spend/features/chat/domain/entities/chat_suggestion_entity.dart';

class BackendChatDatasource {
  BackendChatDatasource({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<List<ChatSuggestionEntity>> fetchSuggestions({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final json = await _api.get(
        '/chat/suggestions',
        query: compactQuery({'from': isoDate(from), 'to': isoDate(to)}),
        requireAuth: true,
      );
      return chatSuggestionsFromApi(json);
    } on ApiException catch (e) {
      throw e.toDataException();
    }
  }

  Future<ChatAnswerEntity> ask({
    required String question,
    DateTime? from,
    DateTime? to,
    List<({String question, String answer})> history = const [],
  }) async {
    try {
      final json = await _api.post(
        '/chat/ask',
        body: {
          'question': question,
          if (from != null) 'from': isoDate(from),
          if (to != null) 'to': isoDate(to),
          if (history.isNotEmpty)
            'history': [
              for (final turn in history.take(3))
                {
                  'question': _clipHistory(turn.question),
                  'answer': _clipHistory(turn.answer),
                },
            ],
        },
        requireAuth: true,
        timeout: ApiClient.chatTimeout,
      );
      return chatAnswerFromApi(json);
    } on ApiException catch (e) {
      throw e.toDataException();
    }
  }
}

String _clipHistory(String value) {
  final text = value.trim();
  if (text.length <= 500) return text;
  return text.substring(0, 500);
}
