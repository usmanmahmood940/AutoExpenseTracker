# Shortcut 0 — Expense: Send to Webhook (shared routine)

Build this **first**. The other three shortcuts call this one.

## Purpose

Takes a bank SMS string, POSTs it to `ingestTransaction`, returns the JSON response.

## Input

| Input | Type | Required |
|-------|------|----------|
| `Message` | Text | Yes |
| `Idempotency Key` | Text | No (auto-generated if empty) |

## Configuration (set once at top of shortcut)

Add two **Text** actions at the very top and fill in your values:

| Variable name | Value |
|---------------|-------|
| `Webhook URL` | `https://asia-south1-auto-expense-tracker-2026.cloudfunctions.net/ingestTransaction` |
| `API Key` | Your `WEBHOOK_API_KEY` secret |

> Do not share this shortcut with the API key filled in.

## Actions (in order)

### 1. Receive input
- **Receive** `Message` and `Idempotency Key` (optional) as shortcut input

### 2. Idempotency key
- **If** `Idempotency Key` **has any value**
  - **Set variable** `Key` → `Idempotency Key`
- **Otherwise**
  - **Generate UUID** → **Set variable** `Key`

### 3. Build JSON body
- **Dictionary**
  - `raw` → `Message`
  - `source` → `ios_shortcut`
  - `receivedAt` → **Current Date** formatted as ISO 8601 (`yyyy-MM-dd'T'HH:mm:ssZZZZZ`)
  - `idempotencyKey` → `Key`
- **Set variable** `Payload`

### 4. POST to webhook
- **Get Contents of URL**
  - URL: `Webhook URL`
  - Method: `POST`
  - Headers:
    - `Content-Type` → `application/json`
    - `X-API-Key` → `API Key`
  - Request Body: `JSON` → `Payload`

### 5. Parse response
- **Get Dictionary from** `Contents of URL`
- **Set variable** `Response`

### 6. Return result
- **Return** `Response` from shortcut

## Output dictionary keys

| Key | Meaning |
|-----|---------|
| `success` | `true` / `false` |
| `transactionId` | Firestore transaction ID (on parse success) |
| `ingestionId` | Raw ingestion log ID |
| `duplicate` | `true` if same transaction already existed |
| `error` | Error message (parse fail, etc.) |

## Notes

- HTTP **401** → wrong API key
- HTTP **200** with `error` → message saved but Gemini could not parse (check Firestore `raw_ingestions`)
- HTTP **200** with `duplicate: true` → same transaction already logged (still OK)
