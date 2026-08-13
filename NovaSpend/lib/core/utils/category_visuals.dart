import 'package:flutter/material.dart';

/// Opacity of the category icon background (same hue as the glyph).
const double kCategoryIconBackgroundAlpha = 0.13;

const String _fallbackCategoryId = 'uncategorized';
const String _fallbackCategoryColorHex = '#757575';

/// Psychology-based `#RRGGBB` per canonical category id.
///
/// Keep in sync with `DEFAULT_CATEGORIES` in `functions/src/schema.ts`
/// (seeded to Firestore `categories/{id}.color`) and
/// `shared/test-fixtures/category-colors.json`.
const Map<String, String> kCategoryColorHexById = {
  'food_dining': '#F57C00',
  'groceries': '#43A047',
  'fuel': '#BF360C',
  'transport': '#1E88E5',
  'shopping': '#D81B60',
  'entertainment': '#8E24AA',
  'bills_utilities': '#FB8C00',
  'healthcare': '#E53935',
  'education': '#3949AB',
  'travel': '#00838F',
  'personal_care': '#EC407A',
  'subscriptions': '#5E35B1',
  'rent_housing': '#6D4C41',
  'cash_withdrawal': '#F9A825',
  'transfer': '#039BE5',
  'fees_charges': '#C62828',
  'donations_zakat': '#00695C',
  'income': '#2E7D32',
  'refund': '#26A69A',
  _fallbackCategoryId: _fallbackCategoryColorHex,
};

/// Maps a transaction category to a Lucide SVG asset under
/// `assets/icons/categories/`.
///
/// Matching is keyword-based and case-insensitive so it works for both the
/// canonical category ids (e.g. `food_dining`) and human labels (e.g.
/// "Food & Dining"). Falls back to the uncategorized question-mark icon.
String categoryIconAsset(String? category) {
  return _asset(resolveCategoryId(category));
}

/// Canonical category id for [category], or `uncategorized`.
String resolveCategoryId(String? category) {
  final key = (category ?? '').toLowerCase();
  if (key.isEmpty) return _fallbackCategoryId;
  if (kCategoryColorHexById.containsKey(key)) return key;

  bool has(List<String> words) => words.any(key.contains);

  if (has(['food', 'dining', 'restaurant'])) return 'food_dining';
  if (has(['grocery', 'groceries', 'supermarket'])) return 'groceries';
  if (has(['shopping', 'retail'])) return 'shopping';
  if (has(['fuel', 'petrol', 'gas'])) return 'fuel';
  if (has(['transport', 'ride', 'taxi', 'cab'])) return 'transport';
  if (has(['travel', 'flight', 'hotel'])) return 'travel';
  if (has(['bill', 'utility', 'utilities'])) return 'bills_utilities';
  if (has(['subscription', 'streaming'])) return 'subscriptions';
  if (has(['health', 'medical', 'pharmacy', 'doctor'])) return 'healthcare';
  if (has(['education', 'school', 'tuition', 'course'])) return 'education';
  if (has(['rent', 'housing', 'mortgage'])) return 'rent_housing';
  if (has(['transfer', 'send'])) return 'transfer';
  if (has(['cash', 'atm', 'withdraw'])) return 'cash_withdrawal';
  if (has(['fee', 'charge', 'tax'])) return 'fees_charges';
  if (has(['donation', 'zakat', 'charity'])) return 'donations_zakat';
  if (has(['personal', 'care', 'salon', 'beauty'])) return 'personal_care';
  if (has(['income', 'salary', 'payroll'])) return 'income';
  if (has(['refund', 'reversal', 'cashback'])) return 'refund';
  if (has(['entertainment', 'movie', 'game'])) return 'entertainment';

  return _fallbackCategoryId;
}

/// Hex color stored on the matching Firestore category document.
String categoryColorHex(String? category, {String? storedHex}) {
  final fromStore = parseCategoryHex(storedHex);
  if (fromStore != null) return _normalizeHex(storedHex!);
  return kCategoryColorHexById[resolveCategoryId(category)] ??
      _fallbackCategoryColorHex;
}

/// Icon glyph color for [category].
///
/// Prefers [storedHex] from Firestore when valid; otherwise the psychology
/// palette for the resolved category id.
Color categoryColor(String? category, {String? storedHex}) {
  return parseCategoryHex(storedHex) ??
      parseCategoryHex(categoryColorHex(category)) ??
      parseCategoryHex(_fallbackCategoryColorHex)!;
}

/// Same hue as [categoryColor], at [kCategoryIconBackgroundAlpha].
Color categoryIconBackground(String? category, {String? storedHex}) {
  return categoryColor(
    category,
    storedHex: storedHex,
  ).withValues(alpha: kCategoryIconBackgroundAlpha);
}

/// Parses `#RRGGBB` / `#AARRGGBB` (optional `#`). Returns null if invalid.
Color? parseCategoryHex(String? hex) {
  if (hex == null) return null;
  var value = hex.trim();
  if (value.startsWith('#')) value = value.substring(1);
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return null;
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return null;
  return Color(parsed);
}

String _normalizeHex(String hex) {
  var value = hex.trim();
  if (!value.startsWith('#')) value = '#$value';
  return value.toUpperCase();
}

String _asset(String id) => 'assets/icons/categories/$id.svg';
