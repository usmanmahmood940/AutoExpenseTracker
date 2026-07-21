# Auto Expense Tracker

Personal auto expense logger: bank SMS/email → webhook → Gemini parsing → Firestore.

## Phase 1 — Backend core (current)

- **`ingestTransaction`** HTTP Cloud Function (Firebase Functions v2, `asia-south1`) — legacy single-user
- **`ingestTransactionForUser`** — multi-user webhook keyed by UID
- Gemini parsing with structured JSON output (`gemini-2.5-flash`, with fallbacks)
- Firestore writes:
  - Legacy: top-level `raw_ingestions` and `transactions`
  - Multi-user: `users/{uid}/raw_ingestions` and `users/{uid}/transactions`
- Dedup by amount + currency + accountId + externalId + transactionDate
- Idempotency via optional `idempotencyKey`

## Project structure

```
├── firebase.json
├── firestore.rules
├── firestore.indexes.json
├── functions/
│   ├── src/
│   │   ├── index.ts          # Function exports
│   │   ├── ingest.ts         # ingestTransaction + ingestTransactionForUser
│   │   ├── gemini.ts         # Gemini parsing
│   │   ├── dedup.ts          # Dedup key + account masking
│   │   ├── validate.ts       # Request/parse validation
│   │   └── schema.ts         # Firestore types
│   ├── scripts/test-ingest.mjs
│   └── test-data/sample-sms.json
├── scripts/sync-shared-schema.mjs  # Regenerates shared/types/schema.ts
└── shared/types/schema.ts    # GENERATED mirror of functions/src/schema.ts
```

### Keeping `shared/types/schema.ts` in sync

`functions/src/schema.ts` is the source of truth (it's what actually
deploys). `shared/types/schema.ts` is a generated mirror for future
client apps that can't import across the Cloud Functions deploy boundary.
Never hand-edit `shared/types/schema.ts` — after changing
`functions/src/schema.ts`, run:

```bash
npm run sync:shared-types    # regenerate shared/types/schema.ts
npm run verify:shared-types  # CI-friendly check; exits non-zero if stale
```

`npm run build` runs `verify:shared-types` automatically and fails if the
two files have drifted.

## Prerequisites

- **Firebase Blaze plan** (required for Cloud Functions with secrets)
- Firebase CLI: `npm install -g firebase-tools`
- Node.js 22

## Secrets (do not commit)

Set these before deploying:

```bash
# Webhook auth header: X-API-Key
firebase functions:secrets:set WEBHOOK_API_KEY

# Gemini API key for SMS parsing
firebase functions:secrets:set GEMINI_API_KEY
```

For local emulator testing, copy `functions/.env.example` to `functions/.secret.local`:

```bash
cp functions/.env.example functions/.secret.local
# Edit functions/.secret.local with your keys (never commit this file)
```

## Deploy

```bash
# 1. Set secrets (one-time, prompts for values)
firebase functions:secrets:set WEBHOOK_API_KEY
firebase functions:secrets:set GEMINI_API_KEY

# 2. Deploy Firestore indexes (includes idempotency + dedup indexes)
npm run deploy:rules

# 3. Build and deploy functions
npm run build
npm run deploy:functions
```

After deploy, note the function URLs from the CLI output:

```
https://asia-south1-auto-expense-tracker-2026.cloudfunctions.net/ingestTransaction
https://asia-south1-auto-expense-tracker-2026.cloudfunctions.net/ingestTransactionForUser
```

## Test the endpoint

### With emulators (local)

```bash
# Terminal 1 — start emulators
npm run emulators

# Terminal 2 — run test harness (legacy)
cd functions
WEBHOOK_API_KEY=your-key npm run test:ingest

# Or multi-user (writes under users/{USER_ID}/…)
INGEST_MODE=user USER_ID=test-user npm run test:ingest
```

### Against production

```bash
cd functions
WEBHOOK_API_KEY=your-key \
INGEST_URL=https://asia-south1-auto-expense-tracker-2026.cloudfunctions.net/ingestTransaction \
npm run test:ingest

# Multi-user
INGEST_MODE=user USER_ID=your-firebase-uid \
INGEST_URL=https://asia-south1-auto-expense-tracker-2026.cloudfunctions.net/ingestTransactionForUser \
npm run test:ingest
```

### Manual curl

```bash
# Legacy (API key → top-level collections)
curl -X POST \
  -H "Content-Type: application/json" \
  -H "X-API-Key: YOUR_WEBHOOK_KEY" \
  -d '{
    "raw": "PKR 5,990.00 charged at PSO RANGERS>LAH for card used, from A/C xxx1215 (DHA PHASE VIII BR LHR) on 06-Jul-2026 at 11:27 TID:387522",
    "source": "ios_shortcut",
    "bank": "HBL",
    "receivedAt": "2026-07-06T11:27:00+05:00"
  }' \
  https://asia-south1-auto-expense-tracker-2026.cloudfunctions.net/ingestTransaction

# Multi-user (UID → users/{uid}/raw_ingestions + transactions)
curl -X POST \
  -H "Content-Type: application/json" \
  -H "X-User-Id: YOUR_FIREBASE_UID" \
  -d '{
    "raw": "PKR 5,990.00 charged at PSO RANGERS>LAH for card used, from A/C xxx1215 (DHA PHASE VIII BR LHR) on 06-Jul-2026 at 11:27 TID:387522",
    "source": "ios_shortcut",
    "bank": "HBL",
    "receivedAt": "2026-07-06T11:27:00+05:00"
  }' \
  https://asia-south1-auto-expense-tracker-2026.cloudfunctions.net/ingestTransactionForUser
```

### Expected responses

| Case | HTTP | Body |
|------|------|------|
| Success | 200 | `{ "success": true, "ingestionId": "...", "transactionId": "..." }` |
| Duplicate | 200 | `{ "success": true, "duplicate": true, "transactionId": "..." }` |
| Parse failed | 200 | `{ "success": false, "ingestionId": "...", "error": "..." }` |
| Bad API key (legacy) | 401 | `{ "success": false, "error": "Unauthorized" }` |
| Missing uid (multi-user) | 400 | `{ "success": false, "error": "uid is required..." }` |
| Unknown uid (multi-user) | 404 | `{ "success": false, "error": "uid does not exist in Firebase Auth" }` |
| Invalid body | 400 | `{ "success": false, "error": "..." }` |

## Phase 2 — iOS Shortcuts (current)

Three shortcuts + shared webhook routine. Full setup: [`ios/README.md`](ios/README.md)

| Shortcut | Purpose |
|----------|---------|
| **Expense: Process Bank SMS** | Automation on bank SMS (drains pending → logs message) |
| **Expense: Manual Test Log** | Paste SMS → webhook → show alert |
| **Expense: Drain Pending Queue** | Sync all pending Numbers rows one-by-one |

Pending queue: Numbers sheet **Expense Pending Queue** (`pending` / `sent` / `failed`).

## Commands

```bash
npm run build              # Compile TypeScript functions
npm run deploy:rules       # Deploy Firestore rules + indexes
npm run deploy:functions   # Deploy Cloud Functions
npm run emulators          # Start local emulators
```

## Firebase console

https://console.firebase.google.com/project/auto-expense-tracker-2026/overview

## Next: Phase 3

Gmail Apps Script fallback for email-based transaction alerts.
