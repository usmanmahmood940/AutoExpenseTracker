"""AES-256-GCM field encryption round-trips and failure modes."""

from __future__ import annotations

import base64

import pytest

from app.core.config import Settings
from app.services.field_crypto import (
    EncryptionError,
    decrypt_ciphertext,
    encrypt_plaintext,
    is_encrypted,
    maybe_decrypt,
    require_persistent_key,
)


def test_round_trip_with_aad() -> None:
    blob = encrypt_plaintext("HBL: PKR 200 at PSO", aad="user-1")
    assert is_encrypted(blob)
    assert decrypt_ciphertext(blob, aad="user-1") == "HBL: PKR 200 at PSO"


def test_wrong_aad_fails() -> None:
    blob = encrypt_plaintext("secret", aad="user-a")
    with pytest.raises(EncryptionError):
        decrypt_ciphertext(blob, aad="user-b")


def test_tampered_blob_fails() -> None:
    blob = encrypt_plaintext("secret", aad="user-a")
    raw = bytearray(base64.b64decode(blob[3:]))
    raw[-1] ^= 0x01
    tampered = "v1:" + base64.b64encode(bytes(raw)).decode("ascii")
    with pytest.raises(EncryptionError):
        decrypt_ciphertext(tampered, aad="user-a")


def test_maybe_decrypt_leaves_legacy_plaintext() -> None:
    assert maybe_decrypt("PKR 99 charged at PSO") == "PKR 99 charged at PSO"
    assert maybe_decrypt("") == ""


def test_require_persistent_key_rejects_ephemeral() -> None:
    settings = Settings(
        database_url="postgresql+asyncpg://u:p@localhost:5432/db",
        environment="local",
        field_encryption_key=None,
        _env_file=None,
    )
    with pytest.raises(RuntimeError, match="FIELD_ENCRYPTION_KEY"):
        require_persistent_key(settings)
