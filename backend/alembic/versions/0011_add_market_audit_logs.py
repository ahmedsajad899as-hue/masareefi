"""add market_audit_logs table

Revision ID: 0011_add_market_audit_logs
Revises: 0010_add_show_personal_features
Create Date: 2026-05-28
"""
from alembic import op
from sqlalchemy import text

revision = '0011_add_market_audit_logs'
down_revision = '0010_add_show_personal_features'
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    conn.execute(text("""
        CREATE TABLE IF NOT EXISTS market_audit_logs (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            market_owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            entity_type VARCHAR(20) NOT NULL,
            entity_id UUID NOT NULL,
            customer_id UUID NULL,
            action VARCHAR(20) NOT NULL DEFAULT 'update',
            changes JSONB NOT NULL DEFAULT '[]'::jsonb,
            created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
        )
    """))
    conn.execute(text("CREATE INDEX IF NOT EXISTS ix_market_audit_logs_owner ON market_audit_logs(market_owner_id)"))
    conn.execute(text("CREATE INDEX IF NOT EXISTS ix_market_audit_logs_entity ON market_audit_logs(entity_type, entity_id)"))
    conn.execute(text("CREATE INDEX IF NOT EXISTS ix_market_audit_logs_customer ON market_audit_logs(customer_id)"))
    conn.execute(text("CREATE INDEX IF NOT EXISTS ix_market_audit_logs_created ON market_audit_logs(created_at)"))


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS market_audit_logs")
