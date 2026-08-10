/**
 * Supported currencies for ingest + clients.
 * Keep in sync with NovaSpend/lib/core/constants/currencies.dart
 */

export const CURRENCIES = [
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
] as const;

export type CurrencyCode = (typeof CURRENCIES)[number];

export const DEFAULT_CURRENCY: CurrencyCode = 'PKR';

const CURRENCY_SET = new Set<string>(CURRENCIES);

/** Legacy / informal aliases → ISO code */
const LEGACY_CURRENCY_MAP: Record<string, CurrencyCode> = {
  pkr: 'PKR',
  rs: 'PKR',
  'rs.': 'PKR',
  usd: 'USD',
  $: 'USD',
  eur: 'EUR',
  '€': 'EUR',
  gbp: 'GBP',
  '£': 'GBP',
  aed: 'AED',
  sar: 'SAR',
  inr: 'INR',
  cad: 'CAD',
  aud: 'AUD',
  chf: 'CHF',
  jpy: 'JPY',
  '¥': 'JPY',
};

export function normalizeCurrency(raw: string | null | undefined): CurrencyCode {
  if (raw == null) {
    return DEFAULT_CURRENCY;
  }
  const key = raw.trim();
  if (!key) {
    return DEFAULT_CURRENCY;
  }
  const upper = key.toUpperCase();
  if (CURRENCY_SET.has(upper)) {
    return upper as CurrencyCode;
  }
  const lower = key.toLowerCase();
  return LEGACY_CURRENCY_MAP[lower] ?? DEFAULT_CURRENCY;
}
