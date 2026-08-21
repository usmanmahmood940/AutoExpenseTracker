"""Duplicate keys + account masking. Port of `functions/src/dedup.ts`."""

from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass

from app.services.merchant_key import normalize_merchant_key

_TIME = re.compile(r"T(\d{2}):(\d{2})")


@dataclass(frozen=True)
class DedupFields:
    amount: float
    currency: str
    account_id: str
    external_id: str | None
    transaction_date: str
    merchant: str
    merchant_details: str | None
    transaction_time: str


def _time_bucket(transaction_time: str) -> str:
    match = _TIME.search(transaction_time)
    if not match:
        return ""
    return f"{match.group(1)}:{match.group(2)}"


def compute_dedup_key(parsed: DedupFields) -> str:
    parts = [
        f"{parsed.amount:.2f}",
        parsed.currency.upper(),
        parsed.account_id,
        parsed.external_id or "",
        parsed.transaction_date,
    ]
    if not parsed.external_id:
        details = (
            normalize_merchant_key(parsed.merchant_details)
            if parsed.merchant_details
            else ""
        )
        parts.extend(
            [
                normalize_merchant_key(parsed.merchant),
                details,
                _time_bucket(parsed.transaction_time),
            ]
        )
    return hashlib.sha256("|".join(parts).encode()).hexdigest()


def mask_account_id(account_id: str) -> str:
    if not account_id or account_id == "Unknown":
        return account_id
    if len(account_id) <= 4:
        return account_id
    return ("x" * (len(account_id) - 4)) + account_id[-4:]
