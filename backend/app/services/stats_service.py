"""
Statistics service — aggregations and analytics for expenses.
"""
import uuid
from datetime import date

from sqlalchemy import select, func, extract
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.expense import Expense
from app.models.category import Category


async def get_daily_summary(db: AsyncSession, user_id: uuid.UUID, target_date: date) -> dict:
    result = await db.execute(
        select(
            func.count(Expense.id).label("count"),
            func.coalesce(func.sum(Expense.amount), 0).label("total"),
        ).where(Expense.user_id == user_id, Expense.expense_date == target_date)
    )
    row = result.one()
    return {"date": target_date.isoformat(), "total": float(row.total), "count": int(row.count)}


async def get_monthly_summary(db: AsyncSession, user_id: uuid.UUID, year: int, month: int) -> dict:
    result = await db.execute(
        select(
            func.coalesce(func.sum(Expense.amount), 0).label("total"),
            func.count(Expense.id).label("count"),
        ).where(
            Expense.user_id == user_id,
            extract("year", Expense.expense_date) == year,
            extract("month", Expense.expense_date) == month,
        )
    )
    row = result.one()
    return {"year": year, "month": month, "total": float(row.total), "count": int(row.count)}


async def get_category_breakdown(
    db: AsyncSession, user_id: uuid.UUID, year: int, month: int
) -> list[dict]:
    result = await db.execute(
        select(
            Category.id,
            Category.name_ar,
            Category.name_en,
            Category.icon,
            Category.color,
            func.coalesce(func.sum(Expense.amount), 0).label("total"),
            func.count(Expense.id).label("count"),
        )
        .join(Expense, Expense.category_id == Category.id, isouter=True)
        .where(
            Expense.user_id == user_id,
            extract("year", Expense.expense_date) == year,
            extract("month", Expense.expense_date) == month,
        )
        .group_by(Category.id, Category.name_ar, Category.name_en, Category.icon, Category.color)
        .order_by(func.sum(Expense.amount).desc())
    )
    rows = result.all()
    grand_total = sum(float(r.total) for r in rows)
    return [
        {
            "category_id": str(r.id),
            "name_ar": r.name_ar,
            "name_en": r.name_en,
            "icon": r.icon,
            "color": r.color,
            "total": float(r.total),
            "count": int(r.count),
            "percentage": round((float(r.total) / grand_total * 100) if grand_total > 0 else 0, 1),
        }
        for r in rows
    ]


async def get_daily_trend(
    db: AsyncSession, user_id: uuid.UUID, year: int, month: int
) -> list[dict]:
    result = await db.execute(
        select(
            Expense.expense_date,
            func.coalesce(func.sum(Expense.amount), 0).label("total"),
            func.count(Expense.id).label("count"),
        )
        .where(
            Expense.user_id == user_id,
            extract("year", Expense.expense_date) == year,
            extract("month", Expense.expense_date) == month,
        )
        .group_by(Expense.expense_date)
        .order_by(Expense.expense_date)
    )
    rows = result.all()
    return [
        {"date": r.expense_date.isoformat(), "total": float(r.total), "count": int(r.count)}
        for r in rows
    ]


async def get_monthly_comparison(
    db: AsyncSession, user_id: uuid.UUID, months: int = 6
) -> list[dict]:
    """Last N months totals."""
    result = await db.execute(
        select(
            extract("year", Expense.expense_date).label("year"),
            extract("month", Expense.expense_date).label("month"),
            func.coalesce(func.sum(Expense.amount), 0).label("total"),
        )
        .where(Expense.user_id == user_id)
        .group_by("year", "month")
        .order_by("year", "month")
        .limit(months)
    )
    rows = result.all()
    return [
        {"year": int(r.year), "month": int(r.month), "total": float(r.total)}
        for r in rows
    ]


async def get_monthly_stats_for_insights(db: AsyncSession, user_id: uuid.UUID, year: int, month: int) -> dict:
    """Assemble full summary dict for GPT insights."""
    monthly = await get_monthly_summary(db, user_id, year, month)
    by_category = await get_category_breakdown(db, user_id, year, month)
    return {
        "total": monthly["total"],
        "count": monthly["count"],
        "year": year,
        "month": month,
        "categories": [
            {"name": c["name_ar"], "total": c["total"], "percentage": c["percentage"]}
            for c in by_category
        ],
    }
