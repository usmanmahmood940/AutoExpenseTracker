"""Canonical payment rails. Keep in sync with `functions/src/payment_methods.ts`."""

from __future__ import annotations

import re

PAYMENT_METHODS = (
    "debit_card",
    "credit_card",
    "bank_transfer",
    "wallet",
    "cash",
    "cheque",
    "atm_withdrawal",
    "qr",
    "other",
    "unknown",
)

DEFAULT_PAYMENT_METHOD = "unknown"

_SET = set(PAYMENT_METHODS)
_WS = re.compile(r"\s+")

_LEGACY: dict[str, str] = {
    "debit_card": "debit_card",
    "debit": "debit_card",
    "debit card": "debit_card",
    "card": "debit_card",
    "credit_card": "credit_card",
    "credit": "credit_card",
    "credit card": "credit_card",
    "bank_transfer": "bank_transfer",
    "transfer": "bank_transfer",
    "account": "bank_transfer",
    "bank": "bank_transfer",
    "ibft": "bank_transfer",
    "raast": "bank_transfer",
    "wallet": "wallet",
    "jazzcash": "wallet",
    "easypaisa": "wallet",
    "nayapay": "wallet",
    "sadapay": "wallet",
    "cash": "cash",
    "cheque": "cheque",
    "check": "cheque",
    "atm_withdrawal": "atm_withdrawal",
    "atm": "atm_withdrawal",
    "atm withdrawal": "atm_withdrawal",
    "qr": "qr",
    "qr_payment": "qr",
    "qr payment": "qr",
    "other": "other",
    "unknown": "unknown",
}


def normalize_payment_method(raw: str | None) -> str:
    if raw is None:
        return DEFAULT_PAYMENT_METHOD
    key = _WS.sub(" ", raw.strip().lower())
    if not key:
        return DEFAULT_PAYMENT_METHOD
    if key in _SET:
        return key
    return _LEGACY.get(key, DEFAULT_PAYMENT_METHOD)
