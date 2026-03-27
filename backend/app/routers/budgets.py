import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, extract, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.budget import Budget
from app.models.expense import Expense
from app.models.goal import Goal
from app.models.user import User
from app.schemas.budget import BudgetCreate, BudgetUpdate, BudgetOut, GoalCreate, GoalUpdate, GoalOut
from app.utils.dependencies import get_current_user

router = APIRouter()


# ─── Budgets ──────────────────────────────────────────────────────────────────

@router.get("", response_model=list[BudgetOut])
async def list_budgets(
    year: int = date.today().year,
    month: int = date.today().month,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Budget)
        .options(selectinload(Budget.category))
        .where(Budget.user_id == current_user.id, Budget.year == year, Budget.month == month)
    )
    budgets = result.scalars().all()

    # Fetch spent amounts per category for this month
    spent_result = await db.execute(
        select(Expense.category_id, func.sum(Expense.amount).label("spent"))
        .where(
            Expense.user_id == current_user.id,
            extract("year", Expense.expense_date) == year,
            extract("month", Expense.expense_date) == month,
        )
        .group_by(Expense.category_id)
    )
    spent_map: dict[uuid.UUID | None, float] = {row.category_id: float(row.spent) for row in spent_result}

    output = []
    for b in budgets:
        spent = spent_map.get(b.category_id, 0.0)
        remaining = max(float(b.amount) - spent, 0.0)
        percentage = round(spent / float(b.amount) * 100, 1) if float(b.amount) > 0 else 0.0
        out = BudgetOut.model_validate(b)
        out.spent = spent
        out.remaining = remaining
        out.percentage = percentage
        output.append(out)
    return output


@router.post("", response_model=BudgetOut, status_code=status.HTTP_201_CREATED)
async def create_budget(
    body: BudgetCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    budget = Budget(**body.model_dump(), user_id=current_user.id)
    db.add(budget)
    try:
        await db.commit()
    except Exception:
        await db.rollback()
        raise HTTPException(status_code=400, detail="Budget for this category/month already exists")
    await db.refresh(budget)
    result = await db.execute(
        select(Budget).options(selectinload(Budget.category)).where(Budget.id == budget.id)
    )
    b = result.scalar_one()
    out = BudgetOut.model_validate(b)
    out.spent = 0.0
    out.remaining = float(b.amount)
    out.percentage = 0.0
    return out


@router.patch("/{budget_id}", response_model=BudgetOut)
async def update_budget(
    budget_id: uuid.UUID,
    body: BudgetUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Budget).where(Budget.id == budget_id, Budget.user_id == current_user.id)
    )
    budget = result.scalar_one_or_none()
    if not budget:
        raise HTTPException(status_code=404, detail="Budget not found")
    for field, value in body.model_dump(exclude_none=True).items():
        setattr(budget, field, value)
    await db.commit()
    result = await db.execute(
        select(Budget).options(selectinload(Budget.category)).where(Budget.id == budget.id)
    )
    b = result.scalar_one()
    out = BudgetOut.model_validate(b)
    out.spent = 0.0
    out.remaining = float(b.amount)
    out.percentage = 0.0
    return out


@router.delete("/{budget_id}", status_code=204)
async def delete_budget(
    budget_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Budget).where(Budget.id == budget_id, Budget.user_id == current_user.id)
    )
    budget = result.scalar_one_or_none()
    if not budget:
        raise HTTPException(status_code=404, detail="Budget not found")
    await db.delete(budget)
    await db.commit()


# ─── Goals ────────────────────────────────────────────────────────────────────

@router.get("/goals", response_model=list[GoalOut])
async def list_goals(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Goal).where(Goal.user_id == current_user.id).order_by(Goal.created_at.desc()))
    goals = result.scalars().all()
    output = []
    for g in goals:
        out = GoalOut.model_validate(g)
        out.progress_percentage = round(float(g.current_amount) / float(g.target_amount) * 100, 1) if float(g.target_amount) > 0 else 0.0
        out.deadline = g.deadline.isoformat() if g.deadline else None
        output.append(out)
    return output


@router.post("/goals", response_model=GoalOut, status_code=status.HTTP_201_CREATED)
async def create_goal(
    body: GoalCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    from datetime import date as date_type
    deadline = date_type.fromisoformat(body.deadline) if body.deadline else None
    goal = Goal(
        user_id=current_user.id,
        title=body.title,
        description=body.description,
        target_amount=body.target_amount,
        current_amount=body.current_amount,
        deadline=deadline,
        currency=body.currency,
    )
    db.add(goal)
    await db.commit()
    await db.refresh(goal)
    out = GoalOut.model_validate(goal)
    out.progress_percentage = 0.0
    out.deadline = goal.deadline.isoformat() if goal.deadline else None
    return out


@router.patch("/goals/{goal_id}", response_model=GoalOut)
async def update_goal(
    goal_id: uuid.UUID,
    body: GoalUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Goal).where(Goal.id == goal_id, Goal.user_id == current_user.id))
    goal = result.scalar_one_or_none()
    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")
    data = body.model_dump(exclude_none=True)
    if "deadline" in data and data["deadline"]:
        from datetime import date as date_type
        data["deadline"] = date_type.fromisoformat(data["deadline"])
    for field, value in data.items():
        setattr(goal, field, value)
    await db.commit()
    await db.refresh(goal)
    out = GoalOut.model_validate(goal)
    out.progress_percentage = round(float(goal.current_amount) / float(goal.target_amount) * 100, 1) if float(goal.target_amount) > 0 else 0.0
    out.deadline = goal.deadline.isoformat() if goal.deadline else None
    return out


@router.delete("/goals/{goal_id}", status_code=204)
async def delete_goal(
    goal_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Goal).where(Goal.id == goal_id, Goal.user_id == current_user.id))
    goal = result.scalar_one_or_none()
    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")
    await db.delete(goal)
    await db.commit()
