# iPhone Update Guide — All 3 Shortcuts

Use this if you **already imported** the `.shortcut` files and need to finish setup or add the **bank name** constant.

## Constants to set once (in Shortcut 0 only)

Open **Expense - Send to Webhook** → edit these **Text** actions at the top:

| Action label | Set to | Example |
|--------------|--------|---------|
| **API Key** | Your Firebase `WEBHOOK_API_KEY` | `a8f3k2m9...` |
| **Bank Name** | Your bank (sent with every webhook) | `HBL`, `UBL`, `Meezan` |
| **Webhook URL** | Leave as-is unless you redeployed | `https://asia-south1-auto-expense-tracker-2026.cloudfunctions.net/ingestTransaction` |

## Constants to set once (in Shortcut 0 only)

### If imported from `ios/export/` (generated file)

On import you should have been prompted for API key and bank name. Verify:

1. Open shortcut → first action **Text** = your API key (not `PASTE_YOUR_WEBHOOK_API_KEY_HERE`)
2. Second action **Text** = your bank name (not `PASTE_YOUR_BANK_NAME_HERE`)
3. Third action **Text** = webhook URL
4. **First actions** should be OTP checks (If contains `OTP` → Stop; If contains `otp` → Stop)

### Add OTP filter manually (if missing)

At the **very top** of **Expense - Send to Webhook**, before API Key:

1. **If** `Shortcut Input` **contains** `OTP`
   - **Show Result** → `Skipped: OTP message (not logged)`
   - **Stop Shortcut**
2. **If** `Shortcut Input` **contains** `otp`
   - **Show Result** → `Skipped: OTP message (not logged)`
   - **Stop Shortcut**

### If you built manually OR need to add `bank` field

1. Open **Expense - Send to Webhook**
2. After **API Key** text action, add **Text** action:
   - Content: `HBL` (or your bank)
   - Rename variable: **Bank Name**
3. Tap **Get Contents of URL** → expand **Request Body** → **JSON**
4. Add key:
   - Key: `bank`
   - Value: variable **Bank Name**
5. Full JSON keys should be:

   | Key | Value |
   |-----|-------|
   | `raw` | Shortcut Input |
   | `source` | `ios_shortcut` |
   | `bank` | Bank Name |
   | `receivedAt` | Received At (from Format Date) |
   | `idempotencyKey` | Idempotency Key (from UUID) |

6. **Done** → run a quick test via Shortcut 2

### Redeploy backend first (bank field support)

The Cloud Function must be redeployed after this update:

```bash
cd /Users/m.usmanmahmood/StudioProjects/AutoExpenseTracker
npm run build && npm run deploy:functions
```

---

## Shortcut 1 — Expense: Manual Test Log

Usually **no changes** if Shortcut 0 is configured.

### Verify

1. Open **Expense - Manual Test Log**
2. Confirm **Run Shortcut** action calls **Expense - Send to Webhook**
3. Run shortcut → paste sample SMS → alert should show `Transaction: <id>`

### Optional improvements

| Change | How |
|--------|-----|
| Show bank in alert | After Get Dictionary Value, add key `bank` from response (if you add it to API response later) |
| Copy result | Keep **Show Content** action at the end |

### Sample test SMS

```
PKR 5,990.00 charged at PSO RANGERS>LAH for card used, from A/C xxx1215 (DHA PHASE VIII BR LHR) on 06-Jul-2026 at 11:27 TID:387522
```

---

## Shortcut 2 — Expense: Drain Pending Queue

If you only imported the **setup** placeholder shortcut, build the full drain shortcut manually:

### One-time: Numbers sheet

1. **Numbers** → new spreadsheet **Expense Pending Queue**
2. Sheet name: **Pending**
3. Headers row 1:

   | A | B | C | D | E |
   |---|---|---|---|---|
   | idempotencyKey | raw | status | createdAt | lastError |

### Build drain shortcut

1. **New Shortcut** → name: **Expense - Drain Pending Queue**
2. Add actions in order:

   **A. Check internet**
   - Get Network Details → Is Connected
   - If false → Show Alert "No internet" → Stop

   **B. Find pending rows**
   - Find Rows Where (Numbers → Expense Pending Queue → Pending)
   - Column `status` is `pending`

   **C. Loop**
   - Repeat with Each (pending rows):
     - Get `raw` column → variable **Message**
     - Get `idempotencyKey` column → variable **Key**
     - **Run Shortcut** → **Expense - Send to Webhook**
       - Input: **Message**
       - (Idempotency key: if your Shortcut 0 supports it via second input, pass **Key**; otherwise Shortcut 0 generates new UUID — dedup still works server-side)
     - Get `success` from Shortcut Result
     - If true → **Update Row** → `status` = `sent`
     - Otherwise → **Update Row** → `status` = `failed`, `lastError` = error text
     - **Wait** 2 seconds (avoid Gemini rate limits)

   **D. Summary**
   - Show Alert: "Drain complete"

### No bank changes needed

Drain calls **Send to Webhook**, which already includes your **Bank Name** constant.

---

## Shortcut 3 — Expense: Process Bank SMS (automation)

This is the **official automation** (not in export folder — create on iPhone).

### Create automation

1. **Shortcuts** → **Automation** → **+** → **Message**
2. **Sender** → add bank short codes (`HBL`, etc.)
3. **Message Contains** → optional: `PKR`, `debited`, `charged`
4. **Next** → **Run Shortcut** → **Expense - Process Bank SMS**
5. Enable **Run Immediately**
6. **Done**

### Create shortcut: Expense - Process Bank SMS

1. **New Shortcut** → receives **Shortcut Input** (message text)
2. Actions:
   - **Run Shortcut** → **Expense - Drain Pending Queue**
   - **Get Network Details** → if offline:
     - Add row to Numbers (`status` = `pending`, `raw` = Shortcut Input)
     - Stop
   - **Run Shortcut** → **Expense - Send to Webhook** (Input = Shortcut Input)
   - If `success` false → save to Numbers as `pending`

### Per-bank automations (optional)

If you use **multiple banks**, create one automation per sender, each with a **different bank constant**:

| Automation | Sender | Bank Name in Shortcut 0 |
|------------|--------|-------------------------|
| HBL SMS | HBL | `HBL` |
| UBL SMS | UBL | `UBL` |

Or duplicate **Send to Webhook** as `Expense - Send to Webhook (UBL)` with a different bank Text action.

---

## Webhook body (final reference)

```json
{
  "raw": "PKR 5,990.00 charged at PSO RANGERS...",
  "source": "ios_shortcut",
  "bank": "HBL",
  "receivedAt": "2026-07-07T17:00:00+05:00",
  "idempotencyKey": "uuid-here"
}
```

The `bank` field **overrides** whatever Gemini detects. Set it once in Shortcut 0.

---

## Checklist

- [ ] Backend redeployed (`npm run deploy:functions`)
- [ ] Shortcut 0: API Key set
- [ ] Shortcut 0: Bank Name set (e.g. `HBL`)
- [ ] Shortcut 0: JSON body includes `bank` key
- [ ] Shortcut 2 (Manual Test): works → `transactionId` in alert
- [ ] Firestore `transactions` doc shows `bank: "HBL"`
- [ ] Numbers sheet created (for drain)
- [ ] Shortcut 3 drain built (optional)
- [ ] Automation created for bank SMS (optional)

## Regenerate importable files

After pulling latest code on Mac:

```bash
python3 ios/generate-shortcuts.py
```

Re-AirDrop `ios/export/*.shortcut` to iPhone. You may need to **replace** existing shortcuts (delete old → import new).
