"""Supported currencies. Keep in sync with `functions/src/currencies.ts`."""

from __future__ import annotations

CURRENCIES = (
    "PKR",
    "USD",
    "EUR",
    "GBP",
    "AED",
    "SAR",
    "INR",
    "CAD",
    "AUD",
    "CHF",
    "JPY",
)

DEFAULT_CURRENCY = "PKR"

_SET = set(CURRENCIES)
_LEGACY: dict[str, str] = {
    "pkr": "PKR",
    "rs": "PKR",
    "rs.": "PKR",
    "usd": "USD",
    "$": "USD",
    "eur": "EUR",
    "€": "EUR",
    "gbp": "GBP",
    "£": "GBP",
    "aed": "AED",
    "sar": "SAR",
    "inr": "INR",
    "cad": "CAD",
    "aud": "AUD",
    "chf": "CHF",
    "jpy": "JPY",
    "¥": "JPY",
}


def normalize_currency(raw: str | None) -> str:
    if raw is None:
        return DEFAULT_CURRENCY
    key = raw.strip()
    if not key:
        return DEFAULT_CURRENCY
    upper = key.upper()
    if upper in _SET:
        return upper
    return _LEGACY.get(key.lower(), DEFAULT_CURRENCY)
