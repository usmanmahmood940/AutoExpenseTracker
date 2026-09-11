import 'package:equatable/equatable.dart';
import 'package:nova_spend/features/chat/domain/entities/agent_proposal_entity.dart';
import 'package:nova_spend/features/chat/domain/entities/chat_citation_entity.dart';

class ChatAnswerEntity extends Equatable {
  const ChatAnswerEntity({
    required this.answer,
    this.citations = const [],
    this.confidence = 'low',
    this.source = 'none',
    this.model,
    this.filterTerm,
    this.windowFrom,
    this.windowTo,
    this.proposal,
  });

  final String answer;
  final List<ChatCitationEntity> citations;
  final String confidence;
  final String source;
  final String? model;
  final String? filterTerm;
  final String? windowFrom;
  final String? windowTo;
  final AgentProposalEntity? proposal;

  bool get isNavigation => source == 'navigation';

  bool get isLowConfidence => confidence == 'low';

  bool get hasProposal => proposal != null && proposal!.isPending;

  @override
  List<Object?> get props => [
    answer,
    citations,
    confidence,
    source,
    model,
    filterTerm,
    windowFrom,
    windowTo,
    proposal,
  ];
}
