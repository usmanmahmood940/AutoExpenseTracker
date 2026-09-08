import 'package:flutter_test/flutter_test.dart';
import 'package:nova_spend/core/http/api_json.dart';
import 'package:nova_spend/features/transactions/domain/entities/parsed_transaction_draft.dart';
import 'package:nova_spend/features/transactions/domain/entities/period_stats_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/raw_ingestion_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_filter.dart';
import 'package:nova_spend/features/transactions/domain/entities/transactions_page.dart';
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:nova_spend/features/transactions/domain/usecases/update_transaction.dart';
import 'package:nova_spend/features/transactions/presentation/provider/transaction_detail_provider.dart';

TransactionEntity _tx({required String raw, String source = 'sms'}) {
  return transactionFromApi({
    'id': 'tx-1',
    'user_id': 'user-1',
    'amount': 200,
    'currency': 'PKR',
    'type': 'debit',
    'merchant': 'PSO',
    'category': 'Fuel',
    'category_source': 'rule',
    'payment_method': 'card',
    'bank': 'HBL',
    'account_id': '',
    'account_id_masked': 'xxxx1215',
    'transaction_time': '10:00',
    'transaction_date': '2026-09-03',
    'day': 'Thursday',
    'external_id_type': 'unknown',
    'dedup_key': 'tx-1',
    'sms_source': {'raw': raw, 'source': source},
    'parse_confidence': 0.9,
    'is_auto_detected': true,
    'is_edited': false,
    'is_duplicate': false,
    'status': 'active',
  });
}

class FakeDetailRepo implements TransactionRepository {
  FakeDetailRepo({this.detail, this.getError});

  TransactionEntity? detail;
  Object? getError;
  int getTransactionCalls = 0;

  @override
  Future<TransactionEntity> getTransaction(
    String uid,
    String transactionId,
  ) async {
    getTransactionCalls++;
    if (getError != null) throw getError!;
    return detail!;
  }

  @override
  Future<ParsedTransactionDraft> parseText({
    required String uid,
    required String raw,
  }) => throw UnimplementedError();

  @override
  Future<String> createTransaction({
    required String uid,
    required Map<String, dynamic> fields,
  }) => throw UnimplementedError();

  @override
  Future<String> createManualFromIngestion({
    required String uid,
    required String ingestionId,
    required Map<String, dynamic> transactionFields,
  }) => throw UnimplementedError();

  @override
  Future<TransactionsPage> getTransactionsPage(
    String uid, {
    int limit = 50,
    TransactionEntity? startAfter,
    TransactionFilter? filter,
    String? dateFrom,
    String? dateTo,
    String sortBy = 'date',
    String orderBy = 'desc',
  }) => throw UnimplementedError();

  @override
  Future<PeriodStatsEntity> getPeriodStats({
    required String period,
    required String from,
    required String to,
  }) => throw UnimplementedError();

  @override
  Future<void> updateTransaction(
    String uid,
    String transactionId,
    Map<String, dynamic> fields,
  ) => throw UnimplementedError();

  @override
  Future<List<TransactionEntity>> getNeedsReview(
    String uid, {
    int limit = 50,
  }) => throw UnimplementedError();

  @override
  Future<List<RawIngestionEntity>> getIngestionsByStatus(
    String uid,
    String status, {
    int limit = 50,
  }) => throw UnimplementedError();

  @override
  Future<int> getPendingReviewCount(String uid) => throw UnimplementedError();

  @override
  Future<void> markReviewed(String uid, String transactionId) =>
      throw UnimplementedError();

  @override
  Future<void> softDelete(String uid, String transactionId) =>
      throw UnimplementedError();

  @override
  Future<void> upsertMerchantCategoryOverride({
    required String uid,
    required String merchantKey,
    required String displayName,
    required String category,
  }) => throw UnimplementedError();

  @override
  Future<String?> getMerchantCategoryOverride({
    required String uid,
    required String merchantKey,
  }) async => null;

  @override
  Future<void> deleteMerchantCategoryOverride({
    required String uid,
    required String merchantKey,
  }) => throw UnimplementedError();
}

void main() {
  TransactionDetailProvider providerFor(FakeDetailRepo repo, TransactionEntity tx) {
    return TransactionDetailProvider(
      uid: 'user-1',
      transaction: tx,
      updateTransaction: UpdateTransaction(repo),
      repository: repo,
    );
  }

  test('loadFullTransaction fills decrypted SMS from detail GET', () async {
    final listed = _tx(raw: '');
    final repo = FakeDetailRepo(
      detail: _tx(raw: 'PKR 5,990 charged at PSO'),
    );
    final provider = providerFor(repo, listed);

    expect(provider.transaction.smsSource.raw, isEmpty);
    await provider.loadFullTransaction();

    expect(repo.getTransactionCalls, 1);
    expect(
      provider.transaction.smsSource.raw,
      'PKR 5,990 charged at PSO',
    );
    provider.dispose();
  });

  test('loadFullTransaction skips fetch when raw SMS is already present', () async {
    final detailed = _tx(raw: 'already decrypted');
    final repo = FakeDetailRepo(detail: detailed);
    final provider = providerFor(repo, detailed);

    await provider.loadFullTransaction();

    expect(repo.getTransactionCalls, 0);
    expect(provider.transaction.smsSource.raw, 'already decrypted');
    provider.dispose();
  });

  test('loadFullTransaction keeps list data when detail GET fails', () async {
    final listed = _tx(raw: '');
    final repo = FakeDetailRepo(getError: Exception('offline'));
    final provider = providerFor(repo, listed);

    await provider.loadFullTransaction();

    expect(repo.getTransactionCalls, 1);
    expect(provider.transaction.smsSource.raw, isEmpty);
    expect(provider.transaction.merchant, 'PSO');
    provider.dispose();
  });
}
