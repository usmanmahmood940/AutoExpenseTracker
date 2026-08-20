"""Model package.

Importing every model here gives Alembic autogenerate a complete view of the
metadata from a single import.
"""

from app.db.base import Base
from app.db.models.auth_otp import AuthOtp, OtpPurpose
from app.db.models.auth_rate_limit import AuthRateLimit
from app.db.models.device import Device, DevicePlatform
from app.db.models.password_reset_session import PasswordResetSession
from app.db.models.user import User

__all__ = [
    "AuthOtp",
    "AuthRateLimit",
    "Base",
    "Device",
    "DevicePlatform",
    "OtpPurpose",
    "PasswordResetSession",
    "User",
]
