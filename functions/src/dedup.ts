import { createHash } from 'crypto';

import { normalizeMerchantKey, type ParsedTransaction } from './schema';

/** Extract HH:mm from ISO-ish transactionTime for stable bucketing. */
function timeBucket(transactionTime: string): string {
  const match = /T(\d{2}):(\d{2})/.exec(transactionTime);
  if (!match) {
    return '';
  }
  return `${match[1]}:${match[2]}`;
}

function normalizeDetails(details: string | null): string {
  if (!details) {
    return '';
  }
  return normalizeMerchantKey(details);
}

/**
 * Stable hash for duplicate detection across SMS and email channels.
 *
 * When a bank reference (`externalId`) is present, amount + account + id + date
 * is enough to merge the same charge across channels.
 *
 * When `externalId` is missing, also include merchant, merchantDetails, and
 * HH:mm so distinct same-day transfers (e.g. two 710 PKR credits from
 * different people) are not collapsed.
 */
export function computeDedupKey(parsed: ParsedTransaction): string {
  const parts = [
    parsed.amount.toFixed(2),
    parsed.currency.toUpperCase(),
    parsed.accountId,
    parsed.externalId ?? '',
    parsed.transactionDate,
  ];

  if (!parsed.externalId) {
    parts.push(
      normalizeMerchantKey(parsed.merchant),
      normalizeDetails(parsed.merchantDetails),
      timeBucket(parsed.transactionTime),
    );
  }

  return createHash('sha256').update(parts.join('|')).digest('hex');
}

/** Mask account identifiers while preserving last 4 visible characters. */
export function maskAccountId(accountId: string): string {
  if (!accountId || accountId === 'Unknown') {
    return accountId;
  }

  if (accountId.length <= 4) {
    return accountId;
  }

  return 'x'.repeat(accountId.length - 4) + accountId.slice(-4);
}
