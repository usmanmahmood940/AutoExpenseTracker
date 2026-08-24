import 'package:equatable/equatable.dart';
import 'package:nova_spend/features/search/domain/entities/date_range_preset.dart';
import 'package:nova_spend/features/search/domain/entities/transaction_sort.dart';

class SearchQuery extends Equatable {
  const SearchQuery({
    this.text = '',
    this.datePreset,
    this.dateFrom,
    this.dateTo,
    this.sort = TransactionSort.defaultSort,
    this.debitsOnly = false,
    this.creditsOnly = false,
    this.subscriptionsOnly = false,
  });

  final String text;
  final DateRangePreset? datePreset;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final TransactionSort sort;
  final bool debitsOnly;
  final bool creditsOnly;
  final bool subscriptionsOnly;

  static const empty = SearchQuery();

  bool get hasText => text.trim().isNotEmpty;

  bool get hasDateRange => dateFrom != null && dateTo != null;

  bool get hasActiveFilters =>
      hasText || hasDateRange || debitsOnly || creditsOnly || subscriptionsOnly;

  /// True when Reset all should show (filters or a non-default sort).
  bool get hasResettableState => hasActiveFilters || !sort.isDefault;

  String? get typeFilter {
    if (debitsOnly && !creditsOnly) return 'debit';
    if (creditsOnly && !debitsOnly) return 'credit';
    return null;
  }

  SearchQuery copyWith({
    String? text,
    DateRangePreset? datePreset,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool clearDateRange = false,
    TransactionSort? sort,
    bool? debitsOnly,
    bool? creditsOnly,
    bool? subscriptionsOnly,
  }) {
    return SearchQuery(
      text: text ?? this.text,
      datePreset: clearDateRange ? null : (datePreset ?? this.datePreset),
      dateFrom: clearDateRange ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateRange ? null : (dateTo ?? this.dateTo),
      sort: sort ?? this.sort,
      debitsOnly: debitsOnly ?? this.debitsOnly,
      creditsOnly: creditsOnly ?? this.creditsOnly,
      subscriptionsOnly: subscriptionsOnly ?? this.subscriptionsOnly,
    );
  }

  @override
  List<Object?> get props => [
    text,
    datePreset,
    dateFrom,
    dateTo,
    sort,
    debitsOnly,
    creditsOnly,
    subscriptionsOnly,
  ];
}
