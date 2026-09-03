"""Response models for Phase C product routes."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, field_serializer, field_validator

from app.db.models.enums import (
    CategoryType,
    ExternalIdType,
    IngestionSource,
    IngestionStatus,
    TransactionStatus,
    TransactionType,
)
from app.services.money import money_float


class SmsSourceOut(BaseModel):
    raw: str = ""
    source: str = "manual"
    received_at: datetime | str | None = None
    message_id: str | None = None
    idempotency_key: str | None = None


class TransactionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    amount: Decimal
    currency: str
    type: TransactionType
    merchant: str
    merchant_details: str | None
    merchant_normalized: str
    is_recurring: bool
    recurring_group_id: str | None
    category: str
    category_source: str
    payment_method: str
    bank: str
    account_id: str
    account_id_masked: str
    branch: str | None
    transaction_time: str
    transaction_date: date
    day: str
    external_id: str | None
    external_id_type: ExternalIdType
    dedup_key: str
    sms_source: SmsSourceOut = Field(default_factory=SmsSourceOut)
    parse_confidence: Decimal
    is_auto_detected: bool
    is_edited: bool
    is_duplicate: bool
    status: TransactionStatus
    reviewed_at: datetime | None
    created_at: datetime
    updated_at: datetime

    @field_validator("sms_source", mode="before")
    @classmethod
    def _coerce_sms_source(cls, value: Any) -> Any:
        if value is None:
            return {}
        return value

    @field_serializer("amount", "parse_confidence")
    def _money(self, value: Decimal) -> float:
        return money_float(value)

    @field_serializer("transaction_date")
    def _date(self, value: date) -> str:
        return value.isoformat()


class TransactionListOut(BaseModel):
    items: list[TransactionOut]
    next_cursor: str | None
    has_more: bool
    total_count: int | None = None
    total_amount: float | None = None
    sort_by: str | None = None
    order_by: str | None = None
    date_from: str | None = None
    date_to: str | None = None


class SearchListOut(BaseModel):
    items: list[TransactionOut]
    next_cursor: str | None
    has_more: bool
    total_count: int | None = None
    total_spent: float | None = None
    total_received: float | None = None
    sort_by: str | None = None
    order_by: str | None = None


class HighlightOut(BaseModel):
    id: uuid.UUID
    amount: float
    merchant: str
    merchant_normalized: str
    category: str
    transaction_date: str
    type: str
    currency: str


class PeriodComparisonOut(BaseModel):
    spent_change_percent: float
    received_change_percent: float
    net_change_percent: float


class PeriodStatsOut(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    period: str
    from_: str = Field(serialization_alias="from")
    to: str
    currency: str
    spent: float
    received: float
    net: float
    highest_spend: HighlightOut | None
    highest_receive: HighlightOut | None
    comparison: PeriodComparisonOut | None


class TopMerchantOut(BaseModel):
    display_name: str
    merchant_normalized: str
    amount: float
    visit_count: int


class MonthlySummaryOut(BaseModel):
    year_month: str = ""
    date_from: str | None = None
    date_to: str | None = None
    currency: str
    total_debit: float
    total_credit: float
    net: float
    transaction_count: int
    by_category: dict[str, float]
    top_merchants_spent: list[TopMerchantOut] = Field(default_factory=list)
    top_merchants_received: list[TopMerchantOut] = Field(default_factory=list)
    top_merchants_by_visits: list[TopMerchantOut] = Field(default_factory=list)


class TrendPointOut(BaseModel):
    date: str
    debit: float


class TrendOut(BaseModel):
    bucket: str
    currency: str
    points: list[TrendPointOut]


class RecurringMerchantOut(BaseModel):
    display_name: str
    merchant_normalized: str
    count: int
    average_amount: float
    last_date: str


class RecurringListOut(BaseModel):
    items: list[RecurringMerchantOut]


class NarrativeOut(BaseModel):
    narrative: str | None = None
    source: str = "none"
    model: str | None = None


class MonthlySummaryListOut(BaseModel):
    items: list[MonthlySummaryOut]


class MerchantSummaryOut(BaseModel):
    merchant_normalized: str
    display_name: str
    currency: str
    total_spent: float
    visit_count: int
    average_spent: float
    this_month_spent: float
    this_month_visits: int


class IngestionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    raw: str
    source: IngestionSource
    received_at: datetime
    message_id: str | None
    idempotency_key: str | None
    status: IngestionStatus
    transaction_id: uuid.UUID | None
    error: str | None
    created_at: datetime
    updated_at: datetime


class ReviewQueueOut(BaseModel):
    needs_review: list[TransactionOut]
    needs_parse: list[IngestionOut]
    duplicates: list[IngestionOut]
    pending_count: int


class CategoryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    slug: str
    name: str
    type: CategoryType
    icon: str
    color: str
    sort_order: int
    is_default: bool
    created_at: datetime
    updated_at: datetime


class MerchantOverrideOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    merchant_key: str
    display_name: str
    category: str
