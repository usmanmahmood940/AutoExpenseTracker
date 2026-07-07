import { createHash } from 'crypto';

import type { ParsedTransaction } from './schema';

/** Stable hash for duplicate detection across SMS and email channels. */
export function computeDedupKey(parsed: ParsedTransaction): string {
  const payload = [
    parsed.amount.toFixed(2),
    parsed.currency.toUpperCase(),
    parsed.accountId,
    parsed.externalId ?? '',
    parsed.transactionDate,
  ].join('|');

  return createHash('sha256').update(payload).digest('hex');
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
