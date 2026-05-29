"""add market_products table and use_product_catalog flag

Revision ID: 0012_add_market_products
Revises: 0011_add_market_audit_logs
Create Date: 2026-05-29
"""
from alembic import op
import sqlalchemy as sa

revision = '0012_add_market_products'
down_revision = '0011_add_market_audit_logs'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add product-catalog toggle to users
    op.add_column(
        'users',
        sa.Column('use_product_catalog', sa.Boolean(), nullable=False,
                  server_default='false'),
    )

    # Create market_products table
    op.create_table(
        'market_products',
        sa.Column('id', sa.Uuid(), primary_key=True),
        sa.Column('market_owner_id', sa.Uuid(), sa.ForeignKey('users.id', ondelete='CASCADE'),
                  nullable=False, index=True),
        sa.Column('name', sa.String(300), nullable=False),
        sa.Column('unit_price', sa.Numeric(12, 2), nullable=False, server_default='0'),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index('ix_market_products_market_owner_id', 'market_products', ['market_owner_id'])


def downgrade() -> None:
    op.drop_table('market_products')
    op.drop_column('users', 'use_product_catalog')
