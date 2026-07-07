# Shortcut 1 — Expense: Process Bank SMS (official automation)

> **iPhone setup:** see [`../IPHONE-UPDATE-GUIDE.md`](../IPHONE-UPDATE-GUIDE.md) → **Shortcut 3 — Process Bank SMS**

Runs automatically when you receive a bank SMS.

## Prerequisites

- Shortcut **0** (`Expense: Send to Webhook`) built
- Shortcut **3** (`Expense: Drain Pending Queue`) built
- Numbers sheet **Expense Pending Queue** set up (see `ios/README.md`)

## Automation setup (one-time)

1. Open **Shortcuts** → **Automation** tab → **+**
2. Choose **Message**
3. Configure:
   - **Message Contains** → leave empty OR add keywords like `PKR`, `debited`, `charged`
   - **Sender** → add your bank short codes (e.g. `HBL`, `UBL`, `Meezan`)
4. Tap **Next**
5. Add action: **Run Shortcut** → select **Expense: Process Bank SMS**
6. Turn on **Run Immediately** (important — no confirmation tap)
7. Turn off **Notify When Run** (optional, reduces noise)
8. Tap **Done**

> iOS may still delay automations in Low Power Mode or when the phone is locked for long periods. Use Shortcut 3 to drain pending rows manually.

## Shortcut actions (Expense: Process Bank SMS)

This is a **regular shortcut** (not the automation itself). The automation only runs this shortcut.

### 1. Receive SMS text
- Shortcut receives **Shortcut Input** = message body from automation

### 2. Skip OTP messages
- **If** Shortcut Input **contains** `OTP` → **Stop Shortcut** (no webhook, no pending)
- **If** Shortcut Input **contains** `otp` → **Stop Shortcut**

### 3. Drain pending first
- **Run Shortcut** → **Expense: Drain Pending Queue**
- (Processes any offline/failed messages before the new one)

### 4. Check internet
- **Get Network Details** → **Is Connected**
- **If** `Is Connected` **is** `false`:
  - **Run Shortcut** → **Expense: Save Pending to Sheet** with:
    - `Message` → Shortcut Input
    - `Idempotency Key` → (empty)
  - **Stop and output** → `Saved offline — will sync later`
  - **End If**

### 4. Send current message
- **Run Shortcut** → **Expense: Send to Webhook**
  - `Message` → Shortcut Input
  - `Idempotency Key` → (empty — new UUID each time)

### 5. Handle webhook result
- **Get Dictionary Value** `success` from `Shortcut Result`
- **If** `success` **is** `true`:
  - **Stop and output** → `Logged`
  - **End If**

### 6. On failure — queue for retry
- **Run Shortcut** → **Expense: Save Pending to Sheet**
  - `Message` → Shortcut Input
  - `Idempotency Key` → from webhook payload if you passed one, else empty
- **Stop and output** → `Webhook failed — saved to pending queue`

## Helper shortcut — Expense: Save Pending to Sheet

Small helper used by Shortcut 1 and worth building separately.

### Input
- `Message` (text)
- `Idempotency Key` (optional text)

### Actions
1. **If** `Message` **contains** `OTP` → **Stop Shortcut**
2. **If** `Message` **contains** `otp` → **Stop Shortcut**
3. **If** `Idempotency Key` has no value → **Generate UUID** → `Key`
4. **Otherwise** → `Key` = `Idempotency Key`
5. **Current Date** → ISO 8601 → `Created At`
6. **Add Row** to Numbers spreadsheet **Expense Pending Queue**, sheet **Pending**:
   | idempotencyKey | raw | status | createdAt | lastError |
   |----------------|-----|--------|-----------|-----------|
   | Key | Message | pending | Created At | (empty) |
