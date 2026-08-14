import assert from 'node:assert/strict';
import { test } from 'node:test';

import { computeDedupKey, maskAccountId } from './dedup';
import type { ParsedTransaction } from './schema';

function parsed(
  overrides: Partial<ParsedTransaction> = {},
): ParsedTransaction {
  return {
    amount: 710,
    currency: 'PKR',
    type: 'credit',
    merchant: 'TELHA WASIM',
    merchantDetails: 'SCB-xxx2501',
    category: 'Income',
    paymentMethod: 'account',
    bank: 'Meezan',
    accountId: 'xxx1215',
    branch: 'DHA PHASE VIII BR LHR',
    transactionTime: '2026-08-13T19:44:00+05:00',
    transactionDate: '2026-08-13',
    externalId: null,
    externalIdType: 'unknown',
    parseConfidence: 0.95,
    ...overrides,
  };
}

test('different merchants without externalId get different dedup keys', () => {
  const telha = computeDedupKey(parsed());
  const waleed = computeDedupKey(
    parsed({
      merchant: 'WALEED ANJUM',
      merchantDetails: 'SCB-xxx7301',
      transactionTime: '2026-08-13T19:46:00+05:00',
    }),
  );

  assert.notEqual(telha, waleed);
});

test('same transfer without externalId is stable across casing/spacing', () => {
  const a = computeDedupKey(parsed());
  const b = computeDedupKey(
    parsed({
      merchant: '  telha   wasim ',
      merchantDetails: 'scb-xxx2501',
    }),
  );

  assert.equal(a, b);
});

test('with externalId, merchant differences do not change the key', () => {
  const a = computeDedupKey(
    parsed({
      externalId: '387522',
      externalIdType: 'tid',
      merchant: 'PSO RANGERS',
    }),
  );
  const b = computeDedupKey(
    parsed({
      externalId: '387522',
      externalIdType: 'tid',
      merchant: 'PSO Rangers LAH',
      merchantDetails: 'LAH',
      transactionTime: '2026-08-13T11:27:00+05:00',
    }),
  );

  assert.equal(a, b);
});

test('same merchant same day different minutes are distinct without externalId', () => {
  const first = computeDedupKey(parsed());
  const second = computeDedupKey(
    parsed({
      transactionTime: '2026-08-13T19:46:00+05:00',
    }),
  );

  assert.notEqual(first, second);
});

test('maskAccountId preserves last four characters', () => {
  assert.equal(maskAccountId('xxx1215'), 'xxx1215');
  assert.equal(maskAccountId('1234567890'), 'xxxxxx7890');
  assert.equal(maskAccountId('Unknown'), 'Unknown');
});
