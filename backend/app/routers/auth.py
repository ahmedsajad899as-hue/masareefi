import secrets
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.user import User, RefreshToken
import logging

from app.schemas.user import UserRegister, UserLogin, UserOut, TokenPair, RefreshRequest, UserUpdate, ChangePasswordRequest, ForgotPasswordRequest, ResetPasswordRequest
from app.utils.email import send_reset_email
from app.utils.hashing import hash_password, verify_password
from app.utils.jwt import create_access_token, create_refresh_token, hash_refresh_token
from app.utils.dependencies import get_current_user

router = APIRouter()


@router.post("/register", response_model=TokenPair, status_code=status.HTTP_201_CREATED)
async def register(body: UserRegister, db: AsyncSession = Depends(get_db)):
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
        plan="trial",
        trial_started_at=datetime.now(timezone.utc),
        referral_code=secrets.token_urlsafe(6).upper(),
    )
    db.add(user)
    await db.flush()  # get user.id before commit

    # Handle incoming referral code — reward the referrer
    if body.referral_code:
        ref_result = await db.execute(
            select(User).where(User.referral_code == body.referral_code.strip().upper())
        )
        referrer = ref_result.scalar_one_or_none()
        if referrer and referrer.id != user.id:
            user.referred_by_id = referrer.id
            referrer.referral_count = (referrer.referral_count or 0) + 1
            referrer.referral_bonus_days = (referrer.referral_bonus_days or 0) + 7

    # Seed system categories for new user
    await _seed_system_categories(db, user.id)

    # Seed default wallets for new user
    await _seed_default_wallets(db, user.id, user.currency)

    access_token = create_access_token(str(user.id))
    raw_refresh, refresh_hash, expires_at = create_refresh_token()

    rt = RefreshToken(user_id=user.id, token_hash=refresh_hash, expires_at=expires_at)
    db.add(rt)
    await db.commit()
    await db.refresh(user)

    return TokenPair(
        access_token=access_token,
        refresh_token=raw_refresh,
        user=UserOut.model_validate(user),
    )


