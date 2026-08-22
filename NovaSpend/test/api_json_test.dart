import 'package:flutter_test/flutter_test.dart';
import 'package:nova_spend/core/http/api_json.dart';

void main() {
  test('transactionFromApi maps snake_case FastAPI payload', () {
    final tx = transactionFromApi({
      'id': '11111111-1111-1111-1111-111111111111',
      'user_id': '22222222-2222-2222-2222-222222222222',
      'amount': 99.5,
      'currency': 'PKR',
      'type': 'debit',
      'merchant': 'PSO',
      'merchant_details': null,
      'merchant_normalized': 'pso',
      'is_recurring': false,
      'category': 'Fuel',
      'category_source': 'ai',
      'payment_method': 'card',
      'bank': 'HBL',
      'account_id': '',
      'account_id_masked': 'xxxx1215',
      'transaction_time': '11:27',
      'transaction_date': '2026-07-06',
      'day': 'Monday',
      'external_id_type': 'unknown',
      'dedup_key': 'abc',
      'sms_source': {'raw': 'PKR 99', 'source': 'ios_shortcut'},
      'parse_confidence': 0.9,
      'is_auto_detected': true,
      'is_edited': false,
      'is_duplicate': false,
      'status': 'active',
    });

    expect(tx.merchant, 'PSO');
    expect(tx.merchantNormalized, 'pso');
    expect(tx.amount, 99.5);
    expect(tx.transactionDate, '2026-07-06');
    expect(tx.smsSource.raw, 'PKR 99');
  });

  test('periodStatsFromApi maps comparison and highlights', () {
    final stats = periodStatsFromApi({
      'period': 'week',
      'from': '2026-08-17',
      'to': '2026-08-21',
      'currency': 'PKR',
      'spent': 100,
      'received': 20,
      'net': -80,
      'highest_spend': {
        'id': 'tx-1',
        'amount': 50,
        'merchant': 'PSO',
        'merchant_normalized': 'pso',
        'category': 'Fuel',
        'transaction_date': '2026-08-20',
        'type': 'debit',
        'currency': 'PKR',
      },
      'comparison': {
        'spent_change_percent': 10,
        'received_change_percent': -5,
        'net_change_percent': 12,
      },
    });

    expect(stats.spent, 100);
    expect(stats.highestSpend?.merchant, 'PSO');
    expect(stats.comparison?.spentChangePercent, 10);
  });

  test('transactionPatchFromClient remaps camelCase and drops FieldValue-like values', () {
    final patch = transactionPatchFromClient({
      'merchant': 'PSO',
      'merchantDetails': 'Lahore',
      'accountIdMasked': 'xxxx',
      'paymentMethod': 'card',
      'transactionDate': '2026-08-21',
      'isEdited': true,
      'updatedAt': Object(),
    });

    expect(patch['merchant'], 'PSO');
    expect(patch['merchant_details'], 'Lahore');
    expect(patch['account_id_masked'], 'xxxx');
    expect(patch['payment_method'], 'card');
    expect(patch['transaction_date'], '2026-08-21');
    expect(patch.containsKey('isEdited'), isFalse);
    expect(patch.containsKey('updatedAt'), isFalse);
  });
}
