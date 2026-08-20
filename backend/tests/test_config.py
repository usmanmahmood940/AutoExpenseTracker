"""Config parsing, which is where a bad deploy usually starts."""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.core.config import Settings


def _settings(**overrides: object) -> Settings:
    defaults: dict[str, object] = {
        "database_url": "postgresql+asyncpg://u:p@localhost:5432/db",
        "_env_file": None,
    }
    return Settings(**{**defaults, **overrides})  # type: ignore[arg-type]


@pytest.mark.parametrize(
    "given",
    [
        "postgresql://u:p@localhost:5432/db",
        "postgres://u:p@localhost:5432/db",
        "postgresql+asyncpg://u:p@localhost:5432/db",
    ],
)
def test_database_urls_are_normalized_to_asyncpg(given: str) -> None:
    settings = _settings(database_url=given)

    assert settings.database_url == "postgresql+asyncpg://u:p@localhost:5432/db"
    assert settings.sync_database_url == "postgresql://u:p@localhost:5432/db"


def test_non_postgres_urls_are_rejected() -> None:
    with pytest.raises(ValidationError):
        _settings(database_url="sqlite+aiosqlite:///./local.db")


@pytest.mark.parametrize(
    ("given", "expected"),
    [
        ("", []),
        ("https://a.dev", ["https://a.dev"]),
        ("https://a.dev, https://b.dev", ["https://a.dev", "https://b.dev"]),
    ],
)
def test_cors_origins_accept_comma_separated_values(
    given: str, expected: list[str]
) -> None:
    assert _settings(cors_origins=given).cors_origins == expected


def test_json_logging_follows_the_environment() -> None:
    assert _settings(environment="local").log_json is False
    assert _settings(environment="prod").log_json is True
    # An explicit setting always wins.
    assert _settings(environment="prod", log_json=False).log_json is False
