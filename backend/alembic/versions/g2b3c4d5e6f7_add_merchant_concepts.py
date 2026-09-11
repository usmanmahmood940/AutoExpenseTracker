"""add merchant_concepts and merchant_concept_overrides

Revision ID: g2b3c4d5e6f7
Revises: f1a2b3c4d5e6
Create Date: 2026-09-11 16:20:00.000000

"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "g2b3c4d5e6f7"
down_revision: str | None = "f1a2b3c4d5e6"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "merchant_concepts",
        sa.Column("merchant_normalized", sa.String(length=200), nullable=False),
        sa.Column(
            "concepts",
            postgresql.ARRAY(sa.String(length=64)),
            server_default=sa.text("'{}'::text[]"),
            nullable=False,
        ),
        sa.Column(
            "model",
            sa.String(length=64),
            server_default=sa.text("'seed'"),
            nullable=False,
        ),
        sa.Column(
            "resolved_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint(
            "merchant_normalized", name=op.f("pk_merchant_concepts")
        ),
    )
    op.create_index(
        "merchant_concepts_gin_idx",
        "merchant_concepts",
        ["concepts"],
        unique=False,
        postgresql_using="gin",
    )

    op.create_table(
        "merchant_concept_overrides",
        sa.Column(
            "id",
            sa.UUID(),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("merchant_normalized", sa.String(length=200), nullable=False),
        sa.Column(
            "concepts",
            postgresql.ARRAY(sa.String(length=64)),
            server_default=sa.text("'{}'::text[]"),
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
            name=op.f("fk_merchant_concept_overrides_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_merchant_concept_overrides")),
        sa.UniqueConstraint(
            "user_id",
            "merchant_normalized",
            name="uq_merchant_concept_overrides_user_merchant",
        ),
    )
    op.create_index(
        op.f("ix_merchant_concept_overrides_user_id"),
        "merchant_concept_overrides",
        ["user_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_merchant_concept_overrides_user_id"),
        table_name="merchant_concept_overrides",
    )
    op.drop_table("merchant_concept_overrides")
    op.drop_index("merchant_concepts_gin_idx", table_name="merchant_concepts")
    op.drop_table("merchant_concepts")
