import 'package:nova_spend/core/constants/currencies.dart';
import 'package:nova_spend/core/constants/payment_methods.dart';
import 'package:nova_spend/features/analytics/domain/entities/monthly_summary_entity.dart';
import 'package:nova_spend/features/analytics/domain/entities/recurring_merchant_entity.dart';
import 'package:nova_spend/features/analytics/domain/entities/trend_point_entity.dart';
import 'package:nova_spend/features/categories/domain/entities/category_entity.dart';
import 'package:nova_spend/features/merchants/domain/entities/merchant_summary_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/period_stats_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/raw_ingestion_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';

DateTime? parseApiDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String isoDate(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

Map<String, String> compactQuery(Map<String, String?> raw) {
  final out = <String, String>{};
  raw.forEach((key, value) {
    if (value != null && value.isNotEmpty) {
      out[key] = value;
    }
  });
  return out;
}

TransactionEntity transactionFromApi(Map<String, dynamic> json) {
  final smsRaw = json['sms_source'];
  final sms = smsRaw is Map
      ? Map<String, dynamic>.from(smsRaw)
      : <String, dynamic>{};
  return TransactionEntity(
    id: json['id']?.toString() ?? '',
    userId: json['user_id']?.toString() ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    currency: normalizeCurrency(json['currency'] as String? ?? 'PKR'),
    type: json['type'] as String? ?? 'debit',
    merchant: json['merchant'] as String? ?? '',
    merchantDetails: json['merchant_details'] as String?,
    merchantNormalized: json['merchant_normalized'] as String?,
    isRecurring: json['is_recurring'] as bool? ?? false,
    recurringGroupId: json['recurring_group_id'] as String?,
    category: json['category'] as String? ?? 'Uncategorized',
    categorySource: json['category_source'] as String? ?? 'rule',
    paymentMethod: normalizePaymentMethod(
      json['payment_method'] as String? ?? '',
    ),
    bank: json['bank'] as String? ?? '',
    accountId: json['account_id'] as String? ?? '',
    accountIdMasked: json['account_id_masked'] as String? ?? '',
    branch: json['branch'] as String?,
    transactionTime: json['transaction_time'] as String? ?? '',
    transactionDate: json['transaction_date'] as String? ?? '',
    day: json['day'] as String? ?? '',
    externalId: json['external_id'] as String?,
    externalIdType: json['external_id_type'] as String? ?? 'unknown',
    dedupKey: json['dedup_key'] as String? ?? '',
    smsSource: SmsSourceEntity(
      raw: sms['raw'] as String? ?? '',
      source: sms['source'] as String? ?? 'manual',
      receivedAt: parseApiDateTime(sms['received_at']),
      messageId: sms['message_id'] as String?,
      idempotencyKey: sms['idempotency_key'] as String?,
    ),
    parseConfidence: (json['parse_confidence'] as num?)?.toDouble() ?? 1,
    isAutoDetected: json['is_auto_detected'] as bool? ?? false,
    isEdited: json['is_edited'] as bool? ?? false,
    isDuplicate: json['is_duplicate'] as bool? ?? false,
    status: json['status'] as String? ?? 'active',
    reviewedAt: parseApiDateTime(json['reviewed_at']),
    createdAt: parseApiDateTime(json['created_at']),
    updatedAt: parseApiDateTime(json['updated_at']),
  );
}

RawIngestionEntity ingestionFromApi(Map<String, dynamic> json) {
  return RawIngestionEntity(
    id: json['id']?.toString() ?? '',
    userId: json['user_id']?.toString() ?? '',
    raw: json['raw'] as String? ?? '',
    source: json['source'] as String? ?? 'manual',
    receivedAt: parseApiDateTime(json['received_at']),
    messageId: json['message_id'] as String?,
    idempotencyKey: json['idempotency_key'] as String?,
    status: json['status'] as String? ?? 'received',
    transactionId: json['transaction_id']?.toString(),
    error: json['error'] as String?,
    createdAt: parseApiDateTime(json['created_at']),
    updatedAt: parseApiDateTime(json['updated_at']),
  );
}

PeriodHighlight? highlightFromApi(dynamic raw) {
  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  final id = map['id']?.toString();
  if (id == null || id.isEmpty) return null;
  return PeriodHighlight(
    id: id,
    amount: (map['amount'] as num?)?.toDouble() ?? 0,
    merchant: map['merchant'] as String? ?? '',
    merchantNormalized: map['merchant_normalized'] as String? ?? '',
    category: map['category'] as String? ?? 'Uncategorized',
    transactionDate: map['transaction_date'] as String? ?? '',
    type: map['type'] as String? ?? 'debit',
    currency: map['currency'] as String? ?? 'PKR',
  );
}

PeriodStatsEntity periodStatsFromApi(Map<String, dynamic> json) {
  PeriodComparisonStats? comparison;
  final rawComparison = json['comparison'];
  if (rawComparison is Map) {
    final map = Map<String, dynamic>.from(rawComparison);
    comparison = PeriodComparisonStats(
      spentChangePercent:
          (map['spent_change_percent'] as num?)?.toDouble() ?? 0,
      receivedChangePercent:
          (map['received_change_percent'] as num?)?.toDouble() ?? 0,
      netChangePercent: (map['net_change_percent'] as num?)?.toDouble() ?? 0,
    );
  }
  return PeriodStatsEntity(
    period: json['period'] as String? ?? '',
    from: json['from'] as String? ?? '',
    to: json['to'] as String? ?? '',
    currency: json['currency'] as String? ?? 'PKR',
    spent: (json['spent'] as num?)?.toDouble() ?? 0,
    received: (json['received'] as num?)?.toDouble() ?? 0,
    net: (json['net'] as num?)?.toDouble() ?? 0,
    highestSpend: highlightFromApi(json['highest_spend']),
    highestReceive: highlightFromApi(json['highest_receive']),
    comparison: comparison,
  );
}

CategoryEntity categoryFromApi(Map<String, dynamic> json) {
  return CategoryEntity(
    id: json['id']?.toString() ?? json['slug']?.toString() ?? '',
    name: json['name'] as String? ?? '',
    type: json['type'] as String? ?? 'expense',
    icon: json['icon'] as String? ?? 'label',
    color: json['color'] as String? ?? '#757575',
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    isDefault: json['is_default'] as bool? ?? false,
    createdAt: parseApiDateTime(json['created_at']),
    updatedAt: parseApiDateTime(json['updated_at']),
  );
}

MerchantSummaryEntity merchantSummaryFromApi(Map<String, dynamic> json) {
  return MerchantSummaryEntity(
    merchantNormalized: json['merchant_normalized'] as String? ?? '',
    displayName: json['display_name'] as String? ?? '',
    currency: json['currency'] as String? ?? 'PKR',
    totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0,
    visitCount: (json['visit_count'] as num?)?.toInt() ?? 0,
    averageSpent: (json['average_spent'] as num?)?.toDouble() ?? 0,
    thisMonthSpent: (json['this_month_spent'] as num?)?.toDouble() ?? 0,
    thisMonthVisits: (json['this_month_visits'] as num?)?.toInt() ?? 0,
  );
}

MonthlySummaryEntity monthlySummaryFromApi(Map<String, dynamic> json) {
  Map<String, double> numMap(dynamic raw) {
    if (raw is! Map) return {};
    return raw.map(
      (key, value) => MapEntry(
        key.toString(),
        (value as num?)?.toDouble() ?? 0,
      ),
    );
  }

  Map<String, MerchantSpendStat> statsMap(dynamic raw) {
    if (raw is! Map) return {};
    final out = <String, MerchantSpendStat>{};
    raw.forEach((key, value) {
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        out[key.toString()] = MerchantSpendStat(
          amount: (map['amount'] as num?)?.toDouble() ?? 0,
          visitCount: (map['visit_count'] as num?)?.toInt() ?? 0,
          merchantNormalized: map['merchant_normalized'] as String? ??
              key.toString().toLowerCase(),
        );
      }
    });
    return out;
  }

  return MonthlySummaryEntity(
    yearMonth: json['year_month'] as String? ?? '',
    dateFrom: json['date_from'] as String?,
    dateTo: json['date_to'] as String?,
    currency: json['currency'] as String? ?? 'PKR',
    totalDebit: (json['total_debit'] as num?)?.toDouble() ?? 0,
    totalCredit: (json['total_credit'] as num?)?.toDouble() ?? 0,
    net: (json['net'] as num?)?.toDouble() ?? 0,
    transactionCount: (json['transaction_count'] as num?)?.toInt() ?? 0,
    byCategory: numMap(json['by_category']),
    byMerchant: numMap(json['by_merchant']),
    byMerchantStats: statsMap(json['by_merchant_stats']),
    byMerchantReceived: numMap(json['by_merchant_received']),
    byMerchantReceivedStats: statsMap(json['by_merchant_received_stats']),
  );
}

