"""agent_proposals — persisted AI mutation plans awaiting user confirmation."""

from __future__ import annotations

import uuid
from datetime import datetime
from enum import StrEnum

from sqlalchemy import DateTime, ForeignKey, String, Text, UniqueConstraint, text
from sqlalchemy import Enum as SAEnum
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.dialects.postgresql import UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, enum_check


class AgentProposalStatus(StrEnum):
    pending_confirmation = "pending_confirmation"
    confirmed = "confirmed"
    executing = "executing"
    executed = "executed"
    rejected = "rejected"
    expired = "expired"
    failed = "failed"


_STATUS = SAEnum(
    AgentProposalStatus,
    name="agent_proposal_status",
    native_enum=False,
    create_constraint=False,
    length=32,
    values_callable=lambda enum_cls: [member.value for member in enum_cls],
    validate_strings=True,
)


class AgentProposal(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "agent_proposals"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "idempotency_key",
            name="uq_agent_proposals_user_idempotency",
        ),
        enum_check("status", AgentProposalStatus, "agent_proposal_status"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    conversation_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    status: Mapped[AgentProposalStatus] = mapped_column(
        _STATUS,
        nullable=False,
        server_default=text("'pending_confirmation'"),
    )
    intent: Mapped[str] = mapped_column(
        String(64), nullable=False, server_default=text("''")
    )
    steps: Mapped[list] = mapped_column(
        JSONB, nullable=False, server_default=text("'[]'::jsonb")
    )
    summary: Mapped[str] = mapped_column(Text, nullable=False, server_default=text("''"))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    confirmed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    executed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    idempotency_key: Mapped[str | None] = mapped_column(String(128), nullable=True)
    error_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    result: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    model: Mapped[str | None] = mapped_column(String(64), nullable=True)
    trace: Mapped[dict | None] = mapped_column(JSONB, nullable=True)


class AgentTrace(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """Observability row for one /agent/chat turn."""

    __tablename__ = "agent_traces"

    user_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    request_id: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    conversation_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    question: Mapped[str] = mapped_column(Text, nullable=False)
    answer: Mapped[str | None] = mapped_column(Text, nullable=True)
    model: Mapped[str | None] = mapped_column(String(64), nullable=True)
    tool_calls: Mapped[list | None] = mapped_column(JSONB, nullable=True)
    proposal_id: Mapped[uuid.UUID | None] = mapped_column(
        PgUUID(as_uuid=True), nullable=True
    )
    latency_ms: Mapped[int | None] = mapped_column(nullable=True)
    error: Mapped[str | None] = mapped_column(Text, nullable=True)
