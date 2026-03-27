import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.user import User, RefreshToken
from app.schemas.user import UserRegister, UserLogin, UserOut, TokenPair, RefreshRequest, UserUpdate, ChangePasswordRequest
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
        preferred_language=body.preferred_language,
        currency=body.currency,
    )
    db.add(user)
    await db.flush()  # get user.id before commit

    # Seed system categories for new user
    await _seed_system_categories(db, user.id)

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