List<TrendPointEntity> trendPointsFromApi(Map<String, dynamic> json) {
  final raw = json['points'];
  if (raw is! List) return const [];
  return raw.whereType<Map>().map((item) {
    final map = Map<String, dynamic>.from(item);
    final parsed = DateTime.tryParse(map['date'] as String? ?? '');
    return TrendPointEntity(
      date: parsed ?? DateTime(1970),
      debit: (map['debit'] as num?)?.toDouble() ?? 0,
    );
  }).toList();
}

List<RecurringMerchantEntity> recurringMerchantsFromApi(
  Map<String, dynamic> json,
) {
  final raw = json['items'];
  if (raw is! List) return const [];
  return raw.whereType<Map>().map((item) {
    final map = Map<String, dynamic>.from(item);
    final parsed = DateTime.tryParse(map['last_date'] as String? ?? '');
    return RecurringMerchantEntity(
      displayName: map['display_name'] as String? ?? '',
      merchantNormalized: map['merchant_normalized'] as String? ?? '',
      count: (map['count'] as num?)?.toInt() ?? 0,
      averageAmount: (map['average_amount'] as num?)?.toDouble() ?? 0,
      lastDate: parsed ?? DateTime(1970),
    );
  }).toList();
}

String? narrativeFromApi(Map<String, dynamic> json) {
  final text = json['narrative'] as String?;
  if (text == null || text.trim().isEmpty) return null;
  return text.trim();
}

