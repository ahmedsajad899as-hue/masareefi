"""add role and market fields to users

Revision ID: 0008
Revises: 0007_add_password_reset_tokens
Create Date: 2026-05-28
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import text

revision = '0008_add_role_and_market_fields'
down_revision = '0007_add_password_reset_tokens'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Use IF NOT EXISTS so this is safe to run even if the guard statements
    # in database.py already added these columns on a previous deployment.
    conn = op.get_bind()
    conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(20) NOT NULL DEFAULT 'user'"))
    conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS store_name VARCHAR(200) NULL"))
    conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS market_overdue_days INTEGER NOT NULL DEFAULT 30"))


def downgrade() -> None:
    op.drop_column('users', 'market_overdue_days')
    op.drop_column('users', 'store_name')
    op.drop_column('users', 'role')
