"""add market_products table and use_product_catalog flag

Revision ID: 0012_add_market_products
Revises: 0011_add_market_audit_logs
Create Date: 2026-05-29
"""
from alembic import op
from sqlalchemy import text

revision = '0012_add_market_products'
down_revision = '0011_add_market_audit_logs'
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()

    # Add product-catalog toggle to users (safe if already exists)
    conn.execute(text("""
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS use_product_catalog BOOLEAN NOT NULL DEFAULT false
    """))

    # Create market_products table
    conn.execute(text("""
        CREATE TABLE IF NOT EXISTS market_products (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            market_owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            name VARCHAR(300) NOT NULL,
            unit_price NUMERIC(12, 2) NOT NULL DEFAULT 0,
            updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
            created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
        )
    """))
    conn.execute(text(
        "CREATE INDEX IF NOT EXISTS ix_market_products_market_owner_id "
        "ON market_products(market_owner_id)"
    ))


def downgrade() -> None:
    conn = op.get_bind()
    conn.execute(text("DROP TABLE IF EXISTS market_products"))
    conn.execute(text("ALTER TABLE users DROP COLUMN IF EXISTS use_product_catalog"))
