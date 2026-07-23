/// Maps a transaction category to a Lucide SVG asset under
/// `assets/icons/categories/`.
///
/// Matching is keyword-based and case-insensitive so it works for both the
/// canonical category ids (e.g. `food_dining`) and human labels (e.g.
/// "Food & Dining"). Falls back to the uncategorized question-mark icon.
String categoryIconAsset(String? category) {
  final key = (category ?? '').toLowerCase();

  bool has(List<String> words) => words.any(key.contains);

  if (has(['food', 'dining', 'restaurant'])) {
    return _asset('food_dining');
  }
  if (has(['grocery', 'groceries', 'supermarket'])) {
    return _asset('groceries');
  }
  if (has(['shopping', 'retail'])) return _asset('shopping');
  if (has(['fuel', 'petrol', 'gas'])) return _asset('fuel');
  if (has(['transport', 'ride', 'taxi', 'cab'])) {
    return _asset('transport');
  }
  if (has(['travel', 'flight', 'hotel'])) return _asset('travel');
  if (has(['bill', 'utility', 'utilities'])) {
    return _asset('bills_utilities');
  }
  if (has(['subscription', 'streaming'])) return _asset('subscriptions');
  if (has(['health', 'medical', 'pharmacy', 'doctor'])) {
    return _asset('healthcare');
  }
  if (has(['education', 'school', 'tuition', 'course'])) {
    return _asset('education');
  }
  if (has(['rent', 'housing', 'mortgage'])) return _asset('rent_housing');
  if (has(['transfer', 'send'])) return _asset('transfer');
  if (has(['cash', 'atm', 'withdraw'])) return _asset('cash_withdrawal');
  if (has(['fee', 'charge', 'tax'])) return _asset('fees_charges');
  if (has(['donation', 'zakat', 'charity'])) {
    return _asset('donations_zakat');
  }
  if (has(['personal', 'care', 'salon', 'beauty'])) {
    return _asset('personal_care');
  }
  if (has(['income', 'salary', 'payroll'])) return _asset('income');
  if (has(['refund', 'reversal', 'cashback'])) return _asset('refund');
  if (has(['entertainment', 'movie', 'game'])) {
    return _asset('entertainment');
  }

  return _asset('uncategorized');
}

String _asset(String id) => 'assets/icons/categories/$id.svg';
