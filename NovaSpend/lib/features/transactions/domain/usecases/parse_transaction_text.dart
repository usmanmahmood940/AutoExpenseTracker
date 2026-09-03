import 'package:nova_spend/features/transactions/domain/entities/parsed_transaction_draft.dart';
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';

class ParseTransactionText {
  ParseTransactionText(this._repository);

  final TransactionRepository _repository;

  Future<ParsedTransactionDraft> call({
    required String uid,
    required String raw,
  }) {
    return _repository.parseText(uid: uid, raw: raw);
  }
}
