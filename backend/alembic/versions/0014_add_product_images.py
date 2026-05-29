"""add product_images table for catalog reference photos

Revision ID: 0014_add_product_images
Revises: 0013_ensure_catalog_schema
Create Date: 2026-05-30
"""
from alembic import op
from sqlalchemy import text

revision = '0014_add_product_images'
down_revision = '0013_ensure_catalog_schema'
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    # SQLite uses BLOB, PostgreSQL uses BYTEA — both handled by LargeBinary.
    # gen_random_uuid() is PostgreSQL-only; SQLite creates the table via create_all.
    dialect = conn.dialect.name
    if dialect == "sqlite":
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS product_images (
                id          TEXT        NOT NULL PRIMARY KEY,
                product_id  TEXT        NOT NULL REFERENCES market_products(id) ON DELETE CASCADE,
                market_owner_id TEXT    NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                image_data  BLOB        NOT NULL,
                created_at  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
        """))
    else:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS product_images (
                id          UUID        NOT NULL DEFAULT gen_random_uuid(),
                product_id  UUID        NOT NULL,
                market_owner_id UUID    NOT NULL,
                image_data  BYTEA       NOT NULL,
                created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
                PRIMARY KEY (id),
                CONSTRAINT fk_pi_product
                    FOREIGN KEY (product_id)
                    REFERENCES market_products(id)
                    ON DELETE CASCADE,
                CONSTRAINT fk_pi_owner
                    FOREIGN KEY (market_owner_id)
                    REFERENCES users(id)
                    ON DELETE CASCADE
            )
        """))
    conn.execute(text(
        "CREATE INDEX IF NOT EXISTS ix_product_images_product_id "
        "ON product_images (product_id)"
    ))
    conn.execute(text(
        "CREATE INDEX IF NOT EXISTS ix_product_images_owner_id "
        "ON product_images (market_owner_id)"
    ))


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS product_images")
