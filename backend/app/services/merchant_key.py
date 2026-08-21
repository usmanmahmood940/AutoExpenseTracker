"""Merchant grouping key — must match `normalizeMerchantKey` in

- `shared/types/schema.ts`
- `NovaSpend/lib/core/constants/app_constants.dart`
"""

from __future__ import annotations

import re

_WS = re.compile(r"\s+")


def normalize_merchant(merchant: str) -> str:
    return _WS.sub(" ", merchant.strip())


def normalize_merchant_key(merchant: str) -> str:
    return _WS.sub(" ", merchant.strip().lower())
