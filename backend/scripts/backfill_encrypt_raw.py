#!/usr/bin/env python3
"""Encrypt legacy plaintext SMS payloads (Option A backfill).

Idempotent. Dual-read in the API keeps working for rows not yet rewritten.

  cd backend
  make backfill-encrypt DRY_RUN=1
  make backfill-encrypt SUPABASE=1 DRY_RUN=1
  make backfill-encrypt SUPABASE=1
  make backfill-encrypt SUPABASE=1 USER_ID=<uuid> LIMIT=50
"""

from __future__ import annotations

import argparse
import asyncio
import logging
import os
import re
import sys
from pathlib import Path
from urllib.parse import quote, unquote
from uuid import UUID

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


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
        raise SystemExit("DATABASE_URL must be a postgresql:// URL")

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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Count rows that would be updated; do not write",
    )
    parser.add_argument("--supabase", action="store_true")
    parser.add_argument("--limit", type=int, default=0, help="0 = all")
    parser.add_argument("--user-id", help="Restrict to one Postgres user UUID")
    return parser.parse_args()


def configure_database(args: argparse.Namespace) -> None:
    env = _load_dotenv()
    if env.get("FIELD_ENCRYPTION_KEY"):
        os.environ.setdefault("FIELD_ENCRYPTION_KEY", env["FIELD_ENCRYPTION_KEY"])
    if args.supabase:
        raw = env.get("SUPABASE_DATABASE_URL") or ""
        if not raw:
            raise SystemExit("SUPABASE_DATABASE_URL is missing from backend/.env")
        os.environ["DATABASE_URL"] = _to_asyncpg(raw)
        return
    if env.get("DATABASE_URL"):
        os.environ.setdefault("DATABASE_URL", env["DATABASE_URL"])


async def backfill(args: argparse.Namespace) -> int:
    from sqlalchemy import select

    from app.core.config import get_settings
    from app.db.models.raw_ingestion import RawIngestion
    from app.db.models.transaction import Transaction
    from app.db.session import dispose_engine, get_sessionmaker
    from app.services.field_crypto import is_encrypted, require_persistent_key
    from app.services.sms_source import (
        encrypt_ingestion_raw,
        encrypt_legacy_sms_source,
    )

    settings = get_settings()
    require_persistent_key(settings)

    user_id = UUID(args.user_id) if args.user_id else None
    ingest_updated = 0
    ingest_would = 0
    tx_updated = 0
    tx_would = 0

    maker = get_sessionmaker()
    async with maker() as session:
        ingest_stmt = select(RawIngestion)
        tx_stmt = select(Transaction)
        if user_id is not None:
            ingest_stmt = ingest_stmt.where(RawIngestion.user_id == user_id)
            tx_stmt = tx_stmt.where(Transaction.user_id == user_id)

        ingestions = list((await session.execute(ingest_stmt)).scalars().all())
        for row in ingestions:
            if is_encrypted(row.raw):
                continue
            ingest_would += 1
            if args.dry_run:
                continue
            if args.limit and ingest_updated + tx_updated >= args.limit:
                break
            row.raw = encrypt_ingestion_raw(row.raw, user_id=row.user_id)
            ingest_updated += 1

        transactions = list((await session.execute(tx_stmt)).scalars().all())
        for tx in transactions:
            hit_limit = (
                args.limit
                and not args.dry_run
                and ingest_updated + tx_updated >= args.limit
            )
            if hit_limit:
                break
            updated = encrypt_legacy_sms_source(tx.sms_source, user_id=tx.user_id)
            if updated is None:
                continue
            tx_would += 1
            if args.dry_run:
                continue
            tx.sms_source = updated
            tx_updated += 1

        if not args.dry_run:
            await session.commit()

    await dispose_engine()
    print(
        "encrypt_backfill "
        f"dry_run={args.dry_run} "
        f"ingestions={ingest_updated if not args.dry_run else ingest_would} "
        f"transactions={tx_updated if not args.dry_run else tx_would}"
    )
    return 0


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    args = parse_args()
    configure_database(args)
    raise SystemExit(asyncio.run(backfill(args)))


if __name__ == "__main__":
    main()
