# Auto Expense Tracker

Personal auto expense logger: bank SMS/email → webhook → Gemini parsing → Firestore.

## Phase 1 — Backend core (current)

- **`ingestTransaction`** HTTP Cloud Function (Firebase Functions v2, `asia-south1`)
- Gemini parsing with structured JSON output (`gemini-2.5-flash`, with fallbacks)
- Firestore writes to `raw_ingestions` and `transactions`
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
│   │   ├── ingest.ts         # ingestTransaction HTTP handler
│   │   ├── gemini.ts         # Gemini parsing
│   │   ├── dedup.ts          # Dedup key + account masking
│   │   ├── validate.ts       # Request/parse validation
│   │   └── schema.ts         # Firestore types
│   ├── scripts/test-ingest.mjs
│   └── test-data/sample-sms.json
└── shared/types/schema.ts    # Mirrored schema for future app
```

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

After deploy, note the function URL from the CLI output:

```
https://asia-south1-auto-expense-tracker-2026.cloudfunctions.net/ingestTransaction
```

## Test the endpoint

### With emulators (local)

```bash
# Terminal 1 — start emulators
npm run emulators

# Terminal 2 — run test harness
cd functions
WEBHOOK_API_KEY=your-key npm run test:ingest
```

### Against production

```bash
cd functions
WEBHOOK_API_KEY=your-key \
INGEST_URL=https://asia-south1-auto-expense-tracker-2026.cloudfunctions.net/ingestTransaction \
npm run test:ingest
```

### Manual curl

```bash
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
```

### Expected responses

| Case | HTTP | Body |
|------|------|------|
| Success | 200 | `{ "success": true, "ingestionId": "...", "transactionId": "..." }` |
| Duplicate | 200 | `{ "success": true, "duplicate": true, "transactionId": "..." }` |
| Parse failed | 200 | `{ "success": true, "ingestionId": "...", "error": "..." }` |
| Bad API key | 401 | `{ "success": false, "error": "Unauthorized" }` |
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
