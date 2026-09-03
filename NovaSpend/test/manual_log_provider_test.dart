import 'package:flutter_test/flutter_test.dart';
import 'package:nova_spend/core/errors/failures.dart';
import 'package:nova_spend/features/transactions/domain/entities/parsed_transaction_draft.dart';
import 'package:nova_spend/features/transactions/domain/entities/period_stats_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/raw_ingestion_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_filter.dart';
import 'package:nova_spend/features/transactions/domain/entities/transactions_page.dart';
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:nova_spend/features/transactions/domain/usecases/create_transaction.dart';
import 'package:nova_spend/features/transactions/domain/usecases/parse_transaction_text.dart';
import 'package:nova_spend/features/transactions/presentation/provider/manual_log_provider.dart';

class FakeManualLogRepo implements TransactionRepository {
  ParsedTransactionDraft? parseResult;
  Object? parseError;
  Object? createError;
  Map<String, dynamic>? createdFields;

  @override
  Future<ParsedTransactionDraft> parseText({
    required String uid,
    required String raw,
  }) async {
    if (parseError != null) throw parseError!;
    return parseResult!;
  }

  @override
  Future<String> createTransaction({
    required String uid,
    required Map<String, dynamic> fields,
  }) async {
    if (createError != null) throw createError!;
    createdFields = fields;
    return 'tx-1';
  }

  @override
  Future<String> createManualFromIngestion({
    required String uid,
    required String ingestionId,
    required Map<String, dynamic> transactionFields,
  }) => throw UnimplementedError();

  @override
  Future<TransactionEntity> getTransaction(String uid, String transactionId) =>
      throw UnimplementedError();

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
  }) => throw UnimplementedError();

  @override
  Future<void> deleteMerchantCategoryOverride({
    required String uid,
    required String merchantKey,
  }) => throw UnimplementedError();
}

void main() {
  late FakeManualLogRepo repo;
  late ManualLogProvider provider;

  setUp(() {
    repo = FakeManualLogRepo();
    provider = ManualLogProvider(
      parseTransactionText: ParseTransactionText(repo),
      createTransaction: CreateTransaction(repo),
    )..configure(uid: 'user-1', currency: 'PKR');
  });

  tearDown(() => provider.dispose());

  test('parse is blocked when paste text is empty', () async {
    final ok = await provider.parse();
    expect(ok, isFalse);
    expect(provider.pasteError, 'empty');
    expect(provider.mode, ManualLogMode.paste);
  });

  test(
    'save is blocked when amount, merchant, and category are missing',
    () async {
      provider.setMode(ManualLogMode.form);
      final ok = await provider.save();
      expect(ok, isFalse);
      expect(provider.amountError, 'invalid');
      expect(provider.merchantError, 'empty');
      expect(provider.categoryError, 'empty');
    },
  );

  test('save is blocked when category is not selected', () async {
    provider
      ..setMode(ManualLogMode.form)
      ..setMerchant('KFC')
      ..setAmountText('200');
    final ok = await provider.save();
    expect(ok, isFalse);
    expect(provider.categoryError, 'empty');
    expect(repo.createdFields, isNull);
  });

  test('successful parse prefills the form', () async {
    repo.parseResult = const ParsedTransactionDraft(
      ok: true,
      amount: 200,
      merchant: 'KFC',
      category: 'Food & Dining',
      type: 'debit',
      transactionDate: '2026-09-03',
      parseConfidence: 0.91,
    );
    provider.setPasteText('spent 200 at KFC');

    final ok = await provider.parse();
    expect(ok, isTrue);
    expect(provider.mode, ManualLogMode.form);
    expect(provider.merchant, 'KFC');
    expect(provider.amount, 200);
    expect(provider.category, 'Food & Dining');
    expect(provider.note, 'spent 200 at KFC');
    expect(provider.parseConfidence, 0.91);
  });

  test('parse failure switches to form and keeps the raw note', () async {
    repo.parseResult = const ParsedTransactionDraft(
      ok: false,
      error: 'Could not parse',
    );
    provider.setPasteText('asdf');

    final ok = await provider.parse();
    expect(ok, isFalse);
    expect(provider.mode, ManualLogMode.form);
    expect(provider.bannerMessage, 'parseFailed');
    expect(provider.note, 'asdf');
  });

  test('network errors keep the pasted draft', () async {
    repo.parseError = const NetworkFailure('Network error. Please try again.');
    provider.setPasteText('spent 200 at KFC');

    final ok = await provider.parse();
    expect(ok, isFalse);
    expect(provider.mode, ManualLogMode.paste);
    expect(provider.pasteText, 'spent 200 at KFC');
    expect(provider.actionError, isA<NetworkFailure>());
  });

  test('save posts structured fields', () async {
    provider
      ..setMode(ManualLogMode.form)
      ..setMerchant('KFC')
      ..setAmountText('199.5')
      ..setCategory('Food & Dining')
      ..setTransactionDate('2026-09-03');

    final ok = await provider.save();
    expect(ok, isTrue);
    expect(repo.createdFields?['merchant'], 'KFC');
    expect(repo.createdFields?['amount'], 199.5);
    expect(repo.createdFields?['transactionDate'], '2026-09-03');
  });
}
