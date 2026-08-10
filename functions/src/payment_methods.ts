/**
 * Canonical payment methods for ingest + clients.
 * Keep in sync with NovaSpend/lib/core/constants/payment_methods.dart
 */

export const PAYMENT_METHODS = [
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
] as const;

export type PaymentMethod = (typeof PAYMENT_METHODS)[number];

export const DEFAULT_PAYMENT_METHOD: PaymentMethod = 'unknown';

const PAYMENT_METHOD_SET = new Set<string>(PAYMENT_METHODS);

/** Legacy / free-text aliases → canonical key */
const LEGACY_PAYMENT_METHOD_MAP: Record<string, PaymentMethod> = {
  debit_card: 'debit_card',
  debit: 'debit_card',
  'debit card': 'debit_card',
  card: 'debit_card',
  credit_card: 'credit_card',
  credit: 'credit_card',
  'credit card': 'credit_card',
  bank_transfer: 'bank_transfer',
  transfer: 'bank_transfer',
  account: 'bank_transfer',
  bank: 'bank_transfer',
  ibft: 'bank_transfer',
  raast: 'bank_transfer',
  wallet: 'wallet',
  jazzcash: 'wallet',
  easypaisa: 'wallet',
  nayapay: 'wallet',
  sadapay: 'wallet',
  cash: 'cash',
  cheque: 'cheque',
  check: 'cheque',
  atm_withdrawal: 'atm_withdrawal',
  atm: 'atm_withdrawal',
  'atm withdrawal': 'atm_withdrawal',
  qr: 'qr',
  qr_payment: 'qr',
  'qr payment': 'qr',
  other: 'other',
  unknown: 'unknown',
};

/**
 * Normalize free-text / legacy payment method values to a canonical key.
 */
export function normalizePaymentMethod(raw: string | null | undefined): PaymentMethod {
  if (raw == null) {
    return DEFAULT_PAYMENT_METHOD;
  }
  const key = raw.trim().toLowerCase().replace(/\s+/g, ' ');
  if (!key) {
    return DEFAULT_PAYMENT_METHOD;
  }
  if (PAYMENT_METHOD_SET.has(key)) {
    return key as PaymentMethod;
  }
  return LEGACY_PAYMENT_METHOD_MAP[key] ?? DEFAULT_PAYMENT_METHOD;
}
