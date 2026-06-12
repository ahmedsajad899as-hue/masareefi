"""add_barcode_to_market_products

Revision ID: 0016_add_barcode_to_market_products
Revises: 0015_add_vision_daily_counter
Create Date: 2026-06-13

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers
revision = "0016_add_barcode_to_market_products"
down_revision = "0015_add_vision_daily_counter"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "market_products",
        sa.Column("barcode", sa.String(100), nullable=True)
    )
    op.create_index("ix_market_products_barcode", "market_products", ["barcode"])


def downgrade() -> None:
    op.drop_index("ix_market_products_barcode", table_name="market_products")
    op.drop_column("market_products", "barcode")
