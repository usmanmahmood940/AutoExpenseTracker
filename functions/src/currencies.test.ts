import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  CURRENCIES,
  DEFAULT_CURRENCY,
  normalizeCurrency,
} from './currencies';

test('normalizeCurrency maps aliases and defaults', () => {
  assert.equal(normalizeCurrency('rs'), 'PKR');
  assert.equal(normalizeCurrency('usd'), 'USD');
  assert.equal(normalizeCurrency(''), DEFAULT_CURRENCY);
  assert.equal(normalizeCurrency('XYZ'), DEFAULT_CURRENCY);
});

test('normalizeCurrency keeps supported codes', () => {
  for (const code of CURRENCIES) {
    assert.equal(normalizeCurrency(code), code);
    assert.equal(normalizeCurrency(code.toLowerCase()), code);
  }
});
