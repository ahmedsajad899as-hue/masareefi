"""add role and market fields to users

Revision ID: 0008
Revises: 0007_add_password_reset_tokens
Create Date: 2026-05-28
"""
from alembic import op
import sqlalchemy as sa

revision = '0008_add_role_and_market_fields'
down_revision = '0007_add_password_reset_tokens'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('users', sa.Column('role', sa.String(20), nullable=False, server_default='user'))
    op.add_column('users', sa.Column('store_name', sa.String(200), nullable=True))
    op.add_column('users', sa.Column('market_overdue_days', sa.Integer(), nullable=False, server_default='30'))


def downgrade() -> None:
    op.drop_column('users', 'market_overdue_days')
    op.drop_column('users', 'store_name')
    op.drop_column('users', 'role')
