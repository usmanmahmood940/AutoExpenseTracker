# Shortcut 3 — Expense: Drain Pending Queue

> **iPhone setup:** see [`../IPHONE-UPDATE-GUIDE.md`](../IPHONE-UPDATE-GUIDE.md)  
> **Import file:** [`../export/Expense - Drain Pending (setup).shortcut`](../export/Expense%20-%20Drain%20Pending%20(setup).shortcut) (setup helper — finish manually)

No user input. Reads all `pending` rows from the Numbers sheet, sends each to the webhook **one by one**, updates status on success.

## Manual changes on iPhone

Build the full drain shortcut on device (see **IPHONE-UPDATE-GUIDE** → Shortcut 2 section). Key points:

1. Create Numbers sheet **Expense Pending Queue** (headers: `idempotencyKey`, `raw`, `status`, `createdAt`, `lastError`)
2. **Find Rows Where** `status` = `pending`
3. **Repeat** → **Run Shortcut** → **Expense - Send to Webhook** (bank name included automatically)
4. **Update Row** → `sent` or `failed`
5. **Wait** 2 seconds between rows

## Why one-by-one (not a bulk webhook)?

| One-by-one (recommended) | Bulk webhook |
|--------------------------|--------------|
| Uses existing `ingestTransaction` | Needs new Cloud Function |
| Each message has its own `idempotencyKey` | Partial batch failures are messy |
| Dedup works per transaction | Harder error handling in Shortcuts |
| Retry one failed row easily | Re-send entire batch on failure |
| Shortcuts `Repeat with Each` is simple | More backend + shortcut complexity |

**Verdict:** One-by-one is the right choice for personal use. No backend changes needed.

## Prerequisites

- Shortcut **0** (`Expense: Send to Webhook`) built
- Numbers sheet **Expense Pending Queue** with columns:

| Column | Example |
|--------|---------|
| idempotencyKey | `a1b2c3d4-...` |
| raw | `PKR 5,990.00 charged at...` |
| status | `pending` / `sent` / `failed` |
| createdAt | `2026-07-07T12:00:00+05:00` |
| lastError | (empty or error text) |

## Actions (in order)

### 1. Init counters
- **Set variable** `Sent Count` → `0`
- **Set variable** `Failed Count` → `0`
- **Set variable** `Skipped Count` → `0`

### 2. Check internet
- **Get Network Details** → **Is Connected**
- **If** `Is Connected` **is** `false`:
  - **Show Alert**: `No internet — cannot drain pending queue`
  - **Stop Shortcut**
- **End If**

### 3. Find pending rows
- **Find Rows Where** in spreadsheet **Expense Pending Queue**, sheet **Pending**:
  - Column `status` **is** `pending`
- **Set variable** `Pending Rows`

### 4. Nothing to do?
- **If** `Pending Rows` **has no value** OR count is 0:
  - **Show Alert**: `No pending messages`
  - **Stop Shortcut**
- **End If**

### 5. Process each row
- **Repeat with Each** item in `Pending Rows`:
  
  #### 5a. Read row fields
  - `Row Key` → value from column `idempotencyKey`
  - `Row Message` → value from column `raw`
  - `Row Number` → **Repeat Index** (or row index from Numbers if available)

  #### 5a2. Skip OTP rows
  - **If** `Row Message` **contains** `OTP` OR `otp`:
    - **Update Row** → `status` = `skipped`
    - **Continue** to next row (no webhook)

  #### 5b. Call webhook
  - **Run Shortcut** → **Expense: Send to Webhook**
    - `Message` → `Row Message`
    - `Idempotency Key` → `Row Key`

  #### 5c. On success
  - **Get Dictionary Value** `success` from result
  - **If** `success` **is** `true`:
    - **Update Row** `Row Number` in sheet **Pending**:
      - `status` → `sent`
      - `lastError` → (empty)
    - **Calculate** `Sent Count + 1` → `Sent Count`
    - **Continue** to next row

  #### 5d. On failure
  - **Get Dictionary Value** `error` from result (or use `Contents of URL` error)
  - **Update Row** `Row Number`:
    - `status` → `failed`
    - `lastError` → error text
  - **Calculate** `Failed Count + 1` → `Failed Count`

### 6. Summary
- **Text**:
  ```
  Drain complete
  Sent: [Sent Count]
  Failed: [Failed Count]
  ```
- **Show Alert** or **Show Notification** with summary

## Rate limiting

Gemini can rate-limit if you drain many rows at once. Add inside the **Repeat** loop:

- **Wait** → `2` seconds (after each webhook call)

This matches the backend test harness delay.

## When to run this shortcut

- Manually from home screen / widget
- Siri: *"Drain pending expenses"*
- Automatically at start of **Shortcut 1** (official SMS flow)
- After coming back online

## Status values

| status | Meaning |
|--------|---------|
| `pending` | Waiting to be sent |
| `sent` | Webhook returned `success: true` |
| `skipped` | OTP message — ignored, not retried |
| `failed` | Webhook error or network failure — fix and set back to `pending` manually in Numbers if needed |
