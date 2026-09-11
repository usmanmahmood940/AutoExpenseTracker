import 'package:equatable/equatable.dart';

class AgentProposalStepEntity extends Equatable {
  const AgentProposalStepEntity({
    required this.op,
    this.ref,
    this.amount,
    this.type,
    this.merchant,
    this.category,
    this.date,
    this.currency,
    this.note,
    this.primaryRef,
    this.sourceRefs = const [],
    this.primaryTransactionId,
    this.sourceTransactionIds = const [],
    this.groupId,
    this.transactionId,
  });

  final String op;
  final String? ref;
  final double? amount;
  final String? type;
  final String? merchant;
  final String? category;
  final String? date;
  final String? currency;
  final String? note;
  final String? primaryRef;
  final List<String> sourceRefs;
  final String? primaryTransactionId;
  final List<String> sourceTransactionIds;
  final String? groupId;
  final String? transactionId;

  factory AgentProposalStepEntity.fromJson(Map<String, dynamic> json) {
    return AgentProposalStepEntity(
      op: json['op']?.toString() ?? '',
      ref: json['ref']?.toString(),
      amount: (json['amount'] as num?)?.toDouble(),
      type: json['type']?.toString(),
      merchant: json['merchant']?.toString(),
      category: json['category']?.toString(),
      date: json['date']?.toString(),
      currency: json['currency']?.toString(),
      note: json['note']?.toString(),
      primaryRef: json['primary_ref']?.toString(),
      sourceRefs: _stringList(json['source_refs']),
      primaryTransactionId: json['primary_transaction_id']?.toString(),
      sourceTransactionIds: _stringList(json['source_transaction_ids']),
      groupId: json['group_id']?.toString(),
      transactionId: json['transaction_id']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
    op,
    ref,
    amount,
    type,
    merchant,
    category,
    date,
    currency,
    note,
    primaryRef,
    sourceRefs,
    primaryTransactionId,
    sourceTransactionIds,
    groupId,
    transactionId,
  ];
}

class AgentProposalEntity extends Equatable {
  const AgentProposalEntity({
    required this.proposalId,
    required this.status,
    required this.intent,
    required this.steps,
    required this.summary,
    this.expiresAt,
    this.model,
  });

  final String proposalId;
  final String status;
  final String intent;
  final List<AgentProposalStepEntity> steps;
  final String summary;
  final String? expiresAt;
  final String? model;

  bool get isPending => status == 'pending_confirmation';

  factory AgentProposalEntity.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'];
    final steps = rawSteps is List
        ? rawSteps
              .whereType<Map>()
              .map(
                (item) => AgentProposalStepEntity.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : const <AgentProposalStepEntity>[];
    return AgentProposalEntity(
      proposalId: json['proposal_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      intent: json['intent']?.toString() ?? '',
      steps: steps,
      summary: json['summary']?.toString() ?? '',
      expiresAt: json['expires_at']?.toString(),
      model: json['model']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
    proposalId,
    status,
    intent,
    steps,
    summary,
    expiresAt,
    model,
  ];
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map((item) => item.toString()).where((s) => s.isNotEmpty).toList();
}
