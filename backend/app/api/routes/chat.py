"""Chat suggestions and ask.

Ask delegates to the agent orchestrator when `chat_use_agent` is enabled
(default). Suggestions remain signal-based SQL.
"""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Query
from pydantic import BaseModel, ConfigDict, Field

from app.api.deps import AppSettings, CurrentUser, DbSession
from app.api.product_schemas import ChatAskOut, ChatSuggestionsOut
from app.core.logging import request_id_var
from app.services import chat_rag
from app.services.agent.orchestrator import run_agent

router = APIRouter(prefix="/chat", tags=["chat"])


class ChatHistoryTurn(BaseModel):
    question: str = Field(min_length=1, max_length=500)
    answer: str = Field(min_length=1, max_length=500)


class ChatAskRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    question: str = Field(min_length=1, max_length=2000)
    date_from: str | None = Field(default=None, alias="from")
    date_to: str | None = Field(default=None, alias="to")
    history: list[ChatHistoryTurn] = Field(default_factory=list, max_length=3)


@router.get("/suggestions", response_model=ChatSuggestionsOut)
async def get_suggestions(
    user: CurrentUser,
    session: DbSession,
    date_from: Annotated[str, Query(alias="from")],
    date_to: Annotated[str, Query(alias="to")],
) -> ChatSuggestionsOut:
    payload = await chat_rag.get_suggestions(
        session, user=user, date_from=date_from, date_to=date_to
    )
    return ChatSuggestionsOut.model_validate(payload)


@router.post("/ask", response_model=ChatAskOut)
async def ask(
    user: CurrentUser,
    session: DbSession,
    settings: AppSettings,
    body: ChatAskRequest,
) -> ChatAskOut:
    if settings.chat_use_agent:
        payload = await run_agent(
            session,
            user=user,
            settings=settings,
            question=body.question,
            date_from=body.date_from,
            date_to=body.date_to,
            history=[turn.model_dump() for turn in body.history],
            request_id=request_id_var.get(),
        )
        return ChatAskOut.model_validate(
            {
                "answer": payload["answer"],
                "citations": payload.get("citations") or [],
                "confidence": payload.get("confidence") or "medium",
                "source": payload.get("source") or "agent",
                "model": payload.get("model"),
                "filter_term": payload.get("filter_term"),
                "window_from": payload.get("window_from"),
                "window_to": payload.get("window_to"),
                "proposal": payload.get("proposal"),
            }
        )

    payload = await chat_rag.ask(
        session,
        user=user,
        settings=settings,
        question=body.question,
        date_from=body.date_from,
        date_to=body.date_to,
        history=[turn.model_dump() for turn in body.history],
    )
    return ChatAskOut.model_validate(payload)