@router.post("/login", response_model=TokenPair)
async def login(body: UserLogin, db: AsyncSession = Depends(get_db)):

    result = await db.execute(select(User).where(User.email == body.email, User.is_active == True))
    user = result.scalar_one_or_none()
    if not user or not verify_password(body.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    access_token = create_access_token(str(user.id))
    raw_refresh, refresh_hash, expires_at = create_refresh_token()

    rt = RefreshToken(user_id=user.id, token_hash=refresh_hash, expires_at=expires_at)
    db.add(rt)
    await db.commit()

    return TokenPair(
        access_token=access_token,
        refresh_token=raw_refresh,
        user=UserOut.model_validate(user),
    )


@router.post("/refresh", response_model=TokenPair)
async def refresh_tokens(body: RefreshRequest, db: AsyncSession = Depends(get_db)):
    token_hash = hash_refresh_token(body.refresh_token)
    result = await db.execute(
        select(RefreshToken).where(
            RefreshToken.token_hash == token_hash,
            RefreshToken.is_revoked == False,
        )
    )
    rt = result.scalar_one_or_none()

    if not rt or rt.expires_at.replace(tzinfo=timezone.utc) < datetime.now(timezone.utc):
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")

    # Revoke old token (rotation)
    rt.is_revoked = True

    user_result = await db.execute(select(User).where(User.id == rt.user_id, User.is_active == True))
    user = user_result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    access_token = create_access_token(str(user.id))
    raw_refresh, refresh_hash, expires_at = create_refresh_token()
    new_rt = RefreshToken(user_id=user.id, token_hash=refresh_hash, expires_at=expires_at)
    db.add(new_rt)
    await db.commit()

    return TokenPair(
        access_token=access_token,
        refresh_token=raw_refresh,
        user=UserOut.model_validate(user),
    )


@router.post("/logout", status_code=204)
async def logout(body: RefreshRequest, db: AsyncSession = Depends(get_db)):
    token_hash = hash_refresh_token(body.refresh_token)
    result = await db.execute(select(RefreshToken).where(RefreshToken.token_hash == token_hash))
    rt = result.scalar_one_or_none()
    if rt:
        rt.is_revoked = True
        await db.commit()


@router.get("/me", response_model=UserOut)
async def get_me(current_user: User = Depends(get_current_user)):
    return current_user


@router.patch("/me", response_model=UserOut)
async def update_profile(
    body: UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    for field, value in body.model_dump(exclude_none=True).items():
        setattr(current_user, field, value)
    await db.commit()
    await db.refresh(current_user)
    return current_user


@router.post("/change-password", status_code=204)
async def change_password(
    body: ChangePasswordRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not verify_password(body.current_password, current_user.password_hash):
        raise HTTPException(status_code=400, detail="Current password is incorrect")
    current_user.password_hash = hash_password(body.new_password)
    await db.commit()


@router.post("/forgot-password")
async def forgot_password(body: ForgotPasswordRequest, db: AsyncSession = Depends(get_db)):
    """
    Generate a 6-digit reset code for the given email.
    If SMTP is configured → sends the code by email and does NOT return it in the response.
    If SMTP is NOT configured → returns the code in the response (shown on screen).
    Always returns 200 to prevent email enumeration.
    """
    import random
    from datetime import timedelta

    result = await db.execute(select(User).where(User.email == body.email, User.is_active == True))
    user = result.scalar_one_or_none()

    if not user:
        # Prevent email enumeration — respond as if success
        return {"message": "إذا كان البريد الإلكتروني مسجلاً، ستصل رسالة التحقق قريباً.", "email_sent": False, "reset_code": None}

    # Generate 6-digit numeric code
    code = f"{random.randint(100000, 999999)}"

    # Store bcrypt-hashed in DB
    user.reset_token_hash = hash_password(code)
    user.reset_token_expires_at = datetime.now(timezone.utc) + timedelta(minutes=15)
    await db.commit()

    # Try sending email
    email_sent = await send_reset_email(body.email, code)

    log = logging.getLogger("masareefi")
    if email_sent:
        log.info("Reset email sent to %s", body.email)
        return {
            "message": "تم إرسال رمز التحقق إلى بريدك الإلكتروني. صالح لمدة 15 دقيقة.",
            "email_sent": True,
            "reset_code": None,  # never expose in response when email was sent
        }
    else:
        # No SMTP configured: show code on screen
        log.warning("SMTP not configured — returning reset code in response for %s", body.email)
        return {
            "message": "تم إنشاء رمز التحقق. صالح لمدة 15 دقيقة.",
            "email_sent": False,
            "reset_code": code,
        }


@router.post("/reset-password", status_code=204)
async def reset_password(body: ResetPasswordRequest, db: AsyncSession = Depends(get_db)):
    """Validate reset code and set the new password."""
    result = await db.execute(select(User).where(User.email == body.email, User.is_active == True))
    user = result.scalar_one_or_none()

    if not user or not user.reset_token_hash or not user.reset_token_expires_at:
        raise HTTPException(status_code=400, detail="رمز التحقق غير صحيح أو منتهي الصلاحية")

    if user.reset_token_expires_at.replace(tzinfo=timezone.utc) < datetime.now(timezone.utc):
        raise HTTPException(status_code=400, detail="انتهت صلاحية رمز التحقق. يرجى طلب رمز جديد")

    if not verify_password(body.reset_code, user.reset_token_hash):
        raise HTTPException(status_code=400, detail="رمز التحقق غير صحيح")

    user.password_hash = hash_password(body.new_password)
    user.reset_token_hash = None
    user.reset_token_expires_at = None
    await db.commit()


@router.get("/referral-info")
async def get_referral_info(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return the current user's referral code, link and reward stats.
    Auto-generates a referral code for existing users who don't have one.
    """
    # Auto-generate referral code for legacy users who registered before this feature
    if not current_user.referral_code:
        current_user.referral_code = secrets.token_urlsafe(6).upper()
        await db.commit()
        await db.refresh(current_user)

    ref_code = current_user.referral_code
    # Build app URL from the actual request origin so it works on any deployment
    base = str(request.base_url).rstrip("/")
    referral_link = f"{base}/?ref={ref_code}"
    return {
        "referral_code": ref_code,
        "referral_link": referral_link,
        "referral_count": current_user.referral_count or 0,
        "referral_bonus_days": current_user.referral_bonus_days or 0,
    }


# ─── Helper ───────────────────────────────────────────────────────────────────

SYSTEM_CATEGORIES = [
    {"name_ar": "طعام", "name_en": "Food", "icon": "🍔", "color": "#FF9800"},
    {"name_ar": "مواصلات", "name_en": "Transport", "icon": "🚗", "color": "#2196F3"},
    {"name_ar": "تسوق", "name_en": "Shopping", "icon": "🛍️", "color": "#E91E63"},
    {"name_ar": "صحة", "name_en": "Health", "icon": "🏥", "color": "#4CAF50"},
    {"name_ar": "ترفيه", "name_en": "Entertainment", "icon": "🎮", "color": "#9C27B0"},
    {"name_ar": "تعليم", "name_en": "Education", "icon": "📚", "color": "#00BCD4"},
    {"name_ar": "فواتير", "name_en": "Bills", "icon": "💡", "color": "#FF5722"},
    {"name_ar": "سكن", "name_en": "Housing", "icon": "🏠", "color": "#795548"},
    {"name_ar": "أخرى", "name_en": "Other", "icon": "➕", "color": "#9E9E9E"},
]


async def _seed_system_categories(db: AsyncSession, user_id: uuid.UUID):
    from app.models.category import Category
    for i, cat in enumerate(SYSTEM_CATEGORIES):
        c = Category(
            user_id=user_id,
            name_ar=cat["name_ar"],
            name_en=cat["name_en"],
            icon=cat["icon"],
            color=cat["color"],
            is_system=True,
            sort_order=i,
        )
        db.add(c)


_DEFAULT_WALLETS = [
    {"name": "فلوس تحت اليد",  "wallet_type": "cash",       "icon": "💰", "color": "#FF9800", "is_default": True},
    {"name": "Zain Cash",       "wallet_type": "zaincash",   "icon": "📱", "color": "#7B1FA2", "is_default": False},
    {"name": "مصرف الرافدين",  "wallet_type": "mastercard", "icon": "💳", "color": "#1A237E", "is_default": False},
]


async def _seed_default_wallets(db: AsyncSession, user_id: uuid.UUID, currency: str = "IQD"):
    from app.models.wallet import Wallet
    for w in _DEFAULT_WALLETS:
        db.add(Wallet(user_id=user_id, currency=currency, **w))
