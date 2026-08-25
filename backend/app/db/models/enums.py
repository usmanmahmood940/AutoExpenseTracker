"""Shared string enums for product tables.

Stored as VARCHAR + an explicit CHECK (see `enum_check`) rather than native
Postgres enums, matching `devices.platform` / `auth_otps.purpose`. Adding a
value later is a constraint swap, not an `ALTER TYPE`.
"""

from __future__ import annotations

from enum import StrEnum


class TransactionType(StrEnum):
    debit = "debit"
    credit = "credit"


class TransactionStatus(StrEnum):
    active = "active"
    deleted = "deleted"
    needs_review = "needs_review"


class ExternalIdType(StrEnum):
    tid = "tid"
    ref = "ref"
    stan = "stan"
    unknown = "unknown"


class IngestionSource(StrEnum):
    ios_shortcut = "ios_shortcut"
    gmail = "gmail"
    manual = "manual"


class IngestionStatus(StrEnum):
    received = "received"
    parsed = "parsed"
    duplicate = "duplicate"
    needs_parse = "needs_parse"
    failed = "failed"


class CategoryType(StrEnum):
    expense = "expense"
    income = "income"
    other = "other"


class PeriodKind(StrEnum):
    today = "today"
    week = "week"
    month = "month"


class TransactionSortBy(StrEnum):
    date = "date"
    amount = "amount"
    merchant = "merchant"


class SortOrder(StrEnum):
    asc = "asc"
    desc = "desc"
