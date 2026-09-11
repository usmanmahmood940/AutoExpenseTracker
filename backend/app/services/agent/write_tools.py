"""Proposal builders for write tools — no DB mutation until confirm."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.agent_proposal import AgentProposal, AgentProposalStatus
from app.db.models.user import User

PROPOSAL_TTL_MINUTES = 30


def _step_create(args: dict[str, Any]) -> dict[str, Any]:
    return {
        "op": "create",
        "ref": str(args.get("ref") or "").strip() or "t1",
        "amount": float(args["amount"]),
        "type": str(args.get("type") or "debit").lower(),
        "merchant": str(args.get("merchant") or "").strip(),
        "category": str(args.get("category") or "Uncategorized").strip(),
        "date": str(args.get("date") or "")[:10],
        "currency": str(args.get("currency") or "").upper() or None,
        "note": args.get("note"),
    }


def _step_settle(args: dict[str, Any]) -> dict[str, Any]:
    return {
        "op": "settle",
        "primary_ref": args.get("primary_ref"),
        "source_refs": list(args.get("source_refs") or []),
        "primary_transaction_id": args.get("primary_transaction_id"),
        "source_transaction_ids": list(args.get("source_transaction_ids") or []),
        "primary_updated_at": args.get("primary_updated_at"),
        "sources_updated_at": args.get("sources_updated_at") or {},
    }


def _step_unsettle(args: dict[str, Any]) -> dict[str, Any]:
    return {
        "op": "unsettle",
        "primary_transaction_id": args.get("primary_transaction_id"),
        "group_id": args.get("group_id"),
        "primary_updated_at": args.get("primary_updated_at"),
    }


def _step_unmerge(args: dict[str, Any]) -> dict[str, Any]:
    return {
        "op": "unmerge",
        "transaction_id": args.get("transaction_id"),
        "updated_at": args.get("updated_at"),
    }


WRITE_STEP_BUILDERS = {
    "propose_create_transaction": _step_create,
    "propose_settle": _step_settle,
    "propose_unsettle": _step_unsettle,
    "propose_unmerge": _step_unmerge,
}


def summarize_steps(steps: list[dict[str, Any]]) -> str:
    parts: list[str] = []
    for step in steps:
        op = step.get("op")
        if op == "create":
            parts.append(
                f"Create {step.get('type')} {step.get('amount')} at {step.get('merchant')}"
            )
        elif op == "settle":
            parts.append(
                f"Settle {step.get('source_refs') or step.get('source_transaction_ids')} "
                f"into {step.get('primary_ref') or step.get('primary_transaction_id')}"
            )
        elif op == "unsettle":
            parts.append(f"Unsettle group {step.get('group_id')}")
        elif op == "unmerge":
            parts.append(f"Unmerge {step.get('transaction_id')}")
    return "; ".join(parts)


async def persist_proposal(
    session: AsyncSession,
    *,
    user: User,
    steps: list[dict[str, Any]],
    model: str | None,
    conversation_id: str | None = None,
    intent: str = "",
) -> AgentProposal:
    proposal = AgentProposal(
        user_id=user.id,
        conversation_id=conversation_id,
        status=AgentProposalStatus.pending_confirmation,
        intent=intent or _infer_intent(steps),
        steps=steps,
        summary=summarize_steps(steps),
        expires_at=datetime.now(UTC) + timedelta(minutes=PROPOSAL_TTL_MINUTES),
        model=model,
    )
    session.add(proposal)
    await session.commit()
    await session.refresh(proposal)
    return proposal


def _infer_intent(steps: list[dict[str, Any]]) -> str:
    ops = {step.get("op") for step in steps}
    if "create" in ops and "settle" in ops:
        return "create_and_settle"
    if ops == {"create"}:
        return "create"
    if "settle" in ops:
        return "settle"
    if "unsettle" in ops:
        return "unsettle"
    if "unmerge" in ops:
        return "unmerge"
    return "mixed"


def proposal_to_dict(proposal: AgentProposal) -> dict[str, Any]:
    return {
        "proposal_id": str(proposal.id),
        "status": proposal.status.value,
        "intent": proposal.intent,
        "steps": proposal.steps,
        "summary": proposal.summary,
        "expires_at": proposal.expires_at.isoformat() if proposal.expires_at else None,
        "model": proposal.model,
    }
