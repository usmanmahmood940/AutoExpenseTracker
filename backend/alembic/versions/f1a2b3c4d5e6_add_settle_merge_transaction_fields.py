"""add settle/merge transaction statuses and fields

Revision ID: f1a2b3c4d5e6
Revises: e7f8a9b0c1d2
Create Date: 2026-09-08 16:45:00.000000

"""

from __future__ import annotations

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "f1a2b3c4d5e6"
down_revision: str | None = "a1b2c3d4e5f6"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_OLD_STATUSES = ("active", "deleted", "needs_review")
_NEW_STATUSES = ("active", "deleted", "needs_review", "settled", "merged")


def _status_check(values: tuple[str, ...]) -> str:
    allowed = ", ".join(f"'{v}'" for v in values)
    return f"status IN ({allowed})"


def upgrade() -> None:
    # Naming convention expands these to ck_transactions_transaction_status.
    op.drop_constraint("transaction_status", "transactions", type_="check")
    op.create_check_constraint(
        "transaction_status",
        "transactions",
        _status_check(_NEW_STATUSES),
    )

    op.add_column(
        "transactions",
        sa.Column("original_amount", sa.Numeric(14, 2), nullable=True),
    )
    op.add_column(
        "transactions",
        sa.Column(
            "settlement_groups",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=True,
        ),
    )
    op.add_column(
        "transactions",
        sa.Column("merged_into_id", sa.UUID(), nullable=True),
    )
    op.add_column(
        "transactions",
        sa.Column("settlement_group_id", sa.String(length=64), nullable=True),
    )
    op.create_index(
        "ix_transactions_merged_into_id",
        "transactions",
        ["merged_into_id"],
    )


def downgrade() -> None:
    op.execute(
        "UPDATE transactions SET status = 'active' "
        "WHERE status IN ('settled', 'merged')"
    )
    op.drop_index("ix_transactions_merged_into_id", table_name="transactions")
    op.drop_column("transactions", "settlement_group_id")
    op.drop_column("transactions", "merged_into_id")
    op.drop_column("transactions", "settlement_groups")
    op.drop_column("transactions", "original_amount")

    op.drop_constraint("transaction_status", "transactions", type_="check")
    op.create_check_constraint(
        "transaction_status",
        "transactions",
        _status_check(_OLD_STATUSES),
    )
