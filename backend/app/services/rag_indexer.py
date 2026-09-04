"""Upsert and rebuild derived RAG documents. Never reads SMS payloads."""

from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass
from datetime import date

from sqlalchemy import delete, func, select, text
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.enums import RagDocType, TransactionStatus, TransactionType
from app.db.models.rag_document import RagDocument
from app.db.models.transaction import Transaction
from app.db.models.user import User
from app.services import analytics as analytics_service
from app.services.embeddings import embed_texts
from app.services.money import as_money
from app.services.rag_documents import (
    MerchantStats,
    build_merchant_doc,
    build_period_doc,
    build_transaction_doc,
    doc_fingerprint,
    merchant_fingerprint,
    period_fingerprint,
    should_index_transaction,
)

logger = logging.getLogger(__name__)
_REINDEX_COMMIT_EVERY = 15


@dataclass
class ReindexStats:
    users: int = 0
    transactions: int = 0
    merchants: int = 0
    periods: int = 0
    skipped: int = 0
    deleted: int = 0


async def _get_existing(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    doc_type: RagDocType,
    ref_id: str,
) -> RagDocument | None:
    return (
        await session.execute(
            select(RagDocument).where(
                RagDocument.user_id == user_id,
                RagDocument.doc_type == doc_type.value,
                RagDocument.ref_id == ref_id,
            )
        )
    ).scalar_one_or_none()


async def _upsert_row(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    doc_type: RagDocType,
    ref_id: str,
    content_text: str,
    fingerprint: str,
    embedding: list[float],
    period_from: date | None,
    period_to: date | None,
) -> bool:
    row = await _get_existing(
        session, user_id=user_id, doc_type=doc_type, ref_id=ref_id
    )
    if row is not None and row.fingerprint == fingerprint:
        return False
    if row is not None:
        row.content_text = content_text
        row.fingerprint = fingerprint
        row.embedding = embedding
        row.period_from = period_from
        row.period_to = period_to
        await session.flush()
        return True
    stmt = pg_insert(RagDocument).values(
        user_id=user_id,
        doc_type=doc_type.value,
        ref_id=ref_id,
        content_text=content_text,
        fingerprint=fingerprint,
        embedding=embedding,
        period_from=period_from,
        period_to=period_to,
    ).on_conflict_do_update(
        constraint="uq_rag_documents_user_type_ref",
        set_={
            "content_text": content_text,
            "fingerprint": fingerprint,
            "embedding": embedding,
            "period_from": period_from,
            "period_to": period_to,
        },
    )
    await session.execute(stmt)
    return True


async def upsert_transaction_doc(
    session: AsyncSession, *, user: User, tx: Transaction
) -> bool:
    if not should_index_transaction(tx):
        await delete_transaction_doc(session, user_id=user.id, tx_id=tx.id)
        return False
    fingerprint = doc_fingerprint(tx)
    existing = await _get_existing(
        session,
        user_id=user.id,
        doc_type=RagDocType.transaction,
        ref_id=str(tx.id),
    )
    if existing is not None and existing.fingerprint == fingerprint:
        return False
    content = build_transaction_doc(tx)
    embedding = (await embed_texts([content]))[0]
    return await _upsert_row(
        session,
        user_id=user.id,
        doc_type=RagDocType.transaction,
        ref_id=str(tx.id),
        content_text=content,
        fingerprint=fingerprint,
        embedding=embedding,
        period_from=tx.transaction_date,
        period_to=tx.transaction_date,
    )


async def delete_transaction_doc(
    session: AsyncSession, *, user_id: uuid.UUID, tx_id: uuid.UUID
) -> int:
    result = await session.execute(
        delete(RagDocument).where(
            RagDocument.user_id == user_id,
            RagDocument.doc_type == RagDocType.transaction.value,
            RagDocument.ref_id == str(tx_id),
        )
    )
    await session.flush()
    return int(result.rowcount or 0)


async def rebuild_merchant_doc(
    session: AsyncSession, *, user: User, merchant_normalized: str
) -> bool:
    key = (merchant_normalized or "").strip()
    if not key:
        return False
    row = (
        await session.execute(
            select(
                func.max(Transaction.merchant),
                func.count(Transaction.id),
                func.coalesce(func.sum(Transaction.amount), 0),
                func.max(Transaction.transaction_date),
            ).where(
                Transaction.user_id == user.id,
                Transaction.merchant_normalized == key,
                Transaction.status != TransactionStatus.deleted,
                Transaction.type == TransactionType.debit,
            )
        )
    ).one()
    merchant, visits, total_raw, last_date = row
    if not visits or last_date is None:
        result = await session.execute(
            delete(RagDocument).where(
                RagDocument.user_id == user.id,
                RagDocument.doc_type == RagDocType.merchant.value,
                RagDocument.ref_id == key,
            )
        )
        await session.flush()
        return bool(result.rowcount)
    total = as_money(total_raw)
    average = as_money(total / visits)
    stats = MerchantStats(
        merchant=merchant or key,
        merchant_normalized=key,
        visit_count=int(visits),
        total=total,
        average=average,
        last_date=last_date,
        currency=user.default_currency,
    )
    content = build_merchant_doc(stats)
    fingerprint = merchant_fingerprint(stats)
    existing = await _get_existing(
        session, user_id=user.id, doc_type=RagDocType.merchant, ref_id=key
    )
    if existing is not None and existing.fingerprint == fingerprint:
        return False
    embedding = (await embed_texts([content]))[0]
    return await _upsert_row(
        session,
        user_id=user.id,
        doc_type=RagDocType.merchant,
        ref_id=key,
        content_text=content,
        fingerprint=fingerprint,
        embedding=embedding,
        period_from=None,
        period_to=None,
    )


