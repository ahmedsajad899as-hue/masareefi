"""Market Settings router — get/update store name and overdue threshold."""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.user import User
from app.schemas.market import MarketSettingsOut, MarketSettingsUpdate
from app.utils.dependencies import get_current_market_owner

router = APIRouter()


@router.get("/", response_model=MarketSettingsOut)
async def get_market_settings(
    current_user: User = Depends(get_current_market_owner),
):
    return MarketSettingsOut(
        store_name=current_user.store_name,
        market_overdue_days=current_user.market_overdue_days,
    )


@router.patch("/", response_model=MarketSettingsOut)
async def update_market_settings(
    body: MarketSettingsUpdate,
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    if body.store_name is not None:
        current_user.store_name = body.store_name.strip() or current_user.store_name
    if body.market_overdue_days is not None:
        if body.market_overdue_days < 1:
            body.market_overdue_days = 1
        current_user.market_overdue_days = body.market_overdue_days
    await db.commit()
    await db.refresh(current_user)
    return MarketSettingsOut(
        store_name=current_user.store_name,
        market_overdue_days=current_user.market_overdue_days,
    )
