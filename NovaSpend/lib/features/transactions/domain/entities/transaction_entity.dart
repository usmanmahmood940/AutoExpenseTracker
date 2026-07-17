import 'package:equatable/equatable.dart';

class SmsSourceEntity extends Equatable {
  const SmsSourceEntity({
    required this.raw,
    required this.source,
    this.receivedAt,
    this.messageId,
    this.idempotencyKey,
  });

  final String raw;
  final String source;
  final DateTime? receivedAt;
  final String? messageId;
  final String? idempotencyKey;

  @override
  List<Object?> get props => [raw, source, receivedAt, messageId, idempotencyKey];
}

class TransactionEntity extends Equatable {
  const TransactionEntity({
    required this.id,
    required this.userId,
    required this.amount,
    required this.currency,
    required this.type,
    required this.merchant,
    this.merchantDetails,
    this.merchantNormalized,
    this.isRecurring = false,
    this.recurringGroupId,
    required this.category,
    required this.categorySource,
    required this.paymentMethod,
    required this.bank,
    required this.accountId,
    required this.accountIdMasked,
    this.branch,
    required this.transactionTime,
    required this.transactionDate,
    required this.day,
    this.externalId,
    required this.externalIdType,
    required this.dedupKey,
    required this.smsSource,
    required this.parseConfidence,
    required this.isAutoDetected,
    required this.isEdited,
    required this.isDuplicate,
    required this.status,
    this.reviewedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final double amount;
  final String currency;
  final String type;
  final String merchant;
  final String? merchantDetails;
  /// Normalized merchant key (Phase C). Falls back to derived key when null.
  final String? merchantNormalized;
  final bool isRecurring;
  final String? recurringGroupId;
  final String category;
  final String categorySource;
  final String paymentMethod;
  final String bank;
  final String accountId;
  final String accountIdMasked;
  final String? branch;
  final String transactionTime;
  final String transactionDate;
  final String day;
  final String? externalId;
  final String externalIdType;
  final String dedupKey;
  final SmsSourceEntity smsSource;
  final double parseConfidence;
  final bool isAutoDetected;
  final bool isEdited;
  final bool isDuplicate;
  final String status;
  final DateTime? reviewedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get needsConfidenceReview =>
      parseConfidence < 0.8 && reviewedAt == null && status != 'deleted';

  /// Effective key for merchant grouping / navigation.
  String get resolvedMerchantKey {
    final stored = merchantNormalized;
    if (stored != null && stored.trim().isNotEmpty) {
      return stored.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    }
    return merchant.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  TransactionEntity copyWith({
    String? merchant,
    double? amount,
    String? category,
    String? type,
    String? categorySource,
    bool? isEdited,
    String? status,
    DateTime? reviewedAt,
    DateTime? updatedAt,
  }) {
    return TransactionEntity(
      id: id,
      userId: userId,
      amount: amount ?? this.amount,
      currency: currency,
      type: type ?? this.type,
      merchant: merchant ?? this.merchant,
      merchantDetails: merchantDetails,
      merchantNormalized: merchantNormalized,
      isRecurring: isRecurring,
      recurringGroupId: recurringGroupId,
      category: category ?? this.category,
      categorySource: categorySource ?? this.categorySource,
      paymentMethod: paymentMethod,
      bank: bank,
      accountId: accountId,
      accountIdMasked: accountIdMasked,
      branch: branch,
      transactionTime: transactionTime,
      transactionDate: transactionDate,
      day: day,
      externalId: externalId,
      externalIdType: externalIdType,
      dedupKey: dedupKey,
      smsSource: smsSource,
      parseConfidence: parseConfidence,
      isAutoDetected: isAutoDetected,
      isEdited: isEdited ?? this.isEdited,
      isDuplicate: isDuplicate,
      status: status ?? this.status,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        amount,
        currency,
        type,
        merchant,
        merchantDetails,
        merchantNormalized,
        isRecurring,
        recurringGroupId,
        category,
        categorySource,
        paymentMethod,
        bank,
        accountId,
        accountIdMasked,
        branch,
        transactionTime,
        transactionDate,
        day,
        externalId,
        externalIdType,
        dedupKey,
        smsSource,
        parseConfidence,
        isAutoDetected,
        isEdited,
        isDuplicate,
        status,
        reviewedAt,
        createdAt,
        updatedAt,
      ];
}
