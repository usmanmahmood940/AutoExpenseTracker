"""add rag_documents.embedding_model

Tracks which model produced each vector so a stale or hash-fallback embedding
can be detected and reindexed instead of silently degrading retrieval.

Revision ID: a1b2c3d4e5f6
Revises: f8a9b0c1d2e3
Create Date: 2026-09-07 19:20:00.000000

"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "a1b2c3d4e5f6"
down_revision: str | None = "f8a9b0c1d2e3"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "rag_documents",
        sa.Column("embedding_model", sa.String(length=80), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("rag_documents", "embedding_model")
