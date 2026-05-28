"""add show_personal_features to users

Revision ID: 0010_add_show_personal_features
Revises: 0009_add_market_tables
Create Date: 2026-05-28
"""
from alembic import op
from sqlalchemy import text

revision = '0010_add_show_personal_features'
down_revision = '0009_add_market_tables'
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    conn.execute(text(
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS show_personal_features "
        "BOOLEAN NOT NULL DEFAULT false"
    ))


def downgrade() -> None:
    op.drop_column('users', 'show_personal_features')
