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
    with op.batch_alter_table("market_products") as batch_op:
        batch_op.add_column(
            sa.Column("barcode", sa.String(100), nullable=True)
        )
        batch_op.create_index(
            "ix_market_products_barcode", ["barcode"]
        )


def downgrade() -> None:
    with op.batch_alter_table("market_products") as batch_op:
        batch_op.drop_index("ix_market_products_barcode")
        batch_op.drop_column("barcode")
