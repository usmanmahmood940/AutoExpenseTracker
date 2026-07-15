import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';

/// Lightweight recurring detection: same merchant + similar amount within ~30 days.
class RecurringDetector {
  RecurringDetector._();

  static const similarAmountRatio = 0.05; // 5%

  /// Returns merchant names that appear 2+ times with similar debit amounts.
  static List<String> detectSubscriptionMerchants(
    List<TransactionEntity> transactions,
  ) {
    final debits = transactions
        .where((t) => t.type == 'debit' && t.status != 'deleted')
        .toList();

    final byMerchant = <String, List<TransactionEntity>>{};
    for (final tx in debits) {
      final key = tx.merchant.trim().toLowerCase();
      if (key.isEmpty) continue;
      byMerchant.putIfAbsent(key, () => []).add(tx);
    }

    final hits = <String>[];
    for (final entry in byMerchant.entries) {
      final list = entry.value;
      if (list.length < 2) continue;
      list.sort((a, b) => a.transactionDate.compareTo(b.transactionDate));
      for (var i = 1; i < list.length; i++) {
        final prev = list[i - 1];
        final curr = list[i];
        final avg = (prev.amount + curr.amount) / 2;
        if (avg <= 0) continue;
        final diff = (prev.amount - curr.amount).abs() / avg;
        if (diff <= similarAmountRatio) {
          hits.add(list.first.merchant);
          break;
        }
      }
    }
    return hits;
  }
}

/// Year-month helper used by insights / budgets.
String yearMonthNow([DateTime? now]) {
  final d = now ?? DateTime.now();
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
}

Timestamp? parseFirestoreTimestamp(dynamic value) {
  if (value is Timestamp) return value;
  return null;
}
