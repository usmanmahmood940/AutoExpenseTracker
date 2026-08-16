#!/usr/bin/env node

/**
 * Local test harness for ingestTransactionForUser.
 *
 *   USER_ID=your-firebase-uid node functions/scripts/test-ingest.mjs
 *
 * With emulators:
 *   USER_ID=test-user INGEST_URL=http://127.0.0.1:5001/auto-expense-tracker-2026/asia-south1/ingestTransactionForUser node functions/scripts/test-ingest.mjs
 */

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomUUID } from 'node:crypto';

const __dirname = dirname(fileURLToPath(import.meta.url));
const samples = JSON.parse(
  readFileSync(join(__dirname, '../test-data/sample-sms.json'), 'utf8'),
);

const userId = process.env.USER_ID;
const defaultBank = process.env.BANK_NAME ?? 'HBL';

const endpoint =
  process.env.INGEST_URL ??
  'http://127.0.0.1:5001/auto-expense-tracker-2026/asia-south1/ingestTransactionForUser';

if (!userId) {
  console.error('Set USER_ID environment variable (Firebase Auth UID).');
  process.exit(1);
}

console.log(`Endpoint: ${endpoint}`);
console.log(`User ID: ${userId}`);
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
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-User-Id': userId,
      },
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
