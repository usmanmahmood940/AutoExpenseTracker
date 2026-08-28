"""add ai_summaries fingerprint columns for cache invalidation

Revision ID: d4f5a6b7c8e9
Revises: c3e8a1b0d4f2
Create Date: 2026-08-28 11:30:00.000000

"""

from __future__ import annotations

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "d4f5a6b7c8e9"
down_revision: str | None = "c3e8a1b0d4f2"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "ai_summaries",
        sa.Column(
            "transaction_count",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )
    op.add_column(
        "ai_summaries",
        sa.Column("source_updated_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.alter_column("ai_summaries", "transaction_count", server_default=None)


def downgrade() -> None:
    op.drop_column("ai_summaries", "source_updated_at")
    op.drop_column("ai_summaries", "transaction_count")
