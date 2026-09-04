import 'package:nova_spend/core/errors/failures.dart';
import 'package:nova_spend/features/chat/data/datasource/backend_chat_datasource.dart';
import 'package:nova_spend/features/chat/domain/entities/chat_answer_entity.dart';
import 'package:nova_spend/features/chat/domain/entities/chat_suggestion_entity.dart';
import 'package:nova_spend/features/chat/domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({required BackendChatDatasource backend})
    : _backend = backend;

  final BackendChatDatasource _backend;

  @override
  Future<List<ChatSuggestionEntity>> getSuggestions(
    String uid, {
    required DateTime from,
    required DateTime to,
  }) {
    return _map(_backend.fetchSuggestions(from: from, to: to));
  }

  @override
  Future<ChatAnswerEntity> ask(
    String uid, {
    required String question,
    DateTime? from,
    DateTime? to,
  }) {
    return _map(_backend.ask(question: question, from: from, to: to));
  }

  Future<T> _map<T>(Future<T> future) async {
    try {
      return await future;
    } catch (error) {
      throwAsFailure(error);
    }
  }
}
