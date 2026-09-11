"""Execute confirmed proposals via existing transaction domain services."""

from __future__ import annotations

import logging
import uuid
from datetime import UTC, date, datetime
from decimal import Decimal
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError, BadRequestError, ConflictError
from app.db.models.agent_proposal import AgentProposal, AgentProposalStatus
from app.db.models.enums import TransactionType
from app.db.models.transaction import Transaction
from app.db.seeds.categories import FALLBACK_CATEGORY_NAME
from app.services import transactions as tx_service

logger = logging.getLogger(__name__)


def _parse_updated_at(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=UTC)
        return parsed
    except ValueError:
        return None


async def _check_fresh(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    transaction_id: uuid.UUID,
    expected: str | None,
) -> Transaction:
    tx = await tx_service.get_owned(
        session, user_id=user_id, transaction_id=transaction_id
    )
    expected_dt = _parse_updated_at(expected)
    if expected_dt is not None and tx.updated_at is not None:
        current = tx.updated_at
        if current.tzinfo is None:
            current = current.replace(tzinfo=UTC)
        # Allow 1s skew
        if abs((current - expected_dt).total_seconds()) > 1.0:
            raise ConflictError(
                "Transaction changed since the proposal was created.",
                code="proposal_stale",
            )
    return tx


async def execute_proposal(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    proposal: AgentProposal,
    default_currency: str = "PKR",
) -> AgentProposal:
    if proposal.status is AgentProposalStatus.executed:
        return proposal
    if proposal.status is AgentProposalStatus.rejected:
        raise BadRequestError("Proposal was rejected.", code="proposal_rejected")
    if proposal.expires_at and proposal.expires_at < datetime.now(UTC):
        proposal.status = AgentProposalStatus.expired
        await session.commit()
        raise BadRequestError("Proposal expired.", code="proposal_expired")
    if proposal.status not in (
        AgentProposalStatus.pending_confirmation,
        AgentProposalStatus.confirmed,
        AgentProposalStatus.executing,
    ):
        raise BadRequestError(
            f"Proposal cannot be executed from status {proposal.status.value}.",
            code="proposal_invalid_status",
        )

    proposal.status = AgentProposalStatus.executing
    proposal.confirmed_at = proposal.confirmed_at or datetime.now(UTC)
    await session.flush()

    ref_map: dict[str, uuid.UUID] = {}
    created_ids: list[str] = []
    settle_primary_id: str | None = None

    try:
        for step in proposal.steps or []:
            op = step.get("op")
            if op == "create":
                tx_date = date.fromisoformat(str(step["date"])[:10])
                tx_type = TransactionType(str(step.get("type") or "debit").lower())
                currency = (
                    str(step.get("currency") or default_currency).upper() or default_currency
                )
                # create_transaction commits; we need atomicity — use internal
                # path that doesn't commit, then commit once at the end.
                tx = await _create_without_commit(
                    session,
                    user_id=user_id,
                    amount=Decimal(str(step["amount"])),
                    merchant=str(step["merchant"]),
                    transaction_date=tx_date,
                    tx_type=tx_type,
                    category=str(step.get("category") or FALLBACK_CATEGORY_NAME),
                    currency=currency,
                    note=step.get("note"),
                )
                ref = str(step.get("ref") or "")
                if ref:
                    ref_map[ref] = tx.id
                created_ids.append(str(tx.id))
            elif op == "settle":
                primary_id = _resolve_id(
                    step.get("primary_transaction_id") or step.get("primary_ref"),
                    ref_map,
                )
                source_raw = list(
                    step.get("source_transaction_ids") or step.get("source_refs") or []
                )
                source_ids = [_resolve_id(item, ref_map) for item in source_raw]
                if step.get("primary_updated_at") and not str(
                    step.get("primary_ref") or ""
                ).startswith("t"):
                    await _check_fresh(
                        session,
                        user_id=user_id,
                        transaction_id=primary_id,
                        expected=step.get("primary_updated_at"),
                    )
                sources_updated = step.get("sources_updated_at") or {}
                for sid in source_ids:
                    expected = sources_updated.get(str(sid))
                    if expected:
                        await _check_fresh(
                            session,
                            user_id=user_id,
                            transaction_id=sid,
                            expected=expected,
                        )
                primary = await _settle_without_commit(
                    session,
                    user_id=user_id,
                    primary_id=primary_id,
                    source_ids=source_ids,
                )
                settle_primary_id = str(primary.id)
            elif op == "unsettle":
                primary_id = uuid.UUID(str(step["primary_transaction_id"]))
                await _check_fresh(
                    session,
                    user_id=user_id,
                    transaction_id=primary_id,
                    expected=step.get("primary_updated_at"),
                )
                await _unsettle_without_commit(
                    session,
                    user_id=user_id,
                    primary_id=primary_id,
                    group_id=str(step["group_id"]),
                )
            elif op == "unmerge":
                tid = uuid.UUID(str(step["transaction_id"]))
                await _check_fresh(
                    session,
                    user_id=user_id,
                    transaction_id=tid,
                    expected=step.get("updated_at"),
                )
                await _unmerge_without_commit(
                    session, user_id=user_id, transaction_id=tid
                )
            else:
                raise BadRequestError(
                    f"Unknown proposal step op: {op}",
                    code="proposal_unknown_op",
                )

        proposal.status = AgentProposalStatus.executed
        proposal.executed_at = datetime.now(UTC)
        proposal.result = {
            "created_transaction_ids": created_ids,
            "settle_primary_id": settle_primary_id,
            "ref_map": {k: str(v) for k, v in ref_map.items()},
        }
        await session.commit()
        # Index / enrich after successful commit
        for tid in created_ids:
            await tx_service._index_after_commit(
                session, user_id=user_id, transaction_id=uuid.UUID(tid)
            )
        if settle_primary_id:
            await tx_service._index_after_commit(
                session,
                user_id=user_id,
                transaction_id=uuid.UUID(settle_primary_id),
            )
        await session.refresh(proposal)
        return proposal
    except AppError as exc:
        await session.rollback()
        # Reload proposal after rollback
        proposal = await session.get(AgentProposal, proposal.id)  # type: ignore[assignment]
        if proposal is not None:
            proposal.status = AgentProposalStatus.failed
            proposal.error_code = getattr(exc, "code", None) or "proposal_failed"
            proposal.error_message = str(exc)
            await session.commit()
        raise
    except Exception as exc:
        await session.rollback()
        proposal = await session.get(AgentProposal, proposal.id)  # type: ignore[assignment]
        if proposal is not None:
            proposal.status = AgentProposalStatus.failed
            proposal.error_code = "proposal_failed"
            proposal.error_message = str(exc)[:500]
            await session.commit()
        logger.exception("proposal execution failed")
        raise BadRequestError("Proposal execution failed.", code="proposal_failed") from exc


