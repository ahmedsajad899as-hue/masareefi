"""seed default admin user if not exists

Revision ID: 0005_seed_admin_user
Revises: 0004_add_phone_number
Create Date: 2026-03-28

Inserts admin@masareefi.com with password 123456789 and default categories/wallets
if the user does not already exist. Safe to run multiple times (idempotent).
"""
from typing import Sequence, Union
import uuid

from alembic import op
import sqlalchemy as sa
from sqlalchemy import text

revision: str = "0005_seed_admin_user"
down_revision: Union[str, None] = "0004_add_phone_number"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

ADMIN_EMAIL = "admin@masareefi.com"
# bcrypt hash of "123456789" — generated at migration authoring time
ADMIN_HASH = "$2b$12$s5LRKSpecqzlgzvQhNq5P.O905QT/gktIIKpAtlD1AAfGfj.D7OIq"

SYSTEM_CATEGORIES = [
    ("طعام",    "Food",          "🍔", "#FF9800", "طعام ومطاعم",        0),
    ("مواصلات", "Transport",     "🚗", "#2196F3", "سيارة ونقل",         1),
    ("تسوق",    "Shopping",      "🛍️","#E91E63", "احتياجات شخصية",     2),
    ("صحة",     "Health",        "🏥", "#4CAF50", "صحة وعلاج",          3),
    ("ترفيه",   "Entertainment", "🎮", "#9C27B0", "ترفيه وتسلية",       4),
    ("تعليم",   "Education",     "📚", "#00BCD4", "تعليم وتطوير",       5),
    ("فواتير",  "Bills",         "💡", "#FF5722", "فواتير واشتراكات",   6),
    ("سكن",     "Housing",       "🏠", "#795548", "سكن ومنزل",          7),
    ("أخرى",    "Other",         "➕", "#9E9E9E", "أخرى",               8),
]

DEFAULT_WALLETS = [
    ("فلوس تحت اليد", "cash",       "💰", "#FF9800", True),
    ("Zain Cash",      "zaincash",   "📱", "#7B1FA2", False),
    ("مصرف الرافدين", "mastercard", "💳", "#1A237E", False),
]


def upgrade() -> None:
    conn = op.get_bind()

    # Check if admin user already exists
    result = conn.execute(
        text("SELECT id FROM users WHERE email = :email"),
        {"email": ADMIN_EMAIL},
    )
    row = result.fetchone()
    if row:
        # Ensure is_admin flag is set
        conn.execute(
            text("UPDATE users SET is_admin = true WHERE email = :email"),
            {"email": ADMIN_EMAIL},
        )
        return

    # Create admin user
    user_id = str(uuid.uuid4())
    conn.execute(
        text("""
            INSERT INTO users (id, email, password_hash, full_name, preferred_language,
                               currency, is_active, is_admin, created_at, updated_at)
            VALUES (:id, :email, :pw_hash, :full_name, 'ar', 'IQD', true, true,
                    NOW(), NOW())
        """),
        {
            "id": user_id,
            "email": ADMIN_EMAIL,
            "pw_hash": ADMIN_HASH,
            "full_name": "مدير النظام",
        },
    )

    # Insert system categories
    for name_ar, name_en, icon, color, sector, sort_order in SYSTEM_CATEGORIES:
        conn.execute(
            text("""
                INSERT INTO categories (id, user_id, name_ar, name_en, icon, color,
                                        sector, is_system, sort_order, created_at, updated_at)
                VALUES (:id, :user_id, :name_ar, :name_en, :icon, :color,
                        :sector, true, :sort_order, NOW(), NOW())
            """),
            {
                "id": str(uuid.uuid4()),
                "user_id": user_id,
                "name_ar": name_ar,
                "name_en": name_en,
                "icon": icon,
                "color": color,
                "sector": sector,
                "sort_order": sort_order,
            },
        )

    # Insert default wallets
    for name, wallet_type, icon, color, is_default in DEFAULT_WALLETS:
        conn.execute(
            text("""
                INSERT INTO wallets (id, user_id, name, wallet_type, balance,
                                     total_income, currency, icon, color, is_default,
                                     created_at, updated_at)
                VALUES (:id, :user_id, :name, :wallet_type, 0, 0, 'IQD',
                        :icon, :color, :is_default, NOW(), NOW())
            """),
            {
                "id": str(uuid.uuid4()),
                "user_id": user_id,
                "name": name,
                "wallet_type": wallet_type,
                "icon": icon,
                "color": color,
                "is_default": is_default,
            },
        )


def downgrade() -> None:
    conn = op.get_bind()
    result = conn.execute(
        text("SELECT id FROM users WHERE email = :email"),
        {"email": ADMIN_EMAIL},
    )
    row = result.fetchone()
    if row:
        user_id = str(row[0])
        conn.execute(text("DELETE FROM wallets WHERE user_id = :uid"), {"uid": user_id})
        conn.execute(text("DELETE FROM categories WHERE user_id = :uid"), {"uid": user_id})
        conn.execute(text("DELETE FROM users WHERE id = :uid"), {"uid": user_id})
