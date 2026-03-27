"""add wallets, wallet_transfers, is_admin, sector, wallet_id

Revision ID: 0003_add_wallets_admin_sector
Revises: 0002_wallet_total_income
Create Date: 2026-03-28

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0003_add_wallets_admin_sector"
down_revision: Union[str, None] = "0002_wallet_total_income"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── wallets table ──
    op.create_table(
        "wallets",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("wallet_type", sa.String(20), nullable=False, server_default="cash"),
        sa.Column("balance", sa.Numeric(14, 2), nullable=False, server_default="0"),
        sa.Column("total_income", sa.Numeric(14, 2), nullable=False, server_default="0"),
        sa.Column("currency", sa.String(10), nullable=False, server_default="IQD"),
        sa.Column("icon", sa.String(10), nullable=False, server_default="💰"),
        sa.Column("color", sa.String(20), nullable=False, server_default="#4CAF50"),
        sa.Column("is_default", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    # ── wallet_transfers table ──
    op.create_table(
        "wallet_transfers",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("from_wallet_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("wallets.id", ondelete="CASCADE"), nullable=False),
        sa.Column("to_wallet_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("wallets.id", ondelete="CASCADE"), nullable=False),
        sa.Column("amount", sa.Numeric(14, 2), nullable=False),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    # ── users: add is_admin column ──
    op.add_column("users", sa.Column("is_admin", sa.Boolean(), nullable=False, server_default="false"))

    # ── categories: add sector column ──
    op.add_column("categories", sa.Column("sector", sa.String(50), nullable=True))

    # ── expenses: add wallet_id FK ──
    op.add_column("expenses", sa.Column(
        "wallet_id",
        postgresql.UUID(as_uuid=True),
        sa.ForeignKey("wallets.id", ondelete="SET NULL"),
        nullable=True,
    ))
    op.create_index("ix_expenses_wallet_id", "expenses", ["wallet_id"])


def downgrade() -> None:
    op.drop_index("ix_expenses_wallet_id", table_name="expenses")
    op.drop_column("expenses", "wallet_id")
    op.drop_column("categories", "sector")
    op.drop_column("users", "is_admin")
    op.drop_table("wallet_transfers")
    op.drop_table("wallets")
