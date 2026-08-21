"""FCM on new Postgres transactions. Replaces `onUserTransactionCreatedNotify`.

Uses the `devices` table (Phase B), not the Firestore `fcmTokens` array.
Dead tokens are pruned so the next send does not keep failing.
"""

from __future__ import annotations

import logging
import uuid
from decimal import Decimal

from firebase_admin import messaging
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.concurrency import run_in_threadpool

from app.core import firebase
from app.db.models.device import Device
from app.db.models.transaction import Transaction

logger = logging.getLogger(__name__)


async def notify_new_transaction(
    session: AsyncSession, *, user_id: uuid.UUID, tx: Transaction
) -> None:
    if tx.status.value == "deleted":
        return
    result = await session.execute(select(Device).where(Device.user_id == user_id))
    devices = list(result.scalars().all())
    tokens = [d.fcm_token for d in devices]
    if not tokens:
        return

    amount = Decimal(tx.amount)
    sign = "+" if tx.type.value == "credit" else "-"
    title = tx.merchant or "New transaction"
    body = f"{sign}{tx.currency} {amount:.2f} · {tx.category}"

    try:
        response = await run_in_threadpool(_send, tokens, title, body, str(tx.id))
    except Exception:
        logger.exception("fcm_send_failed", extra={"transactionId": str(tx.id)})
        return

    dead = [
        tokens[i]
        for i, result in enumerate(response.responses)
        if not result.success and _is_dead_token(result)
    ]
    if not dead:
        return
    for device in devices:
        if device.fcm_token in dead:
            await session.delete(device)
    await session.commit()
    logger.info("fcm_tokens_pruned", extra={"count": len(dead)})


def _send(
    tokens: list[str], title: str, body: str, transaction_id: str
) -> messaging.BatchResponse:
    app = firebase.require_app()
    return messaging.send_each_for_multicast(
        messaging.MulticastMessage(
            tokens=tokens,
            notification=messaging.Notification(title=title, body=body),
            data={"transactionId": transaction_id, "type": "transaction_created"},
        ),
        app=app,
    )


def _is_dead_token(result: messaging.SendResponse) -> bool:
    exc = result.exception
    if exc is None:
        return False
    code = getattr(exc, "code", "") or str(exc)
    return any(
        marker in str(code)
        for marker in (
            "registration-token-not-registered",
            "invalid-registration-token",
            "UNREGISTERED",
            "INVALID_ARGUMENT",
        )
    )
