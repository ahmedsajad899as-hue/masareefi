"""Market Sales router — create credit sales, list, mark as paid."""
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.market import MarketSale, MarketSaleItem, MarketCustomer
from app.models.user import User
from app.schemas.market import MarketSaleCreate, MarketSaleUpdate, MarketSaleOut, MarketSaleItemOut
from app.utils.dependencies import get_current_market_owner

router = APIRouter()


def _build_sale_out(sale: MarketSale) -> MarketSaleOut:
    out = MarketSaleOut.model_validate(sale)
    out.customer_name = sale.customer.name if sale.customer else ""
    out.items = [MarketSaleItemOut.model_validate(i) for i in sale.items]
    return out


@router.get("/", response_model=list[MarketSaleOut])
async def list_sales(
    customer_id: uuid.UUID | None = Query(None),
    is_paid: bool | None = Query(None),
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(MarketSale)
        .options(selectinload(MarketSale.items), selectinload(MarketSale.customer))
        .where(MarketSale.market_owner_id == current_user.id)
    )
    if customer_id:
        stmt = stmt.where(MarketSale.customer_id == customer_id)
    if is_paid is not None:
        stmt = stmt.where(MarketSale.is_paid == is_paid)
    stmt = stmt.order_by(MarketSale.sale_date.desc())
    result = await db.execute(stmt)
    return [_build_sale_out(s) for s in result.scalars().all()]


@router.post("/", response_model=MarketSaleOut, status_code=status.HTTP_201_CREATED)
async def create_sale(
    body: MarketSaleCreate,
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    # Validate customer belongs to this market owner
    cust_result = await db.execute(
        select(MarketCustomer).where(
            MarketCustomer.id == body.customer_id,
            MarketCustomer.market_owner_id == current_user.id,
        )
    )
    customer = cust_result.scalar_one_or_none()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")

    if not body.items:
        raise HTTPException(status_code=400, detail="At least one item is required")

    # Compute total
    total = sum(round(i.quantity * i.unit_price, 2) for i in body.items)

    sale = MarketSale(
        market_owner_id=current_user.id,
        customer_id=body.customer_id,
        sale_date=body.sale_date,
        notes=body.notes,
        total_amount=total,
        is_paid=False,
    )
    db.add(sale)
    await db.flush()

    for item_data in body.items:
        db.add(MarketSaleItem(
            sale_id=sale.id,
            product_name=item_data.product_name,
            quantity=item_data.quantity,
            unit_price=item_data.unit_price,
        ))

    await db.commit()

    # Reload with relationships
    result = await db.execute(
        select(MarketSale)
        .options(selectinload(MarketSale.items), selectinload(MarketSale.customer))
        .where(MarketSale.id == sale.id)
    )
    sale = result.scalar_one()
    return _build_sale_out(sale)


@router.get("/{sale_id}", response_model=MarketSaleOut)
async def get_sale(
    sale_id: uuid.UUID,
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(MarketSale)
        .options(selectinload(MarketSale.items), selectinload(MarketSale.customer))
        .where(MarketSale.id == sale_id, MarketSale.market_owner_id == current_user.id)
    )
    sale = result.scalar_one_or_none()
    if not sale:
        raise HTTPException(status_code=404, detail="Sale not found")
    return _build_sale_out(sale)


@router.patch("/{sale_id}/pay", response_model=MarketSaleOut)
async def mark_sale_paid(
    sale_id: uuid.UUID,
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(MarketSale)
        .options(selectinload(MarketSale.items), selectinload(MarketSale.customer))
        .where(MarketSale.id == sale_id, MarketSale.market_owner_id == current_user.id)
    )
    sale = result.scalar_one_or_none()
    if not sale:
        raise HTTPException(status_code=404, detail="Sale not found")
    sale.is_paid = True
    sale.paid_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(sale)
    # Reload relationships after refresh
    result = await db.execute(
        select(MarketSale)
        .options(selectinload(MarketSale.items), selectinload(MarketSale.customer))
        .where(MarketSale.id == sale.id)
    )
    sale = result.scalar_one()
    return _build_sale_out(sale)


@router.patch("/{sale_id}", response_model=MarketSaleOut)
async def update_sale(
    sale_id: uuid.UUID,
    body: MarketSaleUpdate,
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(MarketSale)
        .options(selectinload(MarketSale.items), selectinload(MarketSale.customer))
        .where(MarketSale.id == sale_id, MarketSale.market_owner_id == current_user.id)
    )
    sale = result.scalar_one_or_none()
    if not sale:
        raise HTTPException(status_code=404, detail="Sale not found")
    if body.notes is not None:
        sale.notes = body.notes
    if body.is_paid is not None:
        sale.is_paid = body.is_paid
        if body.is_paid and not sale.paid_at:
            sale.paid_at = datetime.now(timezone.utc)
    await db.commit()
    result = await db.execute(
        select(MarketSale)
        .options(selectinload(MarketSale.items), selectinload(MarketSale.customer))
        .where(MarketSale.id == sale.id)
    )
    sale = result.scalar_one()
    return _build_sale_out(sale)


@router.delete("/{sale_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_sale(
    sale_id: uuid.UUID,
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(MarketSale).where(
            MarketSale.id == sale_id, MarketSale.market_owner_id == current_user.id
        )
    )
    sale = result.scalar_one_or_none()
    if not sale:
        raise HTTPException(status_code=404, detail="Sale not found")
    await db.delete(sale)
    await db.commit()
