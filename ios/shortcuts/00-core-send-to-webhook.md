# Shortcut 0 — Expense: Send to Webhook (shared routine)

> **iPhone setup:** see [`../IPHONE-UPDATE-GUIDE.md`](../IPHONE-UPDATE-GUIDE.md)  
> **Import file:** [`../export/Expense - Send to Webhook.shortcut`](../export/Expense%20-%20Send%20to%20Webhook.shortcut)

Build this **first**. The other shortcuts call this one.

## Purpose

Takes a bank SMS string, POSTs it to `ingestTransaction`, returns the JSON response.

## Constants (set once at top)

| Variable | Value | Example |
|----------|-------|---------|
| `Webhook URL` | Firebase function URL | `https://asia-south1-.../ingestTransaction` |
| `API Key` | Your `WEBHOOK_API_KEY` | (from Firebase secrets) |
| `Bank Name` | Your bank — **fixed, sent every time** | `HBL`, `UBL`, `Meezan` |

## Input

| Input | Type | Required |
|-------|------|----------|
| `Message` | Text | Yes |
| `Idempotency Key` | Text | No (auto-generated if empty) |

## JSON body sent to webhook

```json
{
  "raw": "<Shortcut Input>",
  "source": "ios_shortcut",
  "bank": "<Bank Name constant>",
  "receivedAt": "<ISO 8601>",
  "idempotencyKey": "<UUID>"
}
```

The `bank` field overrides AI detection on the server.

## Actions (in order)

0. **If** Shortcut Input contains `OTP` → **Stop** (skip, no webhook)  
0b. **If** Shortcut Input contains `otp` → **Stop**  
1. **Text** → API Key  
2. **Text** → Bank Name  
3. **Text** → Webhook URL  
4. **UUID** → Idempotency Key (or use provided input)  
5. **Format Date** → ISO 8601 → Received At  
6. **Get Contents of URL** → POST, headers `X-API-Key` + `Content-Type`, JSON body above  
7. **Get Dictionary from Input** → parse response  
8. **Return** response dictionary  

## Output

| Key | Meaning |
|-----|---------|
| `success` | `true` / `false` |
| `transactionId` | Firestore transaction ID |
| `ingestionId` | Audit log ID |
| `duplicate` | Same transaction already existed |
| `error` | Parse or other error |
