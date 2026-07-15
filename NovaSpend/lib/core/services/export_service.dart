import 'dart:io';

import 'package:csv/csv.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Builds a CSV from transactions and opens the system share sheet.
class ExportService {
  Future<void> exportTransactionsCsv(List<TransactionEntity> transactions) async {
    final rows = <List<dynamic>>[
      [
        'id',
        'date',
        'time',
        'merchant',
        'amount',
        'currency',
        'type',
        'category',
        'bank',
        'account',
        'status',
      ],
      ...transactions.map(
        (t) => [
          t.id,
          t.transactionDate,
          t.transactionTime,
          t.merchant,
          t.amount,
          t.currency,
          t.type,
          t.category,
          t.bank,
          t.accountIdMasked,
          t.status,
        ],
      ),
    ];

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/novaspend_export_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(csv);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'NovaSpend export'),
    );
  }
}
