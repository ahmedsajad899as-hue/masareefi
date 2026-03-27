import uuid

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
    preferred_language: str = "ar"
    currency: str = "IQD"
    is_admin: bool = False


class AdminUpdateUser(BaseModel):
    full_name: str | None = None
    preferred_language: str | None = None
    currency: str | None = None
    is_active: bool | None = None
    is_admin: bool | None = None
    password: str | None = None


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
        preferred_language=body.preferred_language,
        currency=body.currency,
        is_admin=body.is_admin,
    )
    db.add(user)

    # Seed system categories for new user
    from app.routers.auth import _seed_system_categories
    await db.flush()
    await _seed_system_categories(db, user.id)

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
