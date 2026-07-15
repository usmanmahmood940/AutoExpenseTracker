import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nova_spend/features/analytics/domain/entities/monthly_summary_entity.dart';

DateTime? _asDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

Map<String, double> _numMap(dynamic raw) {
  if (raw is! Map) return {};
  return raw.map(
    (key, value) => MapEntry(
      key.toString(),
      (value as num?)?.toDouble() ?? 0,
    ),
  );
}

class MonthlySummaryModel {
  MonthlySummaryModel(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;

  factory MonthlySummaryModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return MonthlySummaryModel(doc.id, doc.data() ?? {});
  }

  MonthlySummaryEntity toEntity() {
    return MonthlySummaryEntity(
      yearMonth: data['yearMonth'] as String? ?? id,
      currency: data['currency'] as String? ?? 'PKR',
      totalDebit: (data['totalDebit'] as num?)?.toDouble() ?? 0,
      totalCredit: (data['totalCredit'] as num?)?.toDouble() ?? 0,
      net: (data['net'] as num?)?.toDouble() ?? 0,
      transactionCount: (data['transactionCount'] as num?)?.toInt() ?? 0,
      byCategory: _numMap(data['byCategory']),
      byMerchant: _numMap(data['byMerchant']),
      updatedAt: _asDateTime(data['updatedAt']),
    );
  }
}
