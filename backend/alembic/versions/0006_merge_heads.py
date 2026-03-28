"""merge duplicate 0002 branch into main chain

Revision ID: 0006_merge_heads
Revises: 0005_seed_admin_user, 0002_add_wallets_sector_is_admin
Create Date: 2026-03-28

Merges the orphan 0002_add_wallets_sector_is_admin branch (no-op) with the
main migration chain so that `alembic upgrade head` has a single head and
runs all migrations including 0004 (phone_number) and 0005 (seed admin user).
"""
from typing import Sequence, Union

revision: str = "0006_merge_heads"
down_revision: Union[tuple, None] = ("0005_seed_admin_user", "0002_add_wallets_sector_is_admin")
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass  # Merge only — no schema changes


def downgrade() -> None:
    pass
