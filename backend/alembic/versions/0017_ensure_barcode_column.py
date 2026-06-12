"""ensure barcode column on market_products

Revision ID: 0017_ensure_barcode_column
Revises: 0016_add_barcode_to_market_products
Create Date: 2026-06-13

Uses raw SQL with IF NOT EXISTS so it is safe to run even if migration 0016
partially added the column already.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import text

revision = "0017_ensure_barcode_column"
down_revision = "0016_add_barcode_to_market_products"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ADD COLUMN IF NOT EXISTS — safe on Postgres even if column already exists
    op.execute(text(
        "ALTER TABLE market_products ADD COLUMN IF NOT EXISTS barcode VARCHAR(100)"
    ))
    # CREATE INDEX IF NOT EXISTS — safe to re-run
    op.execute(text(
        "CREATE INDEX IF NOT EXISTS ix_market_products_barcode ON market_products (barcode)"
    ))


def downgrade() -> None:
    op.execute(text(
        "DROP INDEX IF EXISTS ix_market_products_barcode"
    ))
    op.execute(text(
        "ALTER TABLE market_products DROP COLUMN IF EXISTS barcode"
    ))
