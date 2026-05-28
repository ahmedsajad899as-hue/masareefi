"""Market Sales router — create credit sales, list, mark as paid."""
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.market import MarketSale, MarketSaleItem, MarketCustomer, MarketAuditLog
from app.models.user import User
from app.schemas.market import (
    MarketSaleCreate,
    MarketSaleQuickCreate,
    MarketSaleUpdate,
    MarketSaleOut,
    MarketSaleItemOut,
    MarketAuditLogOut,
)
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


@router.post("/quick", response_model=MarketSaleOut, status_code=status.HTTP_201_CREATED)
async def create_quick_sale(
    body: MarketSaleQuickCreate,
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    """Cash register endpoint — optional customer, is_paid defaults True (cash)."""
    if not body.items:
        raise HTTPException(status_code=400, detail="At least one item is required")

    # Resolve customer: use provided or auto-create walk-in placeholder
    customer_id = body.customer_id
    if customer_id:
        cust_result = await db.execute(
            select(MarketCustomer).where(
                MarketCustomer.id == customer_id,
                MarketCustomer.market_owner_id == current_user.id,
            )
        )
        if not cust_result.scalar_one_or_none():
            raise HTTPException(status_code=404, detail="Customer not found")
    else:
        walkin_result = await db.execute(
            select(MarketCustomer).where(
                MarketCustomer.market_owner_id == current_user.id,
                MarketCustomer.name == "زبون عابر",
            ).limit(1)
        )
        walkin = walkin_result.scalar_one_or_none()
        if not walkin:
            walkin = MarketCustomer(
                market_owner_id=current_user.id,
                name="زبون عابر",
                notes="حساب تلقائي للمبيعات النقدية",
            )
            db.add(walkin)
            await db.flush()
        customer_id = walkin.id

    now = datetime.now(timezone.utc)
    total = sum(round(i.quantity * i.unit_price, 2) for i in body.items)

    sale = MarketSale(
        market_owner_id=current_user.id,
        customer_id=customer_id,
        sale_date=now,
        notes=body.notes,
        total_amount=total,
        is_paid=body.is_paid,
        paid_at=now if body.is_paid else None,
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

    changes: list[dict] = []

    if body.notes is not None and (body.notes or None) != (sale.notes or None):
        changes.append({"field": "notes", "old": sale.notes, "new": body.notes})
        sale.notes = body.notes

    if body.sale_date is not None and body.sale_date != sale.sale_date:
        changes.append({
            "field": "sale_date",
            "old": sale.sale_date.isoformat() if sale.sale_date else None,
            "new": body.sale_date.isoformat(),
        })
        sale.sale_date = body.sale_date

    if body.is_paid is not None and body.is_paid != sale.is_paid:
        changes.append({"field": "is_paid", "old": sale.is_paid, "new": body.is_paid})
        sale.is_paid = body.is_paid
        if body.is_paid and not sale.paid_at:
            sale.paid_at = datetime.now(timezone.utc)
        if not body.is_paid:
            sale.paid_at = None

    if body.items is not None:
        if not body.items:
            raise HTTPException(status_code=400, detail="At least one item is required")
        old_items = [
            {"product_name": i.product_name, "quantity": float(i.quantity), "unit_price": float(i.unit_price)}
            for i in sale.items
        ]
        new_items = [
            {"product_name": i.product_name, "quantity": float(i.quantity), "unit_price": float(i.unit_price)}
            for i in body.items
        ]
        if old_items != new_items:
            changes.append({"field": "items", "old": old_items, "new": new_items})
            # Replace items
            for it in list(sale.items):
                await db.delete(it)
            await db.flush()
            for it in body.items:
                db.add(MarketSaleItem(
                    sale_id=sale.id,
                    product_name=it.product_name,
                    quantity=it.quantity,
                    unit_price=it.unit_price,
                ))
            new_total = round(sum(i.quantity * i.unit_price for i in body.items), 2)
            if float(sale.total_amount) != new_total:
                changes.append({"field": "total_amount", "old": float(sale.total_amount), "new": new_total})
            sale.total_amount = new_total

    if changes:
        db.add(MarketAuditLog(
            market_owner_id=current_user.id,
            entity_type="sale",
            entity_id=sale.id,
            customer_id=sale.customer_id,
            action="update",
            changes=changes,
        ))

    await db.commit()
    result = await db.execute(
        select(MarketSale)
        .options(selectinload(MarketSale.items), selectinload(MarketSale.customer))
        .where(MarketSale.id == sale.id)
    )
    sale = result.scalar_one()
    return _build_sale_out(sale)


@router.get("/{sale_id}/history", response_model=list[MarketAuditLogOut])
async def list_sale_history(
    sale_id: uuid.UUID,
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    """Return audit-log entries for a specific sale."""
    result = await db.execute(
        select(MarketSale.id, MarketSale.customer_id).where(
            MarketSale.id == sale_id,
            MarketSale.market_owner_id == current_user.id,
        )
    )
    row = result.one_or_none()
    if not row:
        raise HTTPException(status_code=404, detail="Sale not found")

    logs_result = await db.execute(
        select(MarketAuditLog)
        .where(
            MarketAuditLog.market_owner_id == current_user.id,
            MarketAuditLog.entity_type == "sale",
            MarketAuditLog.entity_id == sale_id,
        )
        .order_by(MarketAuditLog.created_at.desc())
    )
    return logs_result.scalars().all()


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
