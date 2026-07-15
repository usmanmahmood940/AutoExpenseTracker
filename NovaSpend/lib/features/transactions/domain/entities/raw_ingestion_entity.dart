import 'package:equatable/equatable.dart';

class RawIngestionEntity extends Equatable {
  const RawIngestionEntity({
    required this.id,
    required this.userId,
    required this.raw,
    required this.source,
    this.receivedAt,
    this.messageId,
    this.idempotencyKey,
    required this.status,
    this.transactionId,
    this.error,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String raw;
  final String source;
  final DateTime? receivedAt;
  final String? messageId;
  final String? idempotencyKey;
  final String status;
  final String? transactionId;
  final String? error;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [
        id,
        userId,
        raw,
        source,
        receivedAt,
        messageId,
        idempotencyKey,
        status,
        transactionId,
        error,
        createdAt,
        updatedAt,
      ];
}
