import 'package:equatable/equatable.dart';
import 'package:nova_spend/core/constants/app_constants.dart';

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

  /// Instant this transaction occurred, used to sort newest-first.
  /// Prefers [transactionTime] (ISO or `HH:mm`), then [transactionDate], then [createdAt].
  DateTime? get occurredAt {
    final time = transactionTime.trim();
    if (time.isNotEmpty) {
      final iso = DateTime.tryParse(time);
      if (iso != null) return iso;

      final clock = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(time);
      if (clock != null) {
        final date = DateTime.tryParse(transactionDate);
        if (date != null) {
          return DateTime(
            date.year,
            date.month,
            date.day,
            int.parse(clock.group(1)!),
            int.parse(clock.group(2)!),
            int.parse(clock.group(3) ?? '0'),
          );
        }
      }
    }

    final date = DateTime.tryParse(transactionDate);
    if (date != null) return DateTime(date.year, date.month, date.day);
    return createdAt;
  }

  /// Newest transaction first. Ties fall back to [id] for a stable order.
  static int compareNewestFirst(TransactionEntity a, TransactionEntity b) {
    final ta = a.occurredAt;
    final tb = b.occurredAt;
    if (ta != null && tb != null) {
      final byTime = tb.compareTo(ta);
      if (byTime != 0) return byTime;
    } else if (tb != null) {
      return 1;
    } else if (ta != null) {
      return -1;
    }
    return b.id.compareTo(a.id);
  }

  /// Merchant shown in lists/detail. Cash withdrawals with no name are ATM.
  String get displayMerchant => resolveMerchant(
        merchant,
        category: category,
        paymentMethod: paymentMethod,
      );

  /// Effective key for merchant grouping / navigation.
  String get resolvedMerchantKey {
    final effective = displayMerchant;
    final stored = merchantNormalized;
    final merchantUnchanged =
        normalizeMerchantKey(effective) == normalizeMerchantKey(merchant);
    if (merchantUnchanged && stored != null && stored.trim().isNotEmpty) {
      return stored.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    }
    return normalizeMerchantKey(effective);
  }

  TransactionEntity copyWith({
    String? merchant,
    String? merchantDetails,
    bool clearMerchantDetails = false,
    double? amount,
    String? category,
    String? type,
    String? categorySource,
    String? paymentMethod,
    String? currency,
    String? bank,
    String? accountIdMasked,
    String? transactionTime,
    String? transactionDate,
    String? day,
    bool? isEdited,
    String? status,
    DateTime? reviewedAt,
    DateTime? updatedAt,
  }) {
    return TransactionEntity(
      id: id,
      userId: userId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      type: type ?? this.type,
      merchant: merchant ?? this.merchant,
      merchantDetails: clearMerchantDetails
          ? null
          : (merchantDetails ?? this.merchantDetails),
      merchantNormalized: merchantNormalized,
      isRecurring: isRecurring,
      recurringGroupId: recurringGroupId,
      category: category ?? this.category,
      categorySource: categorySource ?? this.categorySource,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      bank: bank ?? this.bank,
      accountId: accountId,
      accountIdMasked: accountIdMasked ?? this.accountIdMasked,
      branch: branch,
      transactionTime: transactionTime ?? this.transactionTime,
      transactionDate: transactionDate ?? this.transactionDate,
      day: day ?? this.day,
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
