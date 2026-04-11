import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.user import User
from app.schemas.user import UserOut
from app.utils.dependencies import get_current_admin
from app.utils.hashing import hash_password
from app.utils.jwt import create_access_token

router = APIRouter()


# ─── Schemas ──────────────────────────────────────────────────────────────────

class AdminCreateUser(BaseModel):
    email: EmailStr
    password: str
    full_name: str
    phone_number: str | None = None
    preferred_language: str = "ar"
    currency: str = "IQD"
    is_admin: bool = False
    plan: str = "trial"
    plan_expires_at: str | None = None
    custom_daily_expenses: int | None = None
    custom_wallets: int | None = None
    custom_categories: int | None = None
    custom_budgets: int | None = None
    custom_goals: int | None = None
    custom_voice_monthly: int | None = None


class AdminUpdateUser(BaseModel):
    full_name: str | None = None
    phone_number: str | None = None
    preferred_language: str | None = None
    currency: str | None = None
    is_active: bool | None = None
    is_admin: bool | None = None
    password: str | None = None
    plan: str | None = None
    plan_expires_at: str | None = None
    custom_daily_expenses: int | None = None
    custom_wallets: int | None = None
    custom_categories: int | None = None
    custom_budgets: int | None = None
    custom_goals: int | None = None
    custom_voice_monthly: int | None = None


class UserOutAdmin(UserOut):
    is_admin: bool


# ─── Endpoints ────────────────────────────────────────────────────────────────

@router.get("/users", response_model=list[UserOutAdmin])
async def list_users(
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    result = await db.execute(select(User).order_by(User.created_at))
    return result.scalars().all()


@router.post("/users", response_model=UserOutAdmin, status_code=status.HTTP_201_CREATED)
async def create_user(
    body: AdminCreateUser,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    existing = await db.execute(select(User).where(User.email == body.email))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Email already registered")

    user = User(
        email=body.email,
        password_hash=hash_password(body.password),
        full_name=body.full_name,
        phone_number=body.phone_number,
        preferred_language=body.preferred_language,
        currency=body.currency,
        is_admin=body.is_admin,
        plan=body.plan,
        plan_expires_at=datetime.fromisoformat(body.plan_expires_at).replace(tzinfo=timezone.utc) if body.plan_expires_at else None,
        trial_started_at=datetime.now(timezone.utc) if body.plan == "trial" else None,
        custom_daily_expenses=body.custom_daily_expenses,
        custom_wallets=body.custom_wallets,
        custom_categories=body.custom_categories,
        custom_budgets=body.custom_budgets,
        custom_goals=body.custom_goals,
        custom_voice_monthly=body.custom_voice_monthly,
    )
    db.add(user)

    # Seed system categories for new user
    from app.routers.auth import _seed_system_categories, _seed_default_wallets
    await db.flush()
    await _seed_system_categories(db, user.id)
    await _seed_default_wallets(db, user.id, user.currency)

    await db.commit()
    await db.refresh(user)
    return user


@router.patch("/users/{user_id}", response_model=UserOutAdmin)
async def update_user(
    user_id: uuid.UUID,
    body: AdminUpdateUser,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Prevent admin from removing their own admin status
    if user.id == admin.id and body.is_admin is False:
        raise HTTPException(status_code=400, detail="Cannot remove your own admin status")

    update_data = body.model_dump(exclude_none=True)
    if "password" in update_data:
        user.password_hash = hash_password(update_data.pop("password"))
    if "plan_expires_at" in update_data:
        raw = update_data.pop("plan_expires_at")
        user.plan_expires_at = datetime.fromisoformat(raw).replace(tzinfo=timezone.utc) if raw else None
    # When changing plan to trial, set trial_started_at if not already set
    if update_data.get("plan") == "trial" and user.trial_started_at is None:
        user.trial_started_at = datetime.now(timezone.utc)
    for field, value in update_data.items():
        setattr(user, field, value)

    await db.commit()
    await db.refresh(user)
    return user


@router.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    if user_id == admin.id:
        raise HTTPException(status_code=400, detail="Cannot delete your own account")

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    await db.delete(user)
    await db.commit()


@router.post("/users/{user_id}/impersonate")
async def impersonate_user(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    """Generate a temporary access token for the target user (admin-only view)."""
    if user_id == admin.id:
        raise HTTPException(status_code=400, detail="Cannot impersonate yourself")

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if not user.is_active:
        raise HTTPException(status_code=400, detail="User account is disabled")

    access_token = create_access_token(str(user.id))
    return {
        "access_token": access_token,
        "user": {
            "id": str(user.id),
            "email": user.email,
            "full_name": user.full_name,
            "currency": user.currency,
            "preferred_language": user.preferred_language,
            "is_admin": False,
            "is_active": user.is_active,
            "created_at": user.created_at.isoformat() if user.created_at else None,
        },
    }


@router.get("/activity")
async def get_activity(
    limit: int = 200,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    """Return the latest user activity entries (logins, registrations, expenses)."""
    from sqlalchemy import text
    ACTION_LABELS = {
        "login":       "تسجيل دخول",
        "register":    "تسجيل حساب جديد",
        "add_expense": "أضاف مصروف",
        "add_income":  "أضاف دخل",
    }
    try:
        sql = text("""
            SELECT
                ua.id          AS act_id,
                u.full_name    AS user_name,
                u.email        AS user_email,
                ua.action      AS act_action,
                ua.created_at  AS act_created_at
            FROM user_activities ua
            JOIN users u ON ua.user_id = u.id
            ORDER BY ua.created_at DESC
            LIMIT :lim
        """)
        result = await db.execute(sql, {"lim": min(limit, 500)})
        rows = result.mappings().fetchall()
        return [
            {
                "id":         row["act_id"],
                "user_name":  row["user_name"],
                "user_email": row["user_email"],
                "action":     ACTION_LABELS.get(row["act_action"], row["act_action"]),
                "created_at": row["act_created_at"].isoformat() if row["act_created_at"] else None,
            }
            for row in rows
        ]
    except Exception:
        await db.rollback()
        return []
