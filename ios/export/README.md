# Importable iOS Shortcuts

Signed `.shortcut` files — AirDrop to iPhone and tap **Add Shortcut**.

| File | Purpose |
|------|---------|
| `Expense - Send to Webhook.shortcut` | POST one SMS to Firebase (import **first**) |
| `Expense - Manual Test Log.shortcut` | Ask for input → webhook → show alert |
| `Expense - Drain Pending (setup).shortcut` | Setup instructions for pending queue |

## Regenerate (macOS)

```bash
python3 ios/generate-shortcuts.py
```

Requires macOS `shortcuts sign` (built into macOS).

## After import

See **[`../IPHONE-UPDATE-GUIDE.md`](../IPHONE-UPDATE-GUIDE.md)** for manual iPhone steps (bank name, Numbers sheet, automation).

1. Paste `WEBHOOK_API_KEY` and **bank name** when prompted (Send to Webhook only)
2. Run **Manual Test Log** with a sample bank SMS
3. For SMS automation + pending queue, see [`../README.md`](../README.md)
