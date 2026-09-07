"""Shared LIKE/ILIKE pattern escaping.

Callers must pass `escape="\\\\"` to SQLAlchemy's `like`/`ilike` alongside the
escaped value.
"""

from __future__ import annotations

import re

_LIKE_SPECIAL = re.compile(r"([\\%_])")


def escape_like(value: str) -> str:
    return _LIKE_SPECIAL.sub(r"\\\1", value)


def contains_pattern(value: str) -> str:
    """`%value%` with LIKE metacharacters in `value` neutralised."""
    return f"%{escape_like(value)}%"
