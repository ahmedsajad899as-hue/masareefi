from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.user import User
from app.services import (
    get_daily_summary,
    get_monthly_summary,
    get_category_breakdown,
    get_daily_trend,
    get_monthly_comparison,
    get_monthly_stats_for_insights,
    generate_spending_insights,
)
from app.utils.dependencies import get_current_user

router = APIRouter()


@router.get("/daily")
async def daily_summary(
    target_date: date = Query(default_factory=date.today),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await get_daily_summary(db, current_user.id, target_date)


@router.get("/monthly")
async def monthly_summary(
    year: int = Query(default_factory=lambda: date.today().year),
    month: int = Query(default_factory=lambda: date.today().month),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await get_monthly_summary(db, current_user.id, year, month)


@router.get("/categories")
async def category_breakdown(
    year: int = Query(default_factory=lambda: date.today().year),
    month: int = Query(default_factory=lambda: date.today().month),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await get_category_breakdown(db, current_user.id, year, month)


@router.get("/trend")
async def daily_trend(
    year: int = Query(default_factory=lambda: date.today().year),
    month: int = Query(default_factory=lambda: date.today().month),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await get_daily_trend(db, current_user.id, year, month)


@router.get("/comparison")
async def monthly_comparison(
    months: int = Query(6, ge=2, le=24),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await get_monthly_comparison(db, current_user.id, months)


@router.get("/insights")
async def spending_insights(
    year: int = Query(default_factory=lambda: date.today().year),
    month: int = Query(default_factory=lambda: date.today().month),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    summary = await get_monthly_stats_for_insights(db, current_user.id, year, month)
    tips = await generate_spending_insights(summary)
    return {"tips": tips, "summary": summary}
