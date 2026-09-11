"""Agent chat + proposal confirm/reject."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter
from pydantic import BaseModel, ConfigDict, Field

from app.api.deps import AppSettings, CurrentUser, DbSession
from app.core.errors import BadRequestError, NotFoundError
from app.core.logging import request_id_var
from app.db.models.agent_proposal import AgentProposal, AgentProposalStatus
from app.services.agent.executor import execute_proposal
from app.services.agent.orchestrator import run_agent
from app.services.agent.write_tools import proposal_to_dict

router = APIRouter(prefix="/agent", tags=["agent"])


class ChatHistoryTurn(BaseModel):
    question: str = Field(min_length=1, max_length=500)
    answer: str = Field(min_length=1, max_length=500)


class AgentChatRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    question: str = Field(min_length=1, max_length=2000)
    date_from: str | None = Field(default=None, alias="from")
    date_to: str | None = Field(default=None, alias="to")
    history: list[ChatHistoryTurn] = Field(default_factory=list, max_length=3)
    conversation_id: str | None = Field(default=None, max_length=64)


class AgentProposalOut(BaseModel):
    proposal_id: str
    status: str
    intent: str
    steps: list[dict]
    summary: str
    expires_at: str | None = None
    model: str | None = None


class AgentChatOut(BaseModel):
    answer: str
    citations: list[dict] = Field(default_factory=list)
    confidence: str
    source: str
    model: str | None = None
    filter_term: str | None = None
    window_from: str | None = None
    window_to: str | None = None
    proposal: AgentProposalOut | None = None
    tool_calls: list[dict] = Field(default_factory=list)


class ConfirmRequest(BaseModel):
    idempotency_key: str = Field(min_length=8, max_length=128)


class ConfirmOut(BaseModel):
    proposal_id: str
    status: str
    result: dict | None = None
    error_code: str | None = None
    error_message: str | None = None


@router.post("/chat", response_model=AgentChatOut)
async def agent_chat(
    user: CurrentUser,
    session: DbSession,
    settings: AppSettings,
    body: AgentChatRequest,
) -> AgentChatOut:
    payload = await run_agent(
        session,
        user=user,
        settings=settings,
        question=body.question,
        date_from=body.date_from,
        date_to=body.date_to,
        history=[turn.model_dump() for turn in body.history],
        conversation_id=body.conversation_id,
        request_id=request_id_var.get(),
    )
    return AgentChatOut.model_validate(payload)


@router.get("/proposals/{proposal_id}", response_model=AgentProposalOut)
async def get_proposal(
    user: CurrentUser,
    session: DbSession,
    proposal_id: uuid.UUID,
) -> AgentProposalOut:
    proposal = await _owned_proposal(session, user_id=user.id, proposal_id=proposal_id)
    return AgentProposalOut.model_validate(proposal_to_dict(proposal))


@router.post("/proposals/{proposal_id}/confirm", response_model=ConfirmOut)
async def confirm_proposal(
    user: CurrentUser,
    session: DbSession,
    proposal_id: uuid.UUID,
    body: ConfirmRequest,
) -> ConfirmOut:
    proposal = await _owned_proposal(session, user_id=user.id, proposal_id=proposal_id)

    # Idempotent replay
    if (
        proposal.idempotency_key
        and proposal.idempotency_key == body.idempotency_key
        and proposal.status is AgentProposalStatus.executed
    ):
        return ConfirmOut(
            proposal_id=str(proposal.id),
            status=proposal.status.value,
            result=proposal.result,
        )

    if proposal.idempotency_key and proposal.idempotency_key != body.idempotency_key:
        if proposal.status is AgentProposalStatus.executed:
            return ConfirmOut(
                proposal_id=str(proposal.id),
                status=proposal.status.value,
                result=proposal.result,
            )

    if proposal.status is AgentProposalStatus.executed:
        return ConfirmOut(
            proposal_id=str(proposal.id),
            status=proposal.status.value,
            result=proposal.result,
        )

    if proposal.expires_at and proposal.expires_at < datetime.now(UTC):
        proposal.status = AgentProposalStatus.expired
        await session.commit()
        raise BadRequestError("Proposal expired.", code="proposal_expired")

    if proposal.status not in (
        AgentProposalStatus.pending_confirmation,
        AgentProposalStatus.failed,
    ):
        raise BadRequestError(
            f"Proposal cannot be confirmed from {proposal.status.value}.",
            code="proposal_invalid_status",
        )

    proposal.idempotency_key = body.idempotency_key
    proposal.status = AgentProposalStatus.confirmed
    proposal.confirmed_at = datetime.now(UTC)
    await session.flush()

    executed = await execute_proposal(
        session,
        user_id=user.id,
        proposal=proposal,
        default_currency=user.default_currency,
    )
    return ConfirmOut(
        proposal_id=str(executed.id),
        status=executed.status.value,
        result=executed.result,
        error_code=executed.error_code,
        error_message=executed.error_message,
    )


@router.post("/proposals/{proposal_id}/reject", response_model=ConfirmOut)
async def reject_proposal(
    user: CurrentUser,
    session: DbSession,
    proposal_id: uuid.UUID,
) -> ConfirmOut:
    proposal = await _owned_proposal(session, user_id=user.id, proposal_id=proposal_id)
    if proposal.status is AgentProposalStatus.executed:
        raise BadRequestError(
            "Executed proposals cannot be rejected.",
            code="proposal_already_executed",
        )
    proposal.status = AgentProposalStatus.rejected
    await session.commit()
    return ConfirmOut(proposal_id=str(proposal.id), status=proposal.status.value)


async def _owned_proposal(
    session: DbSession,
    *,
    user_id: uuid.UUID,
    proposal_id: uuid.UUID,
) -> AgentProposal:
    proposal = await session.get(AgentProposal, proposal_id)
    if proposal is None or proposal.user_id != user_id:
        raise NotFoundError("Proposal not found.", code="proposal_not_found")
    return proposal
