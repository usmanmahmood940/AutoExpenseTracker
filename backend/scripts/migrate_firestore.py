#!/usr/bin/env python3
"""Copy Firestore product data into Postgres (migration plan §6 step 5).

Dev/staging target is the same Supabase DB Cloud Run uses. Local Homebrew is
only for trying the script without touching shared data.

  cd backend
  make migrate-firestore DRY_RUN=1          # counts only, writes to DATABASE_URL
  make migrate-firestore SUPABASE=1 DRY_RUN=1
  make migrate-firestore SUPABASE=1         # actually copy into Cloud Run's DB
  make migrate-firestore SUPABASE=1 UID=firebaseUidHere
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
        help="Count rows that would be inserted; do not write",
    )
    parser.add_argument("--uid", help="Migrate a single Firebase Auth uid")
    parser.add_argument(
        "--supabase",
        action="store_true",
        help="Write to SUPABASE_DATABASE_URL (Cloud Run / Flutter backend)",
    )
    parser.add_argument(
        "--limit-users",
        type=int,
        default=0,
        help="Stop after N users (0 = all)",
    )
    return parser.parse_args()


def configure_database(args: argparse.Namespace) -> None:
    env = _load_dotenv()
    if args.supabase:
        raw = env.get("SUPABASE_DATABASE_URL") or ""
        if not raw:
            raise SystemExit("SUPABASE_DATABASE_URL is missing from backend/.env")
        os.environ["DATABASE_URL"] = _to_asyncpg(raw)
        return
    if env.get("DATABASE_URL"):
        os.environ.setdefault("DATABASE_URL", env["DATABASE_URL"])


async def _stream_docs(db: object, uid: str, collection: str) -> list[tuple[str, dict]]:
    col = db.collection("users").document(uid).collection(collection)
    out: list[tuple[str, dict]] = []
    for snap in col.stream():
        data = snap.to_dict() or {}
        out.append((snap.id, data))
    return out


async def migrate(args: argparse.Namespace) -> int:
    from firebase_admin import auth as firebase_auth
    from firebase_admin import firestore

    from app.core.config import get_settings
    from app.core.firebase import init_firebase, require_app
    from app.db.models.transaction import Transaction
    from app.db.session import dispose_engine, get_sessionmaker
    from app.services.firestore_migrate import (
        MigrateCounts,
        copy_custom_category,
        copy_override,
        copy_summary,
        ingestion_kwargs,
        insert_if_new,
        transaction_kwargs,
        upsert_user,
        user_fields_from_doc,
    )

    settings = get_settings()
    init_firebase(settings)
    app = require_app()
    db = firestore.client(app=app)

    uids: list[str] = []
    emails: dict[str, tuple[str, bool]] = {}
    if args.uid:
        uids = [args.uid]
        try:
            record = firebase_auth.get_user(args.uid, app=app)
            emails[args.uid] = (
                (record.email or f"{args.uid}@users.novaspend.invalid"),
                bool(record.email_verified),
            )
        except firebase_auth.UserNotFoundError:
            emails[args.uid] = (f"{args.uid}@users.novaspend.invalid", False)
    else:
        page = firebase_auth.list_users(app=app)
        while page is not None:
            for record in page.users:
                uids.append(record.uid)
                emails[record.uid] = (
                    (record.email or f"{record.uid}@users.novaspend.invalid"),
                    bool(record.email_verified),
                )
            page = page.get_next_page() if page.has_next_page else None
        for snap in db.collection("users").stream():
            if snap.id not in emails:
                uids.append(snap.id)
                emails[snap.id] = (f"{snap.id}@users.novaspend.invalid", False)

    if args.limit_users:
        uids = uids[: args.limit_users]

    counts = MigrateCounts()
    maker = get_sessionmaker()
    logging.info(
        "migrate_start",
        extra={
            "users": len(uids),
            "dry_run": args.dry_run,
            "database": settings.database_url.split("@")[-1],
        },
    )

    try:
        for i, uid in enumerate(uids, start=1):
            logging.info("migrate_user %s/%s uid=%s", i, len(uids), uid[:8])
            profile_snap = db.collection("users").document(uid).get()
            profile = profile_snap.to_dict() if profile_snap.exists else {}
            email, verified = emails.get(uid, (f"{uid}@users.novaspend.invalid", False))
            fields = user_fields_from_doc(
                profile or {}, email=email, email_verified=verified
            )

            async with maker() as session:
                user = await upsert_user(
                    session,
                    firebase_uid=uid,
                    fields=fields,
                    counts=counts,
                    dry_run=args.dry_run,
                )
                if user is None:
                    if not args.dry_run:
                        await session.commit()
                    continue
                user_pk = user.id
                if not args.dry_run:
                    await session.commit()

                for doc_id, data in await _stream_docs(db, uid, "transactions"):
                    kwargs = transaction_kwargs(
                        uid=uid, doc_id=doc_id, user_id=user_pk, data=data
                    )
                    if kwargs is None:
                        counts.add_error(f"tx {uid}/{doc_id}: missing date/amount")
                        continue
                    await insert_if_new(
                        session,
                        Transaction,
                        kwargs,
                        counts,
                        "transactions",
                        args.dry_run,
                    )

                from app.db.models.raw_ingestion import RawIngestion

                for doc_id, data in await _stream_docs(db, uid, "raw_ingestions"):
                    kwargs = ingestion_kwargs(
                        uid=uid, doc_id=doc_id, user_id=user_pk, data=data
                    )
                    if kwargs is None:
                        counts.add_error(f"ingestion {uid}/{doc_id}: empty raw")
                        continue
                    tx_id = kwargs.get("transaction_id")
                    if (
                        tx_id is not None
                        and await session.get(Transaction, tx_id) is None
                    ):
                        kwargs["transaction_id"] = None
                    await insert_if_new(
                        session,
                        RawIngestion,
                        kwargs,
                        counts,
                        "ingestions",
                        args.dry_run,
                    )

                for doc_id, data in await _stream_docs(db, uid, "categories"):
                    await copy_custom_category(
                        session,
                        user_id=user_pk,
                        doc_id=doc_id,
                        data=data,
                        counts=counts,
                        dry_run=args.dry_run,
                    )

                for _doc_id, data in await _stream_docs(
                    db, uid, "merchantCategoryOverrides"
                ):
                    await copy_override(
                        session,
                        user_id=user_pk,
                        data=data,
                        counts=counts,
                        dry_run=args.dry_run,
                    )

                for doc_id, data in await _stream_docs(db, uid, "monthlySummaries"):
                    await copy_summary(
                        session,
                        user_id=user_pk,
                        doc_id=doc_id,
                        data=data,
                        counts=counts,
                        dry_run=args.dry_run,
                    )

                if args.dry_run:
                    await session.rollback()
                else:
                    await session.commit()
        await _print_count_check(db, uids, maker)
    finally:
        await dispose_engine()

    print(
        f"users_created={counts.users} users_updated={counts.users_updated} "
        f"transactions={counts.transactions} ingestions={counts.ingestions} "
        f"categories={counts.categories} overrides={counts.overrides} "
        f"summaries={counts.summaries} skipped={counts.skipped} "
        f"errors={len(counts.errors)}"
    )
    for message in counts.errors[:20]:
        print(f"  skip: {message}", file=sys.stderr)
    if len(counts.errors) > 20:
        print(f"  … {len(counts.errors) - 20} more", file=sys.stderr)
    return 0


async def _print_count_check(db: object, uids: list[str], maker: object) -> None:
    """Compare Firestore vs Postgres totals after the copy (Phase F step 5)."""
    from sqlalchemy import func, select

    from app.db.models.monthly_summary import MonthlySummary
    from app.db.models.raw_ingestion import RawIngestion
    from app.db.models.transaction import Transaction
    from app.db.models.user import User

    fs_tx = fs_ing = fs_sum = 0
    for uid in uids:
        txs = db.collection("users").document(uid).collection("transactions")
        fs_tx += len(list(txs.stream()))
        fs_ing += len(
            list(db.collection("users").document(uid).collection("raw_ingestions").stream())
        )
        fs_sum += len(
            list(db.collection("users").document(uid).collection("monthlySummaries").stream())
        )

    async with maker() as session:
        pg_users = (await session.execute(select(func.count()).select_from(User))).scalar_one()
        pg_tx = (await session.execute(select(func.count()).select_from(Transaction))).scalar_one()
        pg_ing = (await session.execute(select(func.count()).select_from(RawIngestion))).scalar_one()
        pg_sum = (
            await session.execute(select(func.count()).select_from(MonthlySummary))
        ).scalar_one()

    print(
        "count_check "
        f"firestore_users={len(uids)} pg_users={pg_users} "
        f"firestore_tx={fs_tx} pg_tx={pg_tx} "
        f"firestore_ing={fs_ing} pg_ing={pg_ing} "
        f"firestore_summaries={fs_sum} pg_summaries={pg_sum}"
    )


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    args = parse_args()
    configure_database(args)
    raise SystemExit(asyncio.run(migrate(args)))


if __name__ == "__main__":
    main()
