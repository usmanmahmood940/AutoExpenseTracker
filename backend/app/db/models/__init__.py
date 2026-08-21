"""Model package.

Importing every model here gives Alembic autogenerate a complete view of the
metadata from a single import.
"""

from app.db.base import Base
from app.db.models.auth_otp import AuthOtp, OtpPurpose
from app.db.models.auth_rate_limit import AuthRateLimit
from app.db.models.category import Category
from app.db.models.device import Device, DevicePlatform
from app.db.models.enums import (
    CategoryType,
    ExternalIdType,
    IngestionSource,
    IngestionStatus,
    PeriodKind,
    SortOrder,
    TransactionSortBy,
    TransactionStatus,
    TransactionType,
)
from app.db.models.merchant_override import MerchantCategoryOverride
from app.db.models.monthly_summary import MonthlySummary
from app.db.models.password_reset_session import PasswordResetSession
from app.db.models.raw_ingestion import RawIngestion
from app.db.models.transaction import Transaction
from app.db.models.user import User

__all__ = [
    "AuthOtp",
    "AuthRateLimit",
    "Base",
    "Category",
    "CategoryType",
    "Device",
    "DevicePlatform",
    "ExternalIdType",
    "IngestionSource",
    "IngestionStatus",
    "MerchantCategoryOverride",
    "MonthlySummary",
    "OtpPurpose",
    "PasswordResetSession",
    "PeriodKind",
    "RawIngestion",
    "SortOrder",
    "Transaction",
    "TransactionSortBy",
    "TransactionStatus",
    "TransactionType",
    "User",
]
