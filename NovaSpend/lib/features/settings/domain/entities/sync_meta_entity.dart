import 'package:equatable/equatable.dart';

class SyncMetaEntity extends Equatable {
  const SyncMetaEntity({
    this.lastSyncedAt,
    this.lastMerchant,
    this.lastAmount,
    this.lastTransactionId,
  });

  final DateTime? lastSyncedAt;
  final String? lastMerchant;
  final double? lastAmount;
  final String? lastTransactionId;

  @override
  List<Object?> get props =>
      [lastSyncedAt, lastMerchant, lastAmount, lastTransactionId];
}
