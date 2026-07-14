#!/usr/bin/env node

/**
 * Local test harness for ingest webhooks.
 *
 * Legacy (API key → top-level collections):
 *   WEBHOOK_API_KEY=your-key node functions/scripts/test-ingest.mjs
 *
 * Multi-user (UID → users/{uid}/…):
 *   INGEST_MODE=user USER_ID=some-uid node functions/scripts/test-ingest.mjs
 *
 * With emulators:
 *   WEBHOOK_API_KEY=your-key INGEST_URL=http://127.0.0.1:5001/auto-expense-tracker-2026/asia-south1/ingestTransaction node functions/scripts/test-ingest.mjs
 *   INGEST_MODE=user USER_ID=test-user INGEST_URL=http://127.0.0.1:5001/auto-expense-tracker-2026/asia-south1/ingestTransactionForUser node functions/scripts/test-ingest.mjs
 */

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomUUID } from 'node:crypto';

const __dirname = dirname(fileURLToPath(import.meta.url));
const samples = JSON.parse(
  readFileSync(join(__dirname, '../test-data/sample-sms.json'), 'utf8'),
);

const mode = process.env.INGEST_MODE === 'user' ? 'user' : 'legacy';
const apiKey = process.env.WEBHOOK_API_KEY;
const userId = process.env.USER_ID;
const defaultBank = process.env.BANK_NAME ?? 'HBL';

const defaultEndpoint =
  mode === 'user'
    ? 'http://127.0.0.1:5001/auto-expense-tracker-2026/asia-south1/ingestTransactionForUser'
    : 'http://127.0.0.1:5001/auto-expense-tracker-2026/asia-south1/ingestTransaction';

const endpoint = process.env.INGEST_URL ?? defaultEndpoint;

if (mode === 'legacy' && !apiKey) {
  console.error('Set WEBHOOK_API_KEY environment variable (legacy mode).');
  process.exit(1);
}

if (mode === 'user' && !userId) {
  console.error('Set USER_ID environment variable (user mode).');
  process.exit(1);
}

console.log(`Mode: ${mode}`);
console.log(`Endpoint: ${endpoint}`);
if (mode === 'user') {
  console.log(`User ID: ${userId}`);
}
console.log(`Samples: ${samples.length}\n`);

let passed = 0;
let failed = 0;

for (const [index, sample] of samples.entries()) {
  const payload = {
    raw: sample.raw,
    source: sample.source,
    receivedAt: new Date().toISOString(),
    idempotencyKey: `test-${randomUUID()}`,
    ...(sample.bank || defaultBank ? { bank: sample.bank ?? defaultBank } : {}),
  };

  console.log(`--- [${index + 1}/${samples.length}] ${sample.name} ---`);

  try {
    const headers = {
      'Content-Type': 'application/json',
    };
    if (mode === 'legacy') {
      headers['X-API-Key'] = apiKey;
    } else {
      headers['X-User-Id'] = userId;
    }

    const response = await fetch(endpoint, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
    });

    const body = await response.json();
    console.log(`Status: ${response.status}`);
    console.log('Response:', JSON.stringify(body, null, 2));

    if (response.ok && body.success && body.transactionId) {
      passed += 1;
    } else if (response.ok && body.success && body.duplicate) {
      passed += 1;
    } else {
      failed += 1;
    }
  } catch (error) {
    failed += 1;
    console.error('Request failed:', error instanceof Error ? error.message : error);
  }

  if (index < samples.length - 1) {
    await new Promise((resolve) => setTimeout(resolve, 2000));
  }

  console.log('');
}

console.log(`Done. Passed: ${passed}, Failed: ${failed}`);

if (failed > 0) {
  process.exit(1);
}
