#!/usr/bin/env python3
"""Backfill merchant_concepts for distinct transaction merchants.

Usage:
  .venv/bin/python -m scripts.backfill_merchant_concepts
  .venv/bin/python -m scripts.backfill_merchant_concepts --limit 100
"""

from __future__ import annotations

import argparse
import asyncio
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from app.core.config import get_settings
from app.db.session import dispose_engine, get_sessionmaker
from app.services.semantic.enrichment import backfill_merchant_concepts


async def _run(limit: int) -> dict[str, int]:
    settings = get_settings()
    async with get_sessionmaker()() as session:
        return await backfill_merchant_concepts(
            session, settings=settings, limit=limit
        )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--limit", type=int, default=200)
    args = parser.parse_args()
    try:
        stats = asyncio.run(_run(args.limit))
    finally:
        asyncio.run(dispose_engine())
    print(stats)


if __name__ == "__main__":
    main()
