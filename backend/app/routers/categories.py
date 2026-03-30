import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, or_, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.category import Category
from app.models.user import User
from app.schemas.category import CategoryCreate, CategoryUpdate, CategoryOut
from app.utils.dependencies import get_current_user, check_plan_limit

router = APIRouter()


@router.get("", response_model=list[CategoryOut])
async def list_categories(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Lists system categories for the user + any custom categories they created."""
    result = await db.execute(
        select(Category)
        .where(Category.user_id == current_user.id)
        .order_by(Category.sort_order, Category.created_at)
    )
    return result.scalars().all()


@router.post("", response_model=CategoryOut, status_code=status.HTTP_201_CREATED)
async def create_category(
    body: CategoryCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Plan limit: custom (non-system) category count
    count_result = await db.execute(
        select(func.count()).select_from(Category).where(
            Category.user_id == current_user.id,
            Category.is_system == False,  # noqa: E712
        )
    )
    custom_count = count_result.scalar_one()
    check_plan_limit(custom_count, current_user, "custom_categories")

    cat = Category(**body.model_dump(), user_id=current_user.id, is_system=False)
    db.add(cat)
    await db.commit()
    await db.refresh(cat)
    return cat


@router.patch("/{category_id}", response_model=CategoryOut)
async def update_category(
    category_id: uuid.UUID,
    body: CategoryUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Category).where(Category.id == category_id, Category.user_id == current_user.id)
    )
    cat = result.scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    if cat.is_system:
        raise HTTPException(status_code=403, detail="Cannot modify system categories")

    for field, value in body.model_dump(exclude_none=True).items():
        setattr(cat, field, value)
    await db.commit()
    await db.refresh(cat)
    return cat


@router.delete("/{category_id}", status_code=204)
async def delete_category(
    category_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Category).where(Category.id == category_id, Category.user_id == current_user.id)
    )
    cat = result.scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    if cat.is_system:
        raise HTTPException(status_code=403, detail="Cannot delete system categories")
    await db.delete(cat)
    await db.commit()
