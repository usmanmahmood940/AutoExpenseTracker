"""add ai_summaries for cached insights narratives

Revision ID: c3e8a1b0d4f2
Revises: b094a470512d
Create Date: 2026-08-27 18:10:00.000000

"""

from __future__ import annotations

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "c3e8a1b0d4f2"
down_revision: str | None = "b094a470512d"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "ai_summaries",
        sa.Column(
            "id",
            sa.UUID(),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("date_from", sa.Date(), nullable=False),
        sa.Column("date_to", sa.Date(), nullable=False),
        sa.Column("narrative", sa.Text(), nullable=False),
        sa.Column("model", sa.String(length=80), nullable=False),
        sa.Column(
            "generated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_ai_summaries_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_ai_summaries")),
        sa.UniqueConstraint(
            "user_id",
            "date_from",
            "date_to",
            name="uq_ai_summaries_user_range",
        ),
    )
    op.create_index(
        op.f("ix_ai_summaries_user_id"), "ai_summaries", ["user_id"], unique=False
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_ai_summaries_user_id"), table_name="ai_summaries")
    op.drop_table("ai_summaries")
