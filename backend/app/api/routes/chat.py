"""Chat suggestions and ask. Grounded in the caller's transactions only."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Query
from pydantic import BaseModel, ConfigDict, Field

from app.api.deps import AppSettings, CurrentUser, DbSession
from app.api.product_schemas import ChatAskOut, ChatSuggestionsOut
from app.services import chat_rag

router = APIRouter(prefix="/chat", tags=["chat"])


class ChatAskRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    question: str = Field(min_length=1, max_length=2000)
    date_from: str | None = Field(default=None, alias="from")
    date_to: str | None = Field(default=None, alias="to")


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
    payload = await chat_rag.ask(
        session,
        user=user,
        settings=settings,
        question=body.question,
        date_from=body.date_from,
        date_to=body.date_to,
    )
    return ChatAskOut.model_validate(payload)
