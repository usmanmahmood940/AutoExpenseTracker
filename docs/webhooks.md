# Webhook API Reference

Both webhooks accept the **same JSON request body**. They differ in auth headers and where data is written in Firestore.

Region: `asia-south1`  
Project: `auto-expense-tracker-2026`

---

## Request body (shared)

```json
{
  "raw": "PKR 5,990.00 charged at PSO RANGERS>LAH for card used, from A/C xxx1215 (DHA PHASE VIII BR LHR) on 06-Jul-2026 at 11:27 TID:387522",
  "source": "ios_shortcut",
  "receivedAt": "2026-07-06T11:27:00+05:00",
  "bank": "HBL",
  "messageId": "optional-message-id",
  "idempotencyKey": "optional-unique-key"
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `raw` | Yes | SMS/email text to parse |
| `source` | Yes | `ios_shortcut`, `gmail`, or `manual` |
| `receivedAt` | Yes | ISO 8601 or `dd/mm/yyyy` with time (e.g. `10/07/2026, 6:02:00 PM GMT +5`) |
| `bank` | No | Overrides AI-detected bank name |
| `messageId` | No | Optional message identifier |
| `idempotencyKey` | No | Prevents duplicate processing of the same event |

---

## Response body (shared success shapes)

**Success (HTTP 200)**

```json
{
  "success": true,
  "ingestionId": "abc123",
  "transactionId": "xyz789"
}
```

**Duplicate (HTTP 200)**

```json
{
  "success": true,
  "duplicate": true,
  "ingestionId": "abc123",
  "transactionId": "xyz789"
}
```

**Parse failed (HTTP 200)**

```json
{
  "success": false,
  "ingestionId": "abc123",
  "error": "Could not parse transaction from SMS"
}
```

**Invalid body (HTTP 400)**

```json
{
  "success": false,
  "error": "raw is required and must be a non-empty string"
}
```

---

## 1. Legacy webhook — `ingestTransaction`

Single-user / original pipeline. Authenticated with a shared API key.

### URL

```
https://asia-south1-auto-expense-tracker-2026.cloudfunctions.net/ingestTransaction
```

### Headers

```http
Content-Type: application/json
X-API-Key: YOUR_WEBHOOK_KEY
```

### Example request

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

### Extra error responses

| Case | HTTP | Body |
|------|------|------|
| Bad or missing API key | 401 | `{ "success": false, "error": "Unauthorized" }` |

### Firestore paths

- `raw_ingestions/{ingestionId}`
- `transactions/{transactionId}`

(`userId` field is set to `"me"`.)

---

## 2. Multi-user webhook — `ingestTransactionForUser`

Writes under a specific Firebase Auth UID. The UID must exist in Firebase Auth.

### URL

```
https://asia-south1-auto-expense-tracker-2026.cloudfunctions.net/ingestTransactionForUser
```

### Headers

```http
Content-Type: application/json
X-User-Id: YOUR_FIREBASE_AUTH_UID
```

UID can also be passed as a query parameter: `?uid=YOUR_FIREBASE_AUTH_UID`

### Example request

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "X-User-Id: YOUR_FIREBASE_AUTH_UID" \
  -d '{
    "raw": "PKR 5,990.00 charged at PSO RANGERS>LAH for card used, from A/C xxx1215 (DHA PHASE VIII BR LHR) on 06-Jul-2026 at 11:27 TID:387522",
    "source": "ios_shortcut",
    "bank": "HBL",
    "receivedAt": "2026-07-06T11:27:00+05:00"
  }' \
  https://asia-south1-auto-expense-tracker-2026.cloudfunctions.net/ingestTransactionForUser
```

### Prerequisites

Firebase Authentication must be enabled before this webhook can verify UIDs:

```bash
firebase deploy --only auth
```

Create at least one user in **Firebase Console → Authentication** before testing with a real UID.

### Extra error responses

| Case | HTTP | Body |
|------|------|------|
| Missing uid | 400 | `{ "success": false, "error": "uid is required (X-User-Id header or ?uid= query parameter)" }` |
| Invalid uid format | 400 | `{ "success": false, "error": "uid must be 1–128 characters: letters, digits, underscore, or hyphen" }` |
| UID not in Firebase Auth | 404 | `{ "success": false, "error": "uid does not exist in Firebase Auth" }` |
| Firebase Auth not configured | 503 | `{ "success": false, "error": "Firebase Authentication is not configured for this project..." }` |
| Auth lookup failed | 500 | `{ "success": false, "error": "Failed to verify uid with Firebase Auth" }` |

### Firestore paths

- `users/{uid}` (created on first ingest if missing)
- `users/{uid}/raw_ingestions/{ingestionId}`
- `users/{uid}/transactions/{transactionId}`

---

## Comparison

| | Legacy `ingestTransaction` | Multi-user `ingestTransactionForUser` |
|---|---|---|
| Auth | `X-API-Key` | `X-User-Id` or `?uid=` |
| Request body | Shared shape above | Shared shape above |
| Success / duplicate / parse responses | Shared shapes above | Shared shapes above |
| Extra errors | 401 Unauthorized | 400 missing/invalid uid, 404 uid not in Auth, 503 Auth not configured |
| Firestore | Top-level `raw_ingestions`, `transactions` | `users/{uid}/raw_ingestions`, `users/{uid}/transactions` |

---

## Local testing

```bash
# Legacy
WEBHOOK_API_KEY=your-key npm run test:ingest --prefix functions

# Multi-user
INGEST_MODE=user USER_ID=your-firebase-uid npm run test:ingest --prefix functions
```
