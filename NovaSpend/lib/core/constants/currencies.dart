// Supported currencies for ingest + UI.
// Keep in sync with functions/src/currencies.ts

const List<String> kCurrencies = [
  'PKR',
  'USD',
  'EUR',
  'GBP',
  'AED',
  'SAR',
  'INR',
  'CAD',
  'AUD',
  'CHF',
  'JPY',
];

const String kDefaultCurrency = 'PKR';

const Map<String, String> _legacyCurrencyMap = {
  'pkr': 'PKR',
  'rs': 'PKR',
  'rs.': 'PKR',
  'usd': 'USD',
  r'$': 'USD',
  'eur': 'EUR',
  'gbp': 'GBP',
  'aed': 'AED',
  'sar': 'SAR',
  'inr': 'INR',
  'cad': 'CAD',
  'aud': 'AUD',
  'chf': 'CHF',
  'jpy': 'JPY',
};

String normalizeCurrency(String? raw) {
  if (raw == null) return kDefaultCurrency;
  final key = raw.trim();
  if (key.isEmpty) return kDefaultCurrency;
  final upper = key.toUpperCase();
  if (kCurrencies.contains(upper)) return upper;
  return _legacyCurrencyMap[key.toLowerCase()] ?? kDefaultCurrency;
}

const Map<String, String> kCurrencyDisplayNames = {
  'PKR': 'Pakistani Rupee',
  'USD': 'US Dollar',
  'EUR': 'Euro',
  'GBP': 'British Pound',
  'AED': 'UAE Dirham',
  'SAR': 'Saudi Riyal',
  'INR': 'Indian Rupee',
  'CAD': 'Canadian Dollar',
  'AUD': 'Australian Dollar',
  'CHF': 'Swiss Franc',
  'JPY': 'Japanese Yen',
};

String currencyDisplayLabel(String code) {
  final normalized = normalizeCurrency(code);
  final name = kCurrencyDisplayNames[normalized];
  if (name == null) return normalized;
  return '$name ($normalized)';
}

String currencySymbol(String code) {
  final normalized = normalizeCurrency(code);
  return normalized == 'PKR' ? 'Rs.' : normalized;
}
