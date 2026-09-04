#!/usr/bin/env python3
"""Run Alembic against SUPABASE_DATABASE_URL from backend/.env.

  cd backend
  make migrate-supabase
  .venv/bin/python scripts/alembic_supabase.py current
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import quote, unquote

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)


def _load_dotenv() -> dict[str, str]:
    from dotenv import dotenv_values

    raw = dotenv_values(".env")
    return {
        key: value.strip().strip('"').strip("'")
        for key, value in raw.items()
        if key and value
    }


def _to_asyncpg(url: str) -> str:
    for prefix in ("postgresql+asyncpg://", "postgres://", "postgresql://"):
        if url.startswith(prefix):
            rest = url[len(prefix) :]
            break
    else:
        raise SystemExit("SUPABASE_DATABASE_URL must be a postgresql:// URL")

    userinfo, hostpart = rest.rsplit("@", 1)
    user, password = userinfo.split(":", 1)
    user, password = unquote(user), unquote(password)

    match = re.search(r"db\.([a-z0-9]+)\.supabase\.co", hostpart)
    if match:
        user = f"postgres.{match.group(1)}"
        host = "aws-0-ap-southeast-1.pooler.supabase.com:5432"
        return (
            f"postgresql+asyncpg://{quote(user, safe='')}:{quote(password, safe='')}"
            f"@{host}/postgres?ssl=require"
        )
    if url.startswith("postgresql+asyncpg://"):
        return url
    return "postgresql+asyncpg://" + url.split("://", 1)[1]


def main() -> None:
    env = _load_dotenv()
    raw = env.get("SUPABASE_DATABASE_URL") or ""
    if not raw:
        raise SystemExit("SUPABASE_DATABASE_URL is missing from backend/.env")
    os.environ["DATABASE_URL"] = _to_asyncpg(raw)
    args = sys.argv[1:] or ["upgrade", "head"]
    raise SystemExit(
        subprocess.call([sys.executable, "-m", "alembic", *args], cwd=ROOT)
    )


if __name__ == "__main__":
    main()
