"""add market_product_barcodes table for multi-barcode support

Revision ID: 0018_add_product_barcodes_table
Revises: 0017_ensure_barcode_column
Create Date: 2026-06-14
"""
from alembic import op
import sqlalchemy as sa

revision = "0018_add_product_barcodes_table"
down_revision = "0017_ensure_barcode_column"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "market_product_barcodes",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("product_id", sa.Uuid(), nullable=False),
        sa.Column("market_owner_id", sa.Uuid(), nullable=False),
        sa.Column("barcode_value", sa.String(200), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=True,
        ),
        sa.ForeignKeyConstraint(
            ["product_id"],
            ["market_products.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["market_owner_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_market_product_barcodes_product_id",
        "market_product_barcodes",
        ["product_id"],
    )
    op.create_index(
        "ix_market_product_barcodes_market_owner_id",
        "market_product_barcodes",
        ["market_owner_id"],
    )
    op.create_index(
        "ix_market_product_barcodes_barcode_value",
        "market_product_barcodes",
        ["barcode_value"],
    )


def downgrade() -> None:
    op.drop_index("ix_market_product_barcodes_barcode_value", "market_product_barcodes")
    op.drop_index("ix_market_product_barcodes_market_owner_id", "market_product_barcodes")
    op.drop_index("ix_market_product_barcodes_product_id", "market_product_barcodes")
    op.drop_table("market_product_barcodes")
