"""ensure use_product_catalog column and market_products table exist

This is a safety migration in case 0012 was recorded as complete but
the ALTER TABLE/CREATE TABLE statements failed (e.g., due to a rollback).
All statements use IF NOT EXISTS so they are fully idempotent.

Revision ID: 0013_ensure_catalog_schema
Revises: 0012_add_market_products
Create Date: 2026-05-29
"""
from alembic import op
from sqlalchemy import text

revision = '0013_ensure_catalog_schema'
down_revision = '0012_add_market_products'
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()

    conn.execute(text("""
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS use_product_catalog BOOLEAN NOT NULL DEFAULT false
    """))

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
    pass  # intentionally no-op — downgrade handled by 0012
