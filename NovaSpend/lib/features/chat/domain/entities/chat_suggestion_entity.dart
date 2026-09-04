import 'package:equatable/equatable.dart';

class ChatSuggestionEntity extends Equatable {
  const ChatSuggestionEntity({
    required this.question,
    required this.signalType,
  });

  final String question;
  final String signalType;

  @override
  List<Object?> get props => [question, signalType];
}
