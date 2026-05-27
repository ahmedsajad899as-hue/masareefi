"""add market tables (customers, sales, items, supplier invoices)

Revision ID: 0009
Revises: 0008_add_role_and_market_fields
Create Date: 2026-05-28
"""
from alembic import op
import sqlalchemy as sa

revision = '0009_add_market_tables'
down_revision = '0008_add_role_and_market_fields'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'market_customers',
        sa.Column('id', sa.Uuid(), primary_key=True),
        sa.Column('market_owner_id', sa.Uuid(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('name', sa.String(200), nullable=False),
        sa.Column('phone', sa.String(30), nullable=True, index=True),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('linked_user_id', sa.Uuid(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True, index=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('CURRENT_TIMESTAMP')),
    )

    op.create_table(
        'market_sales',
        sa.Column('id', sa.Uuid(), primary_key=True),
        sa.Column('market_owner_id', sa.Uuid(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('customer_id', sa.Uuid(), sa.ForeignKey('market_customers.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('sale_date', sa.DateTime(timezone=True), nullable=False),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('total_amount', sa.Numeric(12, 2), nullable=False, server_default='0'),
        sa.Column('is_paid', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('paid_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('CURRENT_TIMESTAMP')),
    )

    op.create_table(
        'market_sale_items',
        sa.Column('id', sa.Uuid(), primary_key=True),
        sa.Column('sale_id', sa.Uuid(), sa.ForeignKey('market_sales.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('product_name', sa.String(300), nullable=False),
        sa.Column('quantity', sa.Numeric(10, 3), nullable=False, server_default='1'),
        sa.Column('unit_price', sa.Numeric(12, 2), nullable=False, server_default='0'),
    )

    op.create_table(
        'supplier_invoices',
        sa.Column('id', sa.Uuid(), primary_key=True),
        sa.Column('market_owner_id', sa.Uuid(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('supplier_name', sa.String(300), nullable=False),
        sa.Column('invoice_date', sa.DateTime(timezone=True), nullable=False),
        sa.Column('due_date', sa.DateTime(timezone=True), nullable=True),
        sa.Column('total_amount', sa.Numeric(12, 2), nullable=False, server_default='0'),
        sa.Column('is_paid', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('paid_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('CURRENT_TIMESTAMP')),
    )

    op.create_table(
        'supplier_invoice_items',
        sa.Column('id', sa.Uuid(), primary_key=True),
        sa.Column('invoice_id', sa.Uuid(), sa.ForeignKey('supplier_invoices.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('product_name', sa.String(300), nullable=False),
        sa.Column('quantity', sa.Numeric(10, 3), nullable=False, server_default='1'),
        sa.Column('unit_price', sa.Numeric(12, 2), nullable=False, server_default='0'),
    )


def downgrade() -> None:
    op.drop_table('supplier_invoice_items')
    op.drop_table('supplier_invoices')
    op.drop_table('market_sale_items')
    op.drop_table('market_sales')
    op.drop_table('market_customers')
