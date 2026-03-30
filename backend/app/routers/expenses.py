import math
import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, func, extract
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.expense import Expense
from app.models.wallet import Wallet
from app.models.user import User
from app.schemas.expense import ExpenseCreate, ExpenseUpdate, ExpenseOut, ExpenseListResponse, BulkExpenseCreate
from app.utils.dependencies import get_current_user, check_plan_limit

router = APIRouter()


@router.post("", response_model=ExpenseOut, status_code=status.HTTP_201_CREATED)
async def create_expense(
    body: ExpenseCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Plan limit: daily expense count (exclude income entries)
    today = date.today()
    count_result = await db.execute(
        select(func.count()).select_from(Expense).where(
            Expense.user_id == current_user.id,
            Expense.expense_date == today,
            Expense.entry_type == "expense",
        )
    )
    daily_count = count_result.scalar_one()
    check_plan_limit(daily_count, current_user, "daily_expenses")

    expense = Expense(**body.model_dump(), user_id=current_user.id)
    db.add(expense)

    # Adjust wallet balance based on entry type
    if body.wallet_id:
        w_result = await db.execute(
            select(Wallet).where(Wallet.id == body.wallet_id, Wallet.user_id == current_user.id)
        )
        wallet = w_result.scalar_one_or_none()
        if wallet:
            if body.entry_type == "income":
                wallet.balance = float(wallet.balance) + body.amount
                wallet.total_income = float(wallet.total_income or 0) + body.amount
            else:
                wallet.balance = float(wallet.balance) - body.amount

    await db.commit()
    await db.refresh(expense)
    # reload with category and wallet
    result = await db.execute(
        select(Expense)
        .options(selectinload(Expense.category), selectinload(Expense.wallet))
        .where(Expense.id == expense.id)
    )
    return result.scalar_one()


@router.post("/bulk", response_model=list[ExpenseOut], status_code=status.HTTP_201_CREATED)
async def create_bulk_expenses(
    body: BulkExpenseCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Plan limit: daily expense count (exclude income entries)
    today = date.today()
    count_result = await db.execute(
        select(func.count()).select_from(Expense).where(
            Expense.user_id == current_user.id,
            Expense.expense_date == today,
            Expense.entry_type == "expense",
        )
    )
    daily_count = count_result.scalar_one()
    check_plan_limit(daily_count, current_user, "daily_expenses", extra=len(body.expenses))

    expenses = [Expense(**e.model_dump(), user_id=current_user.id) for e in body.expenses]
    db.add_all(expenses)

    # Adjust wallet balances based on entry type
    wallet_expense_totals: dict[str, float] = {}
    wallet_income_totals: dict[str, float] = {}
    for e in body.expenses:
        if e.wallet_id:
            wid = str(e.wallet_id)
            if e.entry_type == "income":
                wallet_income_totals[wid] = wallet_income_totals.get(wid, 0) + e.amount
            else:
                wallet_expense_totals[wid] = wallet_expense_totals.get(wid, 0) + e.amount
    all_wallet_ids = set(wallet_expense_totals) | set(wallet_income_totals)
    for wid in all_wallet_ids:
        w_result = await db.execute(
            select(Wallet).where(Wallet.id == uuid.UUID(wid), Wallet.user_id == current_user.id)
        )
        wallet = w_result.scalar_one_or_none()
        if wallet:
            wallet.balance = float(wallet.balance) - wallet_expense_totals.get(wid, 0) + wallet_income_totals.get(wid, 0)
            wallet.total_income = float(wallet.total_income or 0) + wallet_income_totals.get(wid, 0)

    await db.commit()
    ids = [e.id for e in expenses]
    result = await db.execute(
        select(Expense)
        .options(selectinload(Expense.category), selectinload(Expense.wallet))
        .where(Expense.id.in_(ids))
    )
    return result.scalars().all()


@router.get("", response_model=ExpenseListResponse)
async def list_expenses(
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    category_id: uuid.UUID | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = select(Expense).where(Expense.user_id == current_user.id)

    if category_id:
        query = query.where(Expense.category_id == category_id)
    if date_from:
        query = query.where(Expense.expense_date >= date_from)
    if date_to:
        query = query.where(Expense.expense_date <= date_to)

    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar_one()

    query = (
        query.options(selectinload(Expense.category), selectinload(Expense.wallet))
        .order_by(Expense.expense_date.desc(), Expense.created_at.desc())
        .offset((page - 1) * size)
        .limit(size)
    )
    result = await db.execute(query)
    items = result.scalars().all()

    return ExpenseListResponse(
        items=items,
        total=total,
        page=page,
        size=size,
        pages=math.ceil(total / size) if total > 0 else 1,
    )


@router.get("/{expense_id}", response_model=ExpenseOut)
async def get_expense(
    expense_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Expense)
        .options(selectinload(Expense.category), selectinload(Expense.wallet))
        .where(Expense.id == expense_id, Expense.user_id == current_user.id)
    )
    expense = result.scalar_one_or_none()
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")
    return expense


@router.patch("/{expense_id}", response_model=ExpenseOut)
async def update_expense(
    expense_id: uuid.UUID,
    body: ExpenseUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Expense).where(Expense.id == expense_id, Expense.user_id == current_user.id)
    )
    expense = result.scalar_one_or_none()
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")

    for field, value in body.model_dump(exclude_none=True).items():
        setattr(expense, field, value)
    await db.commit()

    result = await db.execute(
        select(Expense).options(selectinload(Expense.category), selectinload(Expense.wallet)).where(Expense.id == expense.id)
    )
    return result.scalar_one()


@router.delete("/{expense_id}", status_code=204)
async def delete_expense(
    expense_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Expense).where(Expense.id == expense_id, Expense.user_id == current_user.id)
    )
    expense = result.scalar_one_or_none()
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")

    # Reverse wallet effect based on entry type
    if expense.wallet_id:
        w_result = await db.execute(
            select(Wallet).where(Wallet.id == expense.wallet_id, Wallet.user_id == current_user.id)
        )
        wallet = w_result.scalar_one_or_none()
        if wallet:
            if expense.entry_type == "income":
                wallet.balance = float(wallet.balance) - float(expense.amount)
                wallet.total_income = max(0, float(wallet.total_income or 0) - float(expense.amount))
            else:
                wallet.balance = float(wallet.balance) + float(expense.amount)

    await db.delete(expense)
    await db.commit()
