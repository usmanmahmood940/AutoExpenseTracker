import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  DEFAULT_PAYMENT_METHOD,
  normalizePaymentMethod,
  PAYMENT_METHODS,
} from './payment_methods';

test('normalizePaymentMethod maps legacy aliases', () => {
  assert.equal(normalizePaymentMethod('card'), 'debit_card');
  assert.equal(normalizePaymentMethod('Account'), 'bank_transfer');
  assert.equal(normalizePaymentMethod('JazzCash'), 'wallet');
  assert.equal(normalizePaymentMethod('Raast'), 'bank_transfer');
  assert.equal(normalizePaymentMethod('credit card'), 'credit_card');
  assert.equal(normalizePaymentMethod(''), DEFAULT_PAYMENT_METHOD);
  assert.equal(normalizePaymentMethod('totally-new'), DEFAULT_PAYMENT_METHOD);
});

test('normalizePaymentMethod keeps canonical keys', () => {
  for (const method of PAYMENT_METHODS) {
    assert.equal(normalizePaymentMethod(method), method);
  }
});
