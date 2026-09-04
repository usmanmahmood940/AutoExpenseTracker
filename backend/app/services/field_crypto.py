"""AES-256-GCM helpers for Option A field-level encryption of SMS payloads.

Wire format: ``v1:`` + standard base64(iv ‖ ciphertext ‖ tag).
AAD, when provided, is bound into the tag so a blob cannot be copied onto
another user's row.
"""

from __future__ import annotations

import base64
import logging
import secrets
from typing import Final

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from app.core.config import Settings, get_settings

logger = logging.getLogger(__name__)

VERSION_PREFIX: Final = "v1:"
_NONCE_LEN: Final = 12
_KEY_LEN: Final = 32

_ephemeral_dek: bytes | None = None


class EncryptionError(Exception):
    """Stored ciphertext could not be decrypted with the current key."""


def _decode_key(raw: str) -> bytes:
    try:
        key = base64.b64decode(raw.strip(), validate=True)
    except (ValueError, TypeError) as exc:
        raise ValueError("FIELD_ENCRYPTION_KEY must be standard base64") from exc
    if len(key) != _KEY_LEN:
        raise ValueError(
            f"FIELD_ENCRYPTION_KEY must decode to {_KEY_LEN} bytes, got {len(key)}"
        )
    return key


def dek_bytes(settings: Settings | None = None) -> bytes:
    """Return the active data-encryption key.

    Staging/prod require ``FIELD_ENCRYPTION_KEY``. Local may generate an
    ephemeral key (logged once) so ingest still works without setup — the same
    pattern as ``otp_hash_secret``.
    """
    global _ephemeral_dek
    settings = settings or get_settings()
    configured = (settings.field_encryption_key or "").strip()
    if configured:
        return _decode_key(configured)
    if settings.environment != "local":
        raise RuntimeError("FIELD_ENCRYPTION_KEY is not configured")
    if _ephemeral_dek is None:
        _ephemeral_dek = secrets.token_bytes(_KEY_LEN)
        logger.warning(
            "field_encryption_key_unset",
            extra={
                "hint": "set FIELD_ENCRYPTION_KEY so encrypted SMS survives a restart"
            },
        )
    return _ephemeral_dek


def using_ephemeral_key(settings: Settings | None = None) -> bool:
    settings = settings or get_settings()
    return not (settings.field_encryption_key or "").strip()


def require_persistent_key(settings: Settings | None = None) -> None:
    """Refuse migrate/backfill when the DEK would be process-local."""
    if using_ephemeral_key(settings):
        raise RuntimeError("FIELD_ENCRYPTION_KEY is required (openssl rand -base64 32)")


def is_encrypted(blob: str | None) -> bool:
    return bool(blob) and blob.startswith(VERSION_PREFIX)


def encrypt_plaintext(plaintext: str, *, aad: str | None = None) -> str:
    nonce = secrets.token_bytes(_NONCE_LEN)
    aad_bytes = aad.encode() if aad else None
    token = AESGCM(dek_bytes()).encrypt(nonce, plaintext.encode(), aad_bytes)
    packed = nonce + token
    return VERSION_PREFIX + base64.b64encode(packed).decode("ascii")


def decrypt_ciphertext(blob: str, *, aad: str | None = None) -> str:
    if not is_encrypted(blob):
        raise EncryptionError("Payload is not encrypted.")
    try:
        packed = base64.b64decode(blob[len(VERSION_PREFIX) :], validate=True)
    except (ValueError, TypeError) as exc:
        raise EncryptionError() from exc
    if len(packed) < _NONCE_LEN + 16:
        raise EncryptionError()
    nonce, token = packed[:_NONCE_LEN], packed[_NONCE_LEN:]
    aad_bytes = aad.encode() if aad else None
    try:
        return AESGCM(dek_bytes()).decrypt(nonce, token, aad_bytes).decode()
    except (InvalidTag, ValueError, UnicodeDecodeError) as exc:
        raise EncryptionError() from exc


def maybe_decrypt(blob: str, *, aad: str | None = None) -> str:
    """Decrypt ``v1:`` blobs; return legacy plaintext unchanged."""
    if not blob:
        return ""
    if is_encrypted(blob):
        return decrypt_ciphertext(blob, aad=aad)
    return blob
