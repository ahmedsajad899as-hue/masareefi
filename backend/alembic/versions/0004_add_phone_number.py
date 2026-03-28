"""add phone_number to users

Revision ID: 0004_add_phone_number
Revises: 0003_add_wallets_admin_sector
Create Date: 2026-03-28

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0004_add_phone_number"
down_revision: Union[str, None] = "0003_add_wallets_admin_sector"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("phone_number", sa.String(20), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "phone_number")
