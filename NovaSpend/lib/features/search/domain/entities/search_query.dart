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
    this.categories = const [],
    this.amountMin,
    this.amountMax,
    this.paymentMethods = const [],
    this.sources = const [],
  });

  final String text;
  final DateRangePreset? datePreset;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final TransactionSort sort;
  final bool debitsOnly;
  final bool creditsOnly;
  final bool subscriptionsOnly;

  /// Display names of selected categories. Empty means all categories.
  final List<String> categories;
  final double? amountMin;
  final double? amountMax;

  /// Canonical payment-method keys. Empty means all methods.
  final List<String> paymentMethods;

  /// Ingestion source keys (`ios_shortcut`, `gmail`, `manual`). Empty means all.
  final List<String> sources;

  static const empty = SearchQuery();

  bool get hasText => text.trim().isNotEmpty;

  bool get hasDateRange => dateFrom != null && dateTo != null;

  bool get hasCategories => categories.isNotEmpty;

  bool get hasAmountRange => amountMin != null || amountMax != null;

  bool get hasPaymentMethods => paymentMethods.isNotEmpty;

  bool get hasSources => sources.isNotEmpty;

  /// Filters owned by the extra-filters sheet (not date/category chips).
  bool get hasSheetFilters =>
      hasAmountRange ||
      debitsOnly ||
      creditsOnly ||
      hasPaymentMethods ||
      hasSources ||
      subscriptionsOnly;

  bool get hasActiveFilters =>
      hasText ||
      hasDateRange ||
      hasCategories ||
      hasSheetFilters ||
      subscriptionsOnly;

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
    List<String>? categories,
    bool clearCategories = false,
    double? amountMin,
    double? amountMax,
    bool clearAmountMin = false,
    bool clearAmountMax = false,
    List<String>? paymentMethods,
    bool clearPaymentMethods = false,
    List<String>? sources,
    bool clearSources = false,
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
      categories: clearCategories ? const [] : (categories ?? this.categories),
      amountMin: clearAmountMin ? null : (amountMin ?? this.amountMin),
      amountMax: clearAmountMax ? null : (amountMax ?? this.amountMax),
      paymentMethods: clearPaymentMethods
          ? const []
          : (paymentMethods ?? this.paymentMethods),
      sources: clearSources ? const [] : (sources ?? this.sources),
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
    categories,
    amountMin,
    amountMax,
    paymentMethods,
    sources,
  ];
}
