import 'package:nova_spend/features/chat/domain/entities/chat_answer_entity.dart';
import 'package:nova_spend/features/chat/domain/entities/chat_suggestion_entity.dart';

abstract class ChatRepository {
  Future<List<ChatSuggestionEntity>> getSuggestions(
    String uid, {
    required DateTime from,
    required DateTime to,
  });

  Future<ChatAnswerEntity> ask(
    String uid, {
    required String question,
    DateTime? from,
    DateTime? to,
  });
}
