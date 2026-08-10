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
