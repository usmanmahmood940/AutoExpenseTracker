import 'package:flutter_test/flutter_test.dart';
import 'package:nova_spend/core/http/api_json.dart';
import 'package:nova_spend/features/search/domain/entities/transaction_sort.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';

TransactionEntity _tx({
  required String id,
  required String date,
  required String time,
  String merchant = 'Shop',
  double amount = 10,
}) {
  return transactionFromApi({
    'id': id,
    'user_id': 'user-1',
    'amount': amount,
    'currency': 'PKR',
    'type': 'debit',
    'merchant': merchant,
    'category': 'Food & Dining',
    'category_source': 'rule',
    'payment_method': 'card',
    'bank': 'HBL',
    'account_id': '',
    'account_id_masked': 'xxxx1215',
    'transaction_time': time,
    'transaction_date': date,
    'day': 'Thursday',
    'external_id_type': 'unknown',
    'dedup_key': id,
    'sms_source': {'raw': '', 'source': 'manual'},
    'parse_confidence': 1,
    'is_auto_detected': false,
    'is_edited': false,
    'is_duplicate': false,
    'status': 'active',
  });
}

void main() {
  test('date newest sorts same-day rows by time, matching Home', () {
    final morning = _tx(id: 'a', date: '2026-09-03', time: '09:00');
    final evening = _tx(id: 'b', date: '2026-09-03', time: '18:30');
    final yesterday = _tx(
      id: 'c',
      date: '2026-09-02',
      time: '23:59',
    );

    final sorted = sortTransactions(
      [morning, yesterday, evening],
      TransactionSort.dateNewest,
    );

    expect(sorted.map((tx) => tx.id), ['b', 'a', 'c']);
    expect(
      TransactionSort.dateNewest.compare(evening, morning),
      TransactionEntity.compareNewestFirst(evening, morning),
    );
  });

  test('date oldest sorts same-day rows by time ascending', () {
    final morning = _tx(id: 'a', date: '2026-09-03', time: '09:00');
    final evening = _tx(id: 'b', date: '2026-09-03', time: '18:30');
    final yesterday = _tx(
      id: 'c',
      date: '2026-09-02',
      time: '23:59',
    );

    final sorted = sortTransactions(
      [evening, yesterday, morning],
      TransactionSort.dateOldest,
    );

    expect(sorted.map((tx) => tx.id), ['c', 'a', 'b']);
  });

  test('ISO transactionTime is used when clock time is absent', () {
    final earlier = _tx(
      id: 'a',
      date: '2026-09-03',
      time: '2026-09-03T11:00:00+05:00',
    );
    final later = _tx(
      id: 'b',
      date: '2026-09-03',
      time: '2026-09-03T19:44:00+05:00',
    );

    expect(
      sortTransactions([earlier, later], TransactionSort.dateNewest)
          .map((tx) => tx.id),
      ['b', 'a'],
    );
  });
}
