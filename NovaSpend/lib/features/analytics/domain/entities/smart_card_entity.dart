import 'package:equatable/equatable.dart';

class SmartCardEntity extends Equatable {
  const SmartCardEntity({
    required this.title,
    required this.body,
    required this.signalType,
    this.suggestedQuestion = '',
  });

  final String title;
  final String body;
  final String signalType;
  final String suggestedQuestion;

  String get askQuestion {
    final question = suggestedQuestion.trim();
    if (question.isNotEmpty) return question;
    return title;
  }

  @override
  List<Object?> get props => [title, body, signalType, suggestedQuestion];
}
