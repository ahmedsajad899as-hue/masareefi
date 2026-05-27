"""add market tables (customers, sales, items, supplier invoices)

Revision ID: 0009
Revises: 0008_add_role_and_market_fields
Create Date: 2026-05-28
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import text

revision = '0009_add_market_tables'
down_revision = '0008_add_role_and_market_fields'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Use IF NOT EXISTS so migrations are safe even if guard statements already
    # created these tables on a previous Railway deployment.
    conn = op.get_bind()
    conn.execute(text("""
        CREATE TABLE IF NOT EXISTS market_customers (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            market_owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            name VARCHAR(200) NOT NULL,
            phone VARCHAR(30) NULL,
            notes TEXT NULL,
            linked_user_id UUID NULL REFERENCES users(id) ON DELETE SET NULL,
            created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
        )
    """))
    conn.execute(text("CREATE INDEX IF NOT EXISTS ix_market_customers_market_owner_id ON market_customers(market_owner_id)"))
    conn.execute(text("CREATE INDEX IF NOT EXISTS ix_market_customers_phone ON market_customers(phone)"))
    conn.execute(text("CREATE INDEX IF NOT EXISTS ix_market_customers_linked_user_id ON market_customers(linked_user_id)"))

    conn.execute(text("""
        CREATE TABLE IF NOT EXISTS market_sales (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            market_owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            customer_id UUID NOT NULL REFERENCES market_customers(id) ON DELETE CASCADE,
            sale_date TIMESTAMP WITH TIME ZONE NOT NULL,
            notes TEXT NULL,
            total_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
            is_paid BOOLEAN NOT NULL DEFAULT false,
            paid_at TIMESTAMP WITH TIME ZONE NULL,
            created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
        )
    """))
    conn.execute(text("CREATE INDEX IF NOT EXISTS ix_market_sales_market_owner_id ON market_sales(market_owner_id)"))
    conn.execute(text("CREATE INDEX IF NOT EXISTS ix_market_sales_customer_id ON market_sales(customer_id)"))

    conn.execute(text("""
        CREATE TABLE IF NOT EXISTS market_sale_items (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            sale_id UUID NOT NULL REFERENCES market_sales(id) ON DELETE CASCADE,
            product_name VARCHAR(300) NOT NULL,
            quantity NUMERIC(10,3) NOT NULL DEFAULT 1,
            unit_price NUMERIC(12,2) NOT NULL DEFAULT 0
        )
    """))
    conn.execute(text("CREATE INDEX IF NOT EXISTS ix_market_sale_items_sale_id ON market_sale_items(sale_id)"))

    conn.execute(text("""
        CREATE TABLE IF NOT EXISTS supplier_invoices (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            market_owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            supplier_name VARCHAR(300) NOT NULL,
            invoice_date TIMESTAMP WITH TIME ZONE NOT NULL,
            due_date TIMESTAMP WITH TIME ZONE NULL,
            total_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
            is_paid BOOLEAN NOT NULL DEFAULT false,
            paid_at TIMESTAMP WITH TIME ZONE NULL,
            notes TEXT NULL,
            created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
        )
    """))
    conn.execute(text("CREATE INDEX IF NOT EXISTS ix_supplier_invoices_market_owner_id ON supplier_invoices(market_owner_id)"))

    conn.execute(text("""
        CREATE TABLE IF NOT EXISTS supplier_invoice_items (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            invoice_id UUID NOT NULL REFERENCES supplier_invoices(id) ON DELETE CASCADE,
            product_name VARCHAR(300) NOT NULL,
            quantity NUMERIC(10,3) NOT NULL DEFAULT 1,
            unit_price NUMERIC(12,2) NOT NULL DEFAULT 0
        )
    """))
    conn.execute(text("CREATE INDEX IF NOT EXISTS ix_supplier_invoice_items_invoice_id ON supplier_invoice_items(invoice_id)"))


def downgrade() -> None:
    op.drop_table('supplier_invoice_items')
    op.drop_table('supplier_invoices')
    op.drop_table('market_sale_items')
    op.drop_table('market_sales')
    op.drop_table('market_customers')
