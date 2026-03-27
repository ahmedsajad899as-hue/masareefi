"""add total_income to wallets

Revision ID: 0002_wallet_total_income
Revises: 0001_initial
Create Date: 2026-03-27

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0002_wallet_total_income"
down_revision: Union[str, None] = "0001_initial"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("wallets", sa.Column("total_income", sa.Numeric(14, 2), nullable=False, server_default="0"))


def downgrade() -> None:
    op.drop_column("wallets", "total_income")
