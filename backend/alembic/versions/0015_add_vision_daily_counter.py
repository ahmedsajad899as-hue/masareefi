"""add vision daily usage counter to users

Revision ID: 0015_add_vision_daily_counter
Revises: 0014_add_product_images
Create Date: 2026-06-07
"""
from alembic import op
import sqlalchemy as sa

revision = '0015_add_vision_daily_counter'
down_revision = '0014_add_product_images'
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    dialect = conn.dialect.name
    if dialect == "sqlite":
        conn.execute(sa.text("ALTER TABLE users ADD COLUMN vision_uses_today INTEGER NOT NULL DEFAULT 0"))
        conn.execute(sa.text("ALTER TABLE users ADD COLUMN vision_reset_date TEXT NOT NULL DEFAULT ''"))
        conn.execute(sa.text("ALTER TABLE users ADD COLUMN custom_daily_vision INTEGER"))
    else:
        conn.execute(sa.text("ALTER TABLE users ADD COLUMN IF NOT EXISTS vision_uses_today INTEGER NOT NULL DEFAULT 0"))
        conn.execute(sa.text("ALTER TABLE users ADD COLUMN IF NOT EXISTS vision_reset_date VARCHAR(10) NOT NULL DEFAULT ''"))
        conn.execute(sa.text("ALTER TABLE users ADD COLUMN IF NOT EXISTS custom_daily_vision INTEGER"))


def downgrade() -> None:
    pass