def _resolve_id(raw: Any, ref_map: dict[str, uuid.UUID]) -> uuid.UUID:
    text = str(raw or "").strip()
    if not text:
        raise BadRequestError("Missing transaction reference.", code="proposal_bad_ref")
    if text in ref_map:
        return ref_map[text]
    try:
        return uuid.UUID(text)
    except ValueError as exc:
        raise BadRequestError(
            f"Unknown ref {text}.", code="proposal_bad_ref"
        ) from exc


async def _create_without_commit(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    amount: Decimal,
    merchant: str,
    transaction_date: date,
    tx_type: TransactionType,
    category: str,
    currency: str,
    note: str | None,
) -> Transaction:
    from app.db.models.enums import ExternalIdType, TransactionStatus
    from app.services.merchant_key import normalize_merchant_key, resolve_merchant
    from app.services.money import as_money
    from app.services.sms_source import build_sms_source
    from app.services.transactions import weekday_name

    merchant = resolve_merchant(merchant.strip(), category=category)
    tx_id = uuid.uuid4()
    tx = Transaction(
        id=tx_id,
        user_id=user_id,
        amount=as_money(amount),
        currency=currency.upper(),
        type=tx_type,
        merchant=merchant,
        merchant_normalized=normalize_merchant_key(merchant),
        category=category.strip() or FALLBACK_CATEGORY_NAME,
        category_source="agent",
        payment_method="unknown",
        bank="",
        account_id="",
        account_id_masked="",
        transaction_time="",
        transaction_date=transaction_date,
        day=weekday_name(transaction_date),
        external_id_type=ExternalIdType.unknown,
        dedup_key=f"agent_{tx_id}",
        sms_source=build_sms_source(
            raw_plaintext=note.strip() if note and note.strip() else "",
            source="manual",
            user_id=user_id,
        ),
        parse_confidence=Decimal("1"),
        is_auto_detected=False,
        is_edited=True,
        status=TransactionStatus.active,
        reviewed_at=datetime.now(UTC),
    )
    session.add(tx)
    await session.flush()
    return tx


