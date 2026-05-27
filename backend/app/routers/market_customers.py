"""Market Customers router — CRUD + search + overdue list."""
import uuid
from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.market import MarketCustomer, MarketSale
from app.models.user import User
from app.schemas.market import MarketCustomerCreate, MarketCustomerUpdate, MarketCustomerOut
from app.utils.dependencies import get_current_market_owner

router = APIRouter()


async def _enrich_customer(customer: MarketCustomer, db: AsyncSession) -> MarketCustomerOut:
    """Compute total_debt and unpaid_sales_count for a customer."""
    result = await db.execute(
        select(
            func.count(MarketSale.id).label("cnt"),
            func.coalesce(func.sum(MarketSale.total_amount), 0).label("total")
        ).where(
            MarketSale.customer_id == customer.id,
            MarketSale.is_paid == False
        )
    )
    row = result.one()
    out = MarketCustomerOut.model_validate(customer)
    out.unpaid_sales_count = int(row.cnt or 0)
    out.total_debt = float(row.total or 0)
    return out


@router.get("/", response_model=list[MarketCustomerOut])
async def list_customers(
    q: str | None = Query(None, description="Search by name or phone"),
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(MarketCustomer).where(MarketCustomer.market_owner_id == current_user.id)
    if q:
        like = f"%{q}%"
        stmt = stmt.where(
            (MarketCustomer.name.ilike(like)) | (MarketCustomer.phone.ilike(like))
        )
    stmt = stmt.order_by(MarketCustomer.created_at.desc())
    result = await db.execute(stmt)
    customers = result.scalars().all()
    return [await _enrich_customer(c, db) for c in customers]


@router.post("/", response_model=MarketCustomerOut, status_code=status.HTTP_201_CREATED)
async def create_customer(
    body: MarketCustomerCreate,
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    customer = MarketCustomer(
        market_owner_id=current_user.id,
        name=body.name,
        phone=body.phone,
        notes=body.notes,
    )
    # Auto-link if phone matches a registered user
    if body.phone:
        user_result = await db.execute(
            select(User).where(User.phone_number == body.phone, User.is_active == True)
        )
        linked = user_result.scalar_one_or_none()
        if linked:
            customer.linked_user_id = linked.id

    db.add(customer)
    await db.commit()
    await db.refresh(customer)
    return await _enrich_customer(customer, db)


@router.get("/overdue", response_model=list[MarketCustomerOut])
async def list_overdue_customers(
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    """Return customers who have unpaid sales older than market_overdue_days."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=current_user.market_overdue_days)
    # Customers that have at least one unpaid sale older than cutoff
    subq = (
        select(MarketSale.customer_id)
        .where(
            MarketSale.market_owner_id == current_user.id,
            MarketSale.is_paid == False,
            MarketSale.sale_date <= cutoff,
        )
        .distinct()
    )
    stmt = select(MarketCustomer).where(
        MarketCustomer.market_owner_id == current_user.id,
        MarketCustomer.id.in_(subq),
    )
    result = await db.execute(stmt)
    customers = result.scalars().all()
    return [await _enrich_customer(c, db) for c in customers]


@router.get("/{customer_id}", response_model=MarketCustomerOut)
async def get_customer(
    customer_id: uuid.UUID,
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(MarketCustomer).where(
            MarketCustomer.id == customer_id,
            MarketCustomer.market_owner_id == current_user.id,
        )
    )
    customer = result.scalar_one_or_none()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    return await _enrich_customer(customer, db)


@router.patch("/{customer_id}", response_model=MarketCustomerOut)
async def update_customer(
    customer_id: uuid.UUID,
    body: MarketCustomerUpdate,
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(MarketCustomer).where(
            MarketCustomer.id == customer_id,
            MarketCustomer.market_owner_id == current_user.id,
        )
    )
    customer = result.scalar_one_or_none()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")

    if body.name is not None:
        customer.name = body.name
    if body.notes is not None:
        customer.notes = body.notes
    if body.phone is not None:
        customer.phone = body.phone
        # Re-link if phone changed
        user_result = await db.execute(
            select(User).where(User.phone_number == body.phone, User.is_active == True)
        )
        linked = user_result.scalar_one_or_none()
        customer.linked_user_id = linked.id if linked else None

    await db.commit()
    await db.refresh(customer)
    return await _enrich_customer(customer, db)


@router.delete("/{customer_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_customer(
    customer_id: uuid.UUID,
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(MarketCustomer).where(
            MarketCustomer.id == customer_id,
            MarketCustomer.market_owner_id == current_user.id,
        )
    )
    customer = result.scalar_one_or_none()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    await db.delete(customer)
    await db.commit()
