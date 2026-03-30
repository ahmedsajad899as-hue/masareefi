"""add password reset token columns to users

Revision ID: 0007_add_password_reset_tokens
Revises: 0006_merge_heads
Create Date: 2026-03-30

Adds reset_token_hash and reset_token_expires_at to the users table
so the forgot-password endpoint can store a bcrypt-hashed OTP.
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0007_add_password_reset_tokens"
down_revision: Union[str, None] = "0006_merge_heads"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("reset_token_hash", sa.String(255), nullable=True))
    op.add_column("users", sa.Column("reset_token_expires_at", sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "reset_token_expires_at")
    op.drop_column("users", "reset_token_hash")
