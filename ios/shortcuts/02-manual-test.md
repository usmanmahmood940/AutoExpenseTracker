# Shortcut 2 — Expense: Manual Test Log

> **iPhone setup:** see [`../IPHONE-UPDATE-GUIDE.md`](../IPHONE-UPDATE-GUIDE.md)  
> **Import file:** [`../export/Expense - Manual Test Log.shortcut`](../export/Expense%20-%20Manual%20Test%20Log.shortcut)

For testing without waiting for a real bank SMS. Asks you to paste a message, sends it to the webhook, shows the result.

## Manual changes on iPhone

Usually **none** — this shortcut calls **Expense - Send to Webhook**, which already has your bank name.

1. Open shortcut → verify **Run Shortcut** points to **Expense - Send to Webhook**
2. Run test → confirm Firestore transaction has correct `bank` field

## Prerequisites

- Shortcut **0** (`Expense: Send to Webhook`) built

## Actions (in order)

### 1. Ask for message
- **Ask for Input** with prompt:
  ```
  Paste bank SMS or email text:
  ```
- Input type: **Text**
- **Set variable** `Message`

### 2. Send to webhook
- **Run Shortcut** → **Expense: Send to Webhook**
  - `Message` → `Message`
  - `Idempotency Key` → (leave empty)

### 3. Build status text
- **Get Dictionary Value** from `Shortcut Result`:
  - `success` → `Success`
  - `transactionId` → `Transaction ID`
  - `ingestionId` → `Ingestion ID`
  - `duplicate` → `Duplicate`
  - `error` → `Error`

- **Text** (multi-line):
  ```
  Success: [Success]
  Transaction: [Transaction ID]
  Ingestion: [Ingestion ID]
  Duplicate: [Duplicate]
  Error: [Error]
  ```
- **Set variable** `Status Text`

### 4. Show result
- **Choose from Menu**:
  - **Show Result** → **Show Content** → `Status Text`
  - **Show Alert** → Title: `Expense Log Result`, Message: `Status Text`

> Use **Show Content** for copy-paste; **Show Alert** for a quick OK/dismiss.

## Optional: show raw JSON

After step 2, add:
- **Get Dictionary from** `Shortcut Result`
- **Show Content** → formatted JSON (use **Dictionary** → **Convert to JSON** if available)

## Testing tips

1. Copy a real bank SMS from Messages app
2. Run this shortcut from home screen or Siri: *"Manual Test Log"*
3. Check Firestore console for `transactions` and `raw_ingestions`
4. Run again with the **same** message — should get `duplicate: true` (dedup working)

## Sample test message

```
PKR 5,990.00 charged at PSO RANGERS>LAH for card used, from A/C xxx1215 (DHA PHASE VIII BR LHR) on 06-Jul-2026 at 11:27 TID:387522
```