async def _settle_without_commit(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    primary_id: uuid.UUID,
    source_ids: list[uuid.UUID],
) -> Transaction:
    """Inlined settle logic without commit — mirrors transactions.settle."""
    from app.db.models.enums import TransactionStatus, TransactionType
    from app.services.money import as_money, money_float
    from app.services.transactions import (
        _groups_list,
        _source_contribution,
        get_owned,
    )
    from sqlalchemy import select

    if not source_ids:
        raise BadRequestError(
            "Select at least one transaction to settle.",
            code="settle_sources_required",
        )
    unique_sources = list(dict.fromkeys(source_ids))
    if primary_id in unique_sources:
        raise BadRequestError(
            "Primary transaction cannot be settled into itself.",
            code="settle_primary_in_sources",
        )
    primary = await get_owned(session, user_id=user_id, transaction_id=primary_id)
    if primary.status not in (TransactionStatus.active, TransactionStatus.settled):
        raise BadRequestError(
            "Primary must be an active or settled transaction.",
            code="settle_primary_invalid",
        )
    result = await session.execute(
        select(Transaction).where(
            Transaction.user_id == user_id,
            Transaction.id.in_(unique_sources),
        )
    )
    sources = list(result.scalars().all())
    if len(sources) != len(unique_sources):
        raise BadRequestError(
            "One or more source transactions were not found.",
            code="settle_source_not_found",
        )
    for source in sources:
        if source.status is not TransactionStatus.active:
            raise BadRequestError(
                "Only active transactions can be settled into a primary.",
                code="settle_source_invalid",
            )
        if source.currency.upper() != primary.currency.upper():
            raise BadRequestError(
                "All transactions in a settle must share the same currency.",
                code="settle_currency_mismatch",
            )
    amount_applied = sum(
        (_source_contribution(source) for source in sources),
        Decimal("0"),
    )
    new_amount = as_money(primary.amount) - as_money(amount_applied)
    if new_amount <= 0:
        raise BadRequestError(
            "Settle would reduce the primary amount to zero or below.",
            code="settle_amount_invalid",
        )
    if primary.original_amount is None:
        primary.original_amount = as_money(primary.amount)
    group_id = str(uuid.uuid4())
    group = {
        "groupId": group_id,
        "mergedTransactionIds": [str(source.id) for source in sources],
        "createdAt": datetime.now(UTC).isoformat(),
        "amountApplied": money_float(amount_applied),
    }
    groups = _groups_list(primary)
    groups.append(group)
    primary.settlement_groups = groups
    primary.amount = new_amount
    primary.status = TransactionStatus.settled
    primary.is_edited = True
    for source in sources:
        source.status = TransactionStatus.merged
        source.merged_into_id = primary.id
        source.settlement_group_id = group_id
        source.is_edited = True
    await session.flush()
    return primary


async def _unsettle_without_commit(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    primary_id: uuid.UUID,
    group_id: str,
) -> Transaction:
    from app.db.models.enums import TransactionStatus
    from app.services.transactions import (
        _apply_remaining_groups,
        _groups_list,
        get_owned,
    )
    from sqlalchemy import select

    primary = await get_owned(session, user_id=user_id, transaction_id=primary_id)
    if primary.status is not TransactionStatus.settled:
        raise BadRequestError(
            "Only settled transactions can be unsettled.",
            code="unsettle_not_settled",
        )
    groups = _groups_list(primary)
    target = next((g for g in groups if g.get("groupId") == group_id), None)
    if target is None:
        raise BadRequestError("Settlement group not found.", code="settle_group_not_found")
    member_ids = [
        uuid.UUID(str(item)) for item in (target.get("mergedTransactionIds") or [])
    ]
    if member_ids:
        result = await session.execute(
            select(Transaction).where(
                Transaction.user_id == user_id,
                Transaction.id.in_(member_ids),
            )
        )
        for member in result.scalars().all():
            member.status = TransactionStatus.active
            member.merged_into_id = None
            member.settlement_group_id = None
            member.is_edited = True
    remaining = [g for g in groups if g.get("groupId") != group_id]
    _apply_remaining_groups(primary, remaining)
    primary.is_edited = True
    await session.flush()
    return primary


async def _unmerge_without_commit(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    transaction_id: uuid.UUID,
) -> Transaction:
    from app.db.models.enums import TransactionStatus
    from app.services.money import as_money, money_float
    from app.services.transactions import (
        _apply_remaining_groups,
        _groups_list,
        _source_contribution,
        get_owned,
    )

    merged = await get_owned(session, user_id=user_id, transaction_id=transaction_id)
    if merged.status is not TransactionStatus.merged:
        raise BadRequestError(
            "Only merged transactions can be unmerged.",
            code="unmerge_not_merged",
        )
    if merged.merged_into_id is None or not merged.settlement_group_id:
        raise BadRequestError(
            "Merged transaction is missing primary linkage.",
            code="unmerge_missing_link",
        )
    primary = await get_owned(
        session, user_id=user_id, transaction_id=merged.merged_into_id
    )
    groups = _groups_list(primary)
    group_id = merged.settlement_group_id
    target_idx = next(
        (i for i, g in enumerate(groups) if g.get("groupId") == group_id),
        None,
    )
    if target_idx is None:
        raise BadRequestError("Settlement group not found.", code="settle_group_not_found")
    contribution = _source_contribution(merged)
    target = dict(groups[target_idx])
    member_ids = [
        str(item) for item in (target.get("mergedTransactionIds") or []) if str(item)
    ]
    merged_id_str = str(merged.id)
    if merged_id_str not in member_ids:
        raise BadRequestError(
            "Merged transaction is not listed on its settlement group.",
            code="unmerge_not_in_group",
        )
    member_ids = [item for item in member_ids if item != merged_id_str]
    if member_ids:
        target["mergedTransactionIds"] = member_ids
        target["amountApplied"] = money_float(
            as_money(target.get("amountApplied") or 0) - contribution
        )
        groups[target_idx] = target
    else:
        groups.pop(target_idx)
    merged.status = TransactionStatus.active
    merged.merged_into_id = None
    merged.settlement_group_id = None
    merged.is_edited = True
    _apply_remaining_groups(primary, groups)
    primary.is_edited = True
    await session.flush()
    return merged
