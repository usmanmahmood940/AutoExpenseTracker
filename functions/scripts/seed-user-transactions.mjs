#!/usr/bin/env node

/**
 * Seed dummy transactions in Firestore for a specific user.
 *
 * Usage examples (from functions/):
 *   node scripts/seed-user-transactions.mjs --uid=USER_UID --count=300
 *   USER_ID=USER_UID TX_COUNT=500 node scripts/seed-user-transactions.mjs
 *
 * Optional:
 *   --chunk=400   Number of docs per batch commit (default: 400)
 *
 * Requires Application Default Credentials for project auto-expense-tracker-2026
 * (for example `firebase login` + `gcloud auth application-default login`).
 */

import { randomUUID } from 'node:crypto';
import { initializeApp, getApps } from 'firebase-admin/app';
import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { createRequire } from 'module';

const require = createRequire(import.meta.url);
const { COLLECTIONS, normalizeMerchantKey } = require('../lib/schema.js');

const PROJECT_ID = 'auto-expense-tracker-2026';
const CURRENCY = 'PKR';
const DEFAULT_COUNT = 300;
const DEFAULT_CHUNK = 400;

const EXPENSE_CATEGORIES = [
  'Food & Dining',
  'Groceries',
  'Fuel',
  'Transport',
  'Shopping',
  'Entertainment',
  'Bills & Utilities',
  'Healthcare',
  'Education',
  'Travel',
  'Personal Care',
  'Subscriptions',
  'Rent & Housing',
  'Cash Withdrawal',
  'Transfer',
  'Fees & Charges',
  'Donations & Zakat',
];

const INCOME_CATEGORIES = ['Income', 'Refund'];

const EXPENSE_MERCHANTS = [
  'KFC',
  'McDonalds',
  'Imtiaz Super Market',
  'Naheed',
  'PSO Pump',
  'Shell Pump',
  'Careem',
  'Uber',
  'Daraz',
  'LuckyOne Mall',
  'Netflix',
  'Spotify',
  'K-Electric',
  'Sui Southern Gas',
  'Aga Khan Lab',
  'Al-Fatah',
];

const INCOME_MERCHANTS = [
  'ABC Pvt Ltd Payroll',
  'Freelance Client',
  'Bank Profit Credit',
  'Refund Settlement',
];

const BANKS = ['HBL', 'UBL', 'Meezan', 'Alfalah', 'Standard Chartered'];

const PAYMENT_METHODS = [
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

function parseArgs(argv) {
  const result = {};
  for (const part of argv.slice(2)) {
    if (!part.startsWith('--')) continue;
    const [k, v] = part.slice(2).split('=');
    if (k && v !== undefined) result[k] = v;
  }
  return result;
}

function randomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randomChoice(values) {
  return values[randomInt(0, values.length - 1)];
}

function randomDateInLastDays(daysBack) {
  const now = Date.now();
  const offsetMs = randomInt(0, daysBack * 24 * 60 * 60 * 1000);
  return new Date(now - offsetMs);
}

function formatIsoDate(d) {
  return d.toISOString().slice(0, 10);
}

function buildTransaction(uid) {
  const isIncome = Math.random() < 0.12;
  const txType = isIncome ? 'credit' : 'debit';
  const txDate = randomDateInLastDays(180);
  const merchant = isIncome
    ? randomChoice(INCOME_MERCHANTS)
    : randomChoice(EXPENSE_MERCHANTS);
  const category = isIncome
    ? randomChoice(INCOME_CATEGORIES)
    : randomChoice(EXPENSE_CATEGORIES);
  const bank = randomChoice(BANKS);
  const paymentMethod = randomChoice(PAYMENT_METHODS);

  const amount = isIncome
    ? randomInt(20_000, 220_000)
    : randomInt(150, 25_000);

  const transactionTime = txDate.toTimeString().slice(0, 8);
  const transactionDate = formatIsoDate(txDate);
  const nowTs = FieldValue.serverTimestamp();
  const reviewed = Math.random() < 0.7;
  const confidence = reviewed ? 0.95 : Math.random() < 0.5 ? 0.72 : 0.86;

  return {
    userId: uid,
    amount,
    currency: CURRENCY,
    type: txType,
    merchant,
    merchantDetails: null,
    merchantNormalized: normalizeMerchantKey(merchant),
    isRecurring: Math.random() < 0.08,
    recurringGroupId: null,
    category,
    categorySource: 'rule',
    paymentMethod,
    bank,
    accountId: `ACC-${randomInt(1000, 9999)}`,
    accountIdMasked: `****${randomInt(1000, 9999)}`,
    branch: null,
    transactionTime,
    transactionDate,
    day: txDate.toLocaleDateString('en-US', { weekday: 'short' }),
    externalId: null,
    externalIdType: 'unknown',
    dedupKey: `dummy_${randomUUID()}`,
    smsSource: {
      raw: `${bank}: PKR ${amount} ${txType === 'debit' ? 'debited' : 'credited'} at ${merchant}`,
      source: 'seed-script',
      receivedAt: Timestamp.fromDate(txDate),
      idempotencyKey: `seed_${randomUUID()}`,
    },
    parseConfidence: confidence,
    isAutoDetected: true,
    isEdited: false,
    isDuplicate: false,
    status: 'active',
    reviewedAt: reviewed ? nowTs : null,
    createdAt: nowTs,
    updatedAt: nowTs,
  };
}

async function main() {
  const args = parseArgs(process.argv);
  const uid = args.uid ?? process.env.USER_ID;
  const count = Number(args.count ?? process.env.TX_COUNT ?? DEFAULT_COUNT);
  const chunkSize = Number(args.chunk ?? process.env.TX_CHUNK ?? DEFAULT_CHUNK);

  if (!uid || uid.trim().length === 0) {
    throw new Error('Missing uid. Pass --uid=USER_UID or set USER_ID.');
  }
  if (!Number.isInteger(count) || count <= 0) {
    throw new Error('count must be a positive integer.');
  }
  if (!Number.isInteger(chunkSize) || chunkSize <= 0 || chunkSize > 450) {
    throw new Error('chunk must be a positive integer up to 450.');
  }

  if (getApps().length === 0) {
    initializeApp({ projectId: PROJECT_ID });
  }
  const db = getFirestore();
  const txCollection = db
    .collection(COLLECTIONS.users)
    .doc(uid)
    .collection(COLLECTIONS.transactions);

  console.log(`Project: ${PROJECT_ID}`);
  console.log(`Target: users/${uid}/${COLLECTIONS.transactions}`);
  console.log(`Generating ${count} dummy transactions...\n`);

  let created = 0;
  while (created < count) {
    const remaining = count - created;
    const take = Math.min(remaining, chunkSize);
    const batch = db.batch();

    for (let i = 0; i < take; i += 1) {
      const docRef = txCollection.doc();
      batch.set(docRef, buildTransaction(uid));
    }

    await batch.commit();
    created += take;
    console.log(`Committed ${created}/${count}`);
  }

  console.log(`\nDone. Seeded ${created} transactions for uid: ${uid}`);
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
