import 'package:flutter/material.dart';

/// Maps a transaction category name to a Material icon for list/avatars.
///
/// Matching is keyword-based and case-insensitive so it works for both the
/// canonical category ids (e.g. `food_dining`) and human labels (e.g.
/// "Food & Dining"). Falls back to a generic receipt icon.
IconData categoryIcon(String? category) {
  final key = (category ?? '').toLowerCase();

  bool has(List<String> words) => words.any(key.contains);

  if (has(['food', 'dining', 'restaurant'])) return Icons.restaurant;
  if (has(['grocery', 'groceries', 'supermarket'])) {
    return Icons.local_grocery_store;
  }
  if (has(['shopping', 'retail'])) return Icons.shopping_bag;
  if (has(['fuel', 'petrol', 'gas'])) return Icons.local_gas_station;
  if (has(['transport', 'ride', 'taxi', 'cab'])) {
    return Icons.directions_car;
  }
  if (has(['travel', 'flight', 'hotel'])) return Icons.flight;
  if (has(['bill', 'utility', 'utilities'])) return Icons.receipt_long;
  if (has(['subscription', 'streaming'])) return Icons.subscriptions;
  if (has(['health', 'medical', 'pharmacy', 'doctor'])) {
    return Icons.medical_services;
  }
  if (has(['education', 'school', 'tuition', 'course'])) return Icons.school;
  if (has(['rent', 'housing', 'mortgage'])) return Icons.home;
  if (has(['transfer', 'send', 'wallet'])) return Icons.swap_horiz;
  if (has(['cash', 'atm', 'withdraw'])) return Icons.local_atm;
  if (has(['fee', 'charge', 'tax'])) return Icons.request_quote;
  if (has(['donation', 'zakat', 'charity'])) return Icons.volunteer_activism;
  if (has(['personal', 'care', 'salon', 'beauty'])) return Icons.spa;
  if (has(['income', 'salary', 'payroll'])) return Icons.payments;
  if (has(['refund', 'reversal', 'cashback'])) return Icons.replay;
  if (has(['entertainment', 'movie', 'game'])) return Icons.sports_esports;

  return Icons.receipt_long;
}