async def rebuild_period_doc(
    session: AsyncSession, *, user: User, year_month: str
) -> bool:
    parsed = analytics_service.parse_year_month(year_month)
    summary = await analytics_service.get_summary(session, user=user, year_month=parsed)
    if int(summary.get("transaction_count") or 0) == 0:
        result = await session.execute(
            delete(RagDocument).where(
                RagDocument.user_id == user.id,
                RagDocument.doc_type == RagDocType.period.value,
                RagDocument.ref_id == parsed,
            )
        )
        await session.flush()
        return bool(result.rowcount)
    content = build_period_doc(summary)
    fingerprint = period_fingerprint(summary)
    existing = await _get_existing(
        session, user_id=user.id, doc_type=RagDocType.period, ref_id=parsed
    )
    if existing is not None and existing.fingerprint == fingerprint:
        return False
    start = date.fromisoformat(summary["date_from"])
    end = date.fromisoformat(summary["date_to"])
    embedding = (await embed_texts([content]))[0]
    return await _upsert_row(
        session,
        user_id=user.id,
        doc_type=RagDocType.period,
        ref_id=parsed,
        content_text=content,
        fingerprint=fingerprint,
        embedding=embedding,
        period_from=start,
        period_to=end,
    )


async def reindex_user(
    session: AsyncSession, *, user_id: uuid.UUID, full: bool = True
) -> ReindexStats:
    stats = ReindexStats(users=1)
    user = await session.get(User, user_id)
    if user is None:
        return ReindexStats()
    txs = list(
        (
            await session.execute(
                select(Transaction).where(Transaction.user_id == user_id)
            )
        ).scalars()
    )
    merchants: set[str] = set()
    months: set[str] = set()
    pending = 0
    for tx in txs:
        months.add(f"{tx.transaction_date.year:04d}-{tx.transaction_date.month:02d}")
        if tx.merchant_normalized:
            merchants.add(tx.merchant_normalized)
        if not should_index_transaction(tx):
            removed = await delete_transaction_doc(
                session, user_id=user_id, tx_id=tx.id
            )
            stats.deleted += removed
            continue
        changed = await upsert_transaction_doc(session, user=user, tx=tx)
        if changed:
            stats.transactions += 1
            pending += 1
            if pending >= _REINDEX_COMMIT_EVERY:
                await session.commit()
                session.expire_all()
                pending = 0
        else:
            stats.skipped += 1
    if full:
        for key in merchants:
            if await rebuild_merchant_doc(session, user=user, merchant_normalized=key):
                stats.merchants += 1
        for year_month in months:
            if await rebuild_period_doc(session, user=user, year_month=year_month):
                stats.periods += 1
    await session.commit()
    return stats


async def reindex_users(
    session: AsyncSession,
    *,
    user_id: uuid.UUID | None = None,
    full: bool = False,
) -> ReindexStats:
    totals = ReindexStats()
    await session.execute(text("SET statement_timeout = '60s'"))
    if user_id is not None:
        stats = await reindex_user(session, user_id=user_id, full=full)
        return stats
    user_ids = list(
        (await session.execute(select(User.id).order_by(User.created_at))).scalars()
    )
    for uid in user_ids:
        try:
            stats = await reindex_user(session, user_id=uid, full=full)
        except Exception:
            logger.exception("reindex_user failed", extra={"user_id": str(uid)})
            await session.rollback()
            await session.execute(text("SET statement_timeout = '60s'"))
            continue
        totals.users += stats.users
        totals.transactions += stats.transactions
        totals.merchants += stats.merchants
        totals.periods += stats.periods
        totals.skipped += stats.skipped
        totals.deleted += stats.deleted
    return totals


async def index_after_commit(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    transaction_id: uuid.UUID,
    deleted: bool = False,
) -> None:
    """Best-effort index update. Never raises to the caller.

    Opens a separate session so a vector write failure cannot expire the
    caller's already-committed transaction.
    """
    del session
    try:
        from app.db.session import get_sessionmaker

        async with get_sessionmaker()() as index_session:
            user = await index_session.get(User, user_id)
            tx = await index_session.get(Transaction, transaction_id)
            if user is None or tx is None:
                return
            if deleted:
                await delete_transaction_doc(
                    index_session, user_id=user_id, tx_id=transaction_id
                )
            else:
                await upsert_transaction_doc(index_session, user=user, tx=tx)
            if tx.merchant_normalized:
                await rebuild_merchant_doc(
                    index_session,
                    user=user,
                    merchant_normalized=tx.merchant_normalized,
                )
            year_month = (
                f"{tx.transaction_date.year:04d}-{tx.transaction_date.month:02d}"
            )
            await rebuild_period_doc(index_session, user=user, year_month=year_month)
            await index_session.commit()
    except Exception:
        logger.exception(
            "rag index failed",
            extra={"user_id": str(user_id), "transaction_id": str(transaction_id)},
        )
