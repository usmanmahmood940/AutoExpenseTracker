// Canonical payment methods for ingest + UI.
// Keep in sync with functions/src/payment_methods.ts

const List<String> kPaymentMethods = [
  'debit_card',
  'credit_card',
  'bank_transfer',
  'wallet',
  'cash',
  'cheque',
  'atm_withdrawal',
  'qr',
  'other',
  'unknown',
];

const String kDefaultPaymentMethod = 'unknown';

const Map<String, String> _legacyPaymentMethodMap = {
  'debit_card': 'debit_card',
  'debit': 'debit_card',
  'debit card': 'debit_card',
  'card': 'debit_card',
  'credit_card': 'credit_card',
  'credit': 'credit_card',
  'credit card': 'credit_card',
  'bank_transfer': 'bank_transfer',
  'transfer': 'bank_transfer',
  'account': 'bank_transfer',
  'bank': 'bank_transfer',
  'ibft': 'bank_transfer',
  'raast': 'bank_transfer',
  'wallet': 'wallet',
  'jazzcash': 'wallet',
  'easypaisa': 'wallet',
  'nayapay': 'wallet',
  'sadapay': 'wallet',
  'cash': 'cash',
  'cheque': 'cheque',
  'check': 'cheque',
  'atm_withdrawal': 'atm_withdrawal',
  'atm': 'atm_withdrawal',
  'atm withdrawal': 'atm_withdrawal',
  'qr': 'qr',
  'qr_payment': 'qr',
  'qr payment': 'qr',
  'other': 'other',
  'unknown': 'unknown',
};

/// Normalize free-text / legacy payment method values to a canonical key.
String normalizePaymentMethod(String? raw) {
  if (raw == null) return kDefaultPaymentMethod;
  final key = raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (key.isEmpty) return kDefaultPaymentMethod;
  if (kPaymentMethods.contains(key)) return key;
  return _legacyPaymentMethodMap[key] ?? kDefaultPaymentMethod;
}
