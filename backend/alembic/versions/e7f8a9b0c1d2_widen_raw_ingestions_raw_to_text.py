"""widen raw_ingestions.raw to Text for ciphertext

Revision ID: e7f8a9b0c1d2
Revises: d4f5a6b7c8e9
Create Date: 2026-09-04 12:22:00.000000

"""

from __future__ import annotations

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "e7f8a9b0c1d2"
down_revision: str | None = "d4f5a6b7c8e9"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.alter_column(
        "raw_ingestions",
        "raw",
        existing_type=sa.String(length=8000),
        type_=sa.Text(),
        existing_nullable=False,
    )


def downgrade() -> None:
    op.alter_column(
        "raw_ingestions",
        "raw",
        existing_type=sa.Text(),
        type_=sa.String(length=8000),
        existing_nullable=False,
    )
