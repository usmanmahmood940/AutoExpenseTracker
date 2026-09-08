"""Build RAG document text from structured transaction columns only.

Never reads raw_ingestions.raw or sms_source — those stay encrypted at rest.
"""

from __future__ import annotations

import hashlib
from dataclasses import dataclass
from datetime import date
from typing import Any

from app.db.models.enums import TransactionStatus
from app.db.models.transaction import Transaction
from app.services.merchant_keywords import keyword_suffix
from app.services.money import as_money
from app.services.transactions import SUMMABLE_STATUSES

# Bump whenever the document text format changes. Folded into every
# fingerprint so a reindex re-embeds existing rows instead of skipping them
# on an unchanged fingerprint.
DOC_SCHEMA_VERSION = 3


def _enum_value(value: Any) -> str:
    return value.value if hasattr(value, "value") else str(value)


def build_transaction_doc(tx: Transaction) -> str:
    amount = as_money(tx.amount)
    doc = (
        f"{tx.transaction_date.isoformat()} | {_enum_value(tx.type)} | "
        f"{tx.currency} {amount} | {tx.merchant} | {tx.category} | "
        f"{tx.payment_method}"
    )
    if _enum_value(tx.status) == TransactionStatus.settled.value:
        original_amount = getattr(tx, "original_amount", None)
        original = as_money(original_amount) if original_amount is not None else amount
        doc = f"{doc} | settled net {amount} original {original}"
    keywords = keyword_suffix(tx.merchant or "")
    return f"{doc} | {keywords}" if keywords else doc


def doc_fingerprint(tx: Transaction) -> str:
    original_amount = getattr(tx, "original_amount", None)
    original = str(as_money(original_amount)) if original_amount is not None else ""
    payload = "|".join(
        [
            str(DOC_SCHEMA_VERSION),
            str(as_money(tx.amount)),
            original,
            tx.merchant_normalized or "",
            tx.category or "",
            tx.transaction_date.isoformat(),
            _enum_value(tx.status),
            _enum_value(tx.type),
        ]
    )
    return hashlib.sha256(payload.encode()).hexdigest()


def should_index_transaction(tx: Transaction) -> bool:
    status = _enum_value(tx.status)
    return status in {item.value for item in SUMMABLE_STATUSES}


@dataclass(frozen=True)
class MerchantStats:
    merchant: str
    merchant_normalized: str
    visit_count: int
    total: Any
    average: Any
    last_date: date
    currency: str


def build_merchant_doc(stats: MerchantStats) -> str:
    total = as_money(stats.total)
    average = as_money(stats.average)
    doc = (
        f"merchant | {stats.merchant} | {stats.visit_count} visits | "
        f"total {stats.currency} {total} | avg {stats.currency} {average} | "
        f"last {stats.last_date.isoformat()}"
    )
    keywords = keyword_suffix(stats.merchant or "")
    return f"{doc} | {keywords}" if keywords else doc


def merchant_fingerprint(stats: MerchantStats) -> str:
    payload = "|".join(
        [
            str(DOC_SCHEMA_VERSION),
            stats.merchant_normalized,
            str(stats.visit_count),
            str(as_money(stats.total)),
            stats.last_date.isoformat(),
        ]
    )
    return hashlib.sha256(payload.encode()).hexdigest()


def build_period_doc(summary: dict) -> str:
    year_month = summary.get("year_month") or ""
    currency = summary.get("currency") or "PKR"
    spent = as_money(summary.get("total_debit") or 0)
    received = as_money(summary.get("total_credit") or 0)
    net = as_money(summary.get("net") or 0)
    net_sign = "+" if float(net) >= 0 else ""
    categories = summary.get("by_category") or {}
    top = sorted(categories.items(), key=lambda item: item[1], reverse=True)[:3]
    top_names = ", ".join(name for name, _ in top) or "none"
    return (
        f"period | {year_month} | spent {currency} {spent} | "
        f"received {currency} {received} | net {net_sign}{net} | top {top_names}"
    )


def period_fingerprint(summary: dict) -> str:
    payload = "|".join(
        [
            str(DOC_SCHEMA_VERSION),
            str(summary.get("year_month") or ""),
            str(summary.get("transaction_count") or 0),
            str(as_money(summary.get("total_debit") or 0)),
            str(as_money(summary.get("total_credit") or 0)),
            str(summary.get("source_updated_at") or ""),
        ]
    )
    return hashlib.sha256(payload.encode()).hexdigest()