/// Maps Flutter/Firestore camelCase patch fields to FastAPI snake_case.
Map<String, dynamic> transactionPatchFromClient(Map<String, dynamic> fields) {
  const rename = {
    'merchantDetails': 'merchant_details',
    'accountId': 'account_id',
    'accountIdMasked': 'account_id_masked',
    'paymentMethod': 'payment_method',
    'transactionDate': 'transaction_date',
    'transactionTime': 'transaction_time',
    'categorySource': 'category_source',
  };
  const skip = {
    'isEdited',
    'updatedAt',
    'reviewedAt',
    'userId',
    'merchantNormalized',
    'createdAt',
  };
  final out = <String, dynamic>{};
  fields.forEach((key, value) {
    if (skip.contains(key)) return;
    if (!_isJsonValue(value)) return;
    out[rename[key] ?? key] = value;
  });
  return out;
}

Map<String, dynamic> transactionCreateFromClient({
  required Map<String, dynamic> fields,
  String? ingestionId,
}) {
  final body = <String, dynamic>{
    'amount': fields['amount'],
    'merchant': fields['merchant'],
    'transaction_date': fields['transactionDate'] ?? fields['transaction_date'],
    if (fields['type'] != null) 'type': fields['type'],
    if (fields['category'] != null) 'category': fields['category'],
    if (fields['currency'] != null) 'currency': fields['currency'],
    if (fields['transactionTime'] != null)
      'transaction_time': fields['transactionTime'],
    if (fields['paymentMethod'] != null)
      'payment_method': fields['paymentMethod'],
    if (fields['bank'] != null) 'bank': fields['bank'],
    if (fields['accountId'] != null) 'account_id': fields['accountId'],
    if (fields['accountIdMasked'] != null)
      'account_id_masked': fields['accountIdMasked'],
    if (fields['merchantDetails'] != null)
      'merchant_details': fields['merchantDetails'],
    if (fields['branch'] != null) 'branch': fields['branch'],
    'category_source': fields['categorySource'] ?? 'user',
    if (ingestionId != null) 'ingestion_id': ingestionId,
  };
  body.removeWhere((_, value) => value == null);
  return body;
}

bool _isJsonValue(dynamic value) {
  return value == null ||
      value is num ||
      value is String ||
      value is bool ||
      value is List ||
      value is Map;
}
