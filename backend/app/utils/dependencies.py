import uuid
from datetime import datetime, timezone

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.user import User
from app.utils.jwt import decode_access_token

bearer_scheme = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    token = credentials.credentials
    try:
        user_id = decode_access_token(token)
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    result = await db.execute(select(User).where(User.id == uuid.UUID(user_id)))
    user = result.scalar_one_or_none()

    if user is None or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found or inactive")

    return user


async def get_current_admin(
    current_user: User = Depends(get_current_user),
) -> User:
    if not current_user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return current_user


# ── Plan Limits ────────────────────────────────────────────────────────────────

TRIAL_DAYS = 14

PLAN_LIMITS: dict[str, dict[str, int]] = {
    "trial":    {"daily_expenses": 999, "wallets": 999, "custom_categories": 999, "budgets": 999, "goals": 999, "voice_monthly": 999},
    "free":     {"daily_expenses":   3, "wallets":   2, "custom_categories":   0, "budgets":   1, "goals":   0, "voice_monthly":   0},
    "pro":      {"daily_expenses": 999, "wallets":  10, "custom_categories":  20, "budgets": 999, "goals": 999, "voice_monthly":  30},
    "business": {"daily_expenses": 999, "wallets": 999, "custom_categories": 999, "budgets": 999, "goals": 999, "voice_monthly": 999},
    "custom":   {"daily_expenses":   0, "wallets":   0, "custom_categories":   0, "budgets":   0, "goals":   0, "voice_monthly":   0},
}

# Maps resource key → User model attribute for the "custom" plan
_CUSTOM_FIELD: dict[str, str] = {
    "daily_expenses":    "custom_daily_expenses",
    "wallets":           "custom_wallets",
    "custom_categories": "custom_categories",
    "budgets":           "custom_budgets",
    "goals":             "custom_goals",
    "voice_monthly":     "custom_voice_monthly",
}

_UPGRADE_MESSAGES: dict[str, str] = {
    "daily_expenses":    "وصلت الحد اليومي للمصاريف ({limit}/يوم). الترقية إلى Pro تتيح إضافة بلا حدود.",
    "wallets":           "وصلت الحد الأقصى للمحافظ ({limit}). الترقية إلى Pro تتيح إضافة المزيد.",
    "custom_categories": "الفئات المخصصة متاحة في باقة Pro فقط. قم بالترقية لإضافة فئاتك الخاصة.",
    "budgets":           "وصلت الحد الأقصى للميزانيات ({limit}). قم بالترقية.",
    "goals":             "أهداف الادخار متاحة في باقة Pro فقط. قم بالترقية.",
    "voice_monthly":     "وصلت الحد الشهري للمساعد الصوتي. الترقية إلى Pro تمنحك 30 استخداماً شهرياً.",
}


def _utc_aware(dt: datetime) -> datetime:
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def get_effective_plan(user: User) -> str:
    """Return the active plan, collapsing expired trials/subscriptions to 'free'."""
    if getattr(user, "is_admin", False):
        return "business"
    plan = getattr(user, "plan", None) or "trial"
    if plan == "trial":
        started = getattr(user, "trial_started_at", None)
        if not started:
            return "free"
        bonus = getattr(user, "referral_bonus_days", 0) or 0
        elapsed = (datetime.now(timezone.utc) - _utc_aware(started)).days
        return "trial" if elapsed < (TRIAL_DAYS + bonus) else "free"
    if plan in ("pro", "business"):
        expires = getattr(user, "plan_expires_at", None)
        if expires and datetime.now(timezone.utc) > _utc_aware(expires):
            return "free"
    return plan


def check_plan_limit(current: int, user: User, resource: str, extra: int = 1) -> None:
    """Raise HTTP 402 if adding `extra` more items would exceed the resource limit."""
    plan = get_effective_plan(user)
    if plan == "custom":
        field = _CUSTOM_FIELD.get(resource)
        limit = getattr(user, field, None) if field else None
        limit = 0 if limit is None else limit
    else:
        limit = PLAN_LIMITS.get(plan, PLAN_LIMITS["free"]).get(resource, 0)
    if limit >= 999:
        return  # effectively unlimited
    if current + extra > limit:
        msg = _UPGRADE_MESSAGES.get(resource, "قم بالترقية للاستمرار.").replace("{limit}", str(limit))
        raise HTTPException(
            status_code=402,
            detail={
                "error":    "plan_limit_reached",
                "resource": resource,
                "limit":    limit,
                "current":  current,
                "plan":     plan,
                "message":  msg,
            },
        )
