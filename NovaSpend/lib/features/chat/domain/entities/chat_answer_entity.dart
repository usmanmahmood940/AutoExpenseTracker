import 'package:equatable/equatable.dart';
import 'package:nova_spend/features/chat/domain/entities/chat_citation_entity.dart';

class ChatAnswerEntity extends Equatable {
  const ChatAnswerEntity({
    required this.answer,
    this.citations = const [],
    this.confidence = 'low',
    this.source = 'none',
    this.model,
  });

  final String answer;
  final List<ChatCitationEntity> citations;
  final String confidence;
  final String source;
  final String? model;

  bool get isNavigation => source == 'navigation';

  @override
  List<Object?> get props => [answer, citations, confidence, source, model];
}
