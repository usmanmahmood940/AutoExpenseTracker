import 'package:equatable/equatable.dart';

class SearchQuery extends Equatable {
  const SearchQuery({
    this.text = '',
    this.thisMonth = false,
    this.debitsOnly = false,
    this.creditsOnly = false,
    this.subscriptionsOnly = false,
  });

  final String text;
  final bool thisMonth;
  final bool debitsOnly;
  final bool creditsOnly;
  final bool subscriptionsOnly;

  static const empty = SearchQuery();

  bool get hasText => text.trim().isNotEmpty;

  bool get hasActiveFilters =>
      hasText ||
      thisMonth ||
      debitsOnly ||
      creditsOnly ||
      subscriptionsOnly;

  String? get typeFilter {
    if (debitsOnly && !creditsOnly) return 'debit';
    if (creditsOnly && !debitsOnly) return 'credit';
    return null;
  }

  SearchQuery copyWith({
    String? text,
    bool? thisMonth,
    bool? debitsOnly,
    bool? creditsOnly,
    bool? subscriptionsOnly,
  }) {
    return SearchQuery(
      text: text ?? this.text,
      thisMonth: thisMonth ?? this.thisMonth,
      debitsOnly: debitsOnly ?? this.debitsOnly,
      creditsOnly: creditsOnly ?? this.creditsOnly,
      subscriptionsOnly: subscriptionsOnly ?? this.subscriptionsOnly,
    );
  }

  @override
  List<Object?> get props => [
        text,
        thisMonth,
        debitsOnly,
        creditsOnly,
        subscriptionsOnly,
      ];
}
