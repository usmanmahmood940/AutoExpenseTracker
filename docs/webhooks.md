# Webhook API Reference

Region: `asia-south1`  
Project: `auto-expense-tracker-2026`

---

## Request body

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

## Response body

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

## `ingestTransactionForUser` (deleted Cloud Function)

Identifies the user via Firebase Auth UID (`X-User-Id` or `?uid=`). Wrote under `users/{uid}/…`.

**Deleted 2026-08-25** (migration step 12). Use FastAPI `POST /ingest` below.

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

Create at least one user in **Firebase Console → Authentication** before testing with a real UID. Copy your UID from NovaSpend **Settings**.

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

## FastAPI `POST /ingest` (live)

Same request and response bodies as the Function. This is the Shortcut webhook as of Phase F (2026-08-23).

### URL

Local:

```
http://127.0.0.1:8000/ingest
```

Alias: `POST /webhooks/sms`. After a Cloud Run deploy the host is the service URL (not localhost).

### Headers

```http
Content-Type: application/json
X-User-Id: YOUR_FIREBASE_AUTH_UID
```

UID can also be passed as `?uid=`. If `INGEST_SHARED_SECRET` is set on the API, also send:

```http
X-Ingest-Secret: THE_SHARED_SECRET
```

Unset (the default, matching today's Function) means UID-only auth.

### Writes

- Postgres `users` (created on first ingest if missing)
- `raw_ingestions`
- `transactions` (unless duplicate / parse failed)
- `monthly_summaries` for that month (recomputed from SQL)
- FCM to tokens in `devices` (register via `POST /me/devices`)

### Example

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
  http://127.0.0.1:8000/ingest
```

Requires `GEMINI_API_KEY` in `backend/.env` for a real parse. Without it the row is stored as `needs_parse`.

---

## Local testing

```bash
USER_ID=your-firebase-uid npm run test:ingest --prefix functions
# FastAPI (Gemini stubbed in pytest; for a live parse use make run + the curl above):
cd backend && make test
```
