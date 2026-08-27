"""Merchant grouping key — must match `normalizeMerchantKey` /
`resolveMerchant` in

- `shared/types/schema.ts`
- `functions/src/schema.ts`
- `NovaSpend/lib/core/constants/app_constants.dart`
"""

from __future__ import annotations

import re

_WS = re.compile(r"\s+")

DEFAULT_MERCHANT = "Unknown"
ATM_MERCHANT = "ATM"
_MISSING_MERCHANTS = frozenset({"", "unknown"})
_CASH_WITHDRAWAL_CATEGORIES = frozenset({"cash withdrawal", "cash_withdrawal"})
_ATM_PAYMENT_METHOD = "atm_withdrawal"


def normalize_merchant(merchant: str) -> str:
    return _WS.sub(" ", merchant.strip())


def normalize_merchant_key(merchant: str) -> str:
    return _WS.sub(" ", merchant.strip().lower())


def resolve_merchant(
    merchant: str,
    *,
    category: str = "",
    payment_method: str = "",
) -> str:
    """Stored/display name. Cash withdrawals with no merchant become ATM."""
    trimmed = merchant.strip()
    if (
        trimmed.lower() in _MISSING_MERCHANTS
        and _is_cash_withdrawal(category=category, payment_method=payment_method)
    ):
        return ATM_MERCHANT
    return trimmed or DEFAULT_MERCHANT


def _is_cash_withdrawal(*, category: str, payment_method: str) -> bool:
    return (
        category.strip().lower() in _CASH_WITHDRAWAL_CATEGORIES
        or payment_method.strip().lower() == _ATM_PAYMENT_METHOD
    )
