import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';

/// One page of Activity search results, plus optional full-match aggregates.
class SearchPage {
  const SearchPage({
    required this.items,
    required this.hasMore,
    this.totalCount,
    this.totalSpent,
    this.totalReceived,
  });

  final List<TransactionEntity> items;
  final bool hasMore;

  /// Count / spent / received over the full match set, not this page.
  /// Null when the server omitted aggregates (later pages, or Firestore).
  final int? totalCount;
  final double? totalSpent;
  final double? totalReceived;
}
