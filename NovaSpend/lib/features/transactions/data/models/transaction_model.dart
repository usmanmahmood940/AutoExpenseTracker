import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nova_spend/features/transactions/domain/entities/raw_ingestion_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

class TransactionModel {
  TransactionModel(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;

  factory TransactionModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return TransactionModel(doc.id, doc.data() ?? {});
  }

  TransactionEntity toEntity() {
    final sms = data['smsSource'] as Map<String, dynamic>? ?? {};
    return TransactionEntity(
      id: id,
      userId: data['userId'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      currency: data['currency'] as String? ?? 'PKR',
      type: data['type'] as String? ?? 'debit',
      merchant: data['merchant'] as String? ?? '',
      merchantDetails: data['merchantDetails'] as String?,
      category: data['category'] as String? ?? 'Uncategorized',
      categorySource: data['categorySource'] as String? ?? 'rule',
      paymentMethod: data['paymentMethod'] as String? ?? '',
      bank: data['bank'] as String? ?? '',
      accountId: data['accountId'] as String? ?? '',
      accountIdMasked: data['accountIdMasked'] as String? ?? '',
      branch: data['branch'] as String?,
      transactionTime: data['transactionTime'] as String? ?? '',
      transactionDate: data['transactionDate'] as String? ?? '',
      day: data['day'] as String? ?? '',
      externalId: data['externalId'] as String?,
      externalIdType: data['externalIdType'] as String? ?? 'unknown',
      dedupKey: data['dedupKey'] as String? ?? '',
      smsSource: SmsSourceEntity(
        raw: sms['raw'] as String? ?? '',
        source: sms['source'] as String? ?? 'manual',
        receivedAt: _asDateTime(sms['receivedAt']),
        messageId: sms['messageId'] as String?,
        idempotencyKey: sms['idempotencyKey'] as String?,
      ),
      parseConfidence: (data['parseConfidence'] as num?)?.toDouble() ?? 1,
      isAutoDetected: data['isAutoDetected'] as bool? ?? false,
      isEdited: data['isEdited'] as bool? ?? false,
      isDuplicate: data['isDuplicate'] as bool? ?? false,
      status: data['status'] as String? ?? 'active',
      reviewedAt: _asDateTime(data['reviewedAt']),
      createdAt: _asDateTime(data['createdAt']),
      updatedAt: _asDateTime(data['updatedAt']),
    );
  }
}

class RawIngestionModel {
  RawIngestionModel(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;

  factory RawIngestionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return RawIngestionModel(doc.id, doc.data() ?? {});
  }

  RawIngestionEntity toEntity() {
    return RawIngestionEntity(
      id: id,
      userId: data['userId'] as String? ?? '',
      raw: data['raw'] as String? ?? '',
      source: data['source'] as String? ?? 'manual',
      receivedAt: _asDateTime(data['receivedAt']),
      messageId: data['messageId'] as String?,
      idempotencyKey: data['idempotencyKey'] as String?,
      status: data['status'] as String? ?? 'received',
      transactionId: data['transactionId'] as String?,
      error: data['error'] as String?,
      createdAt: _asDateTime(data['createdAt']),
      updatedAt: _asDateTime(data['updatedAt']),
    );
  }
}
