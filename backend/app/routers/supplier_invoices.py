"""Supplier Invoices router — manage invoices from suppliers/warehouses."""
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.market import SupplierInvoice, SupplierInvoiceItem
from app.models.user import User
from app.schemas.market import (
    SupplierInvoiceCreate, SupplierInvoiceUpdate, SupplierInvoiceOut, SupplierInvoiceItemOut
)
from app.utils.dependencies import get_current_market_owner

router = APIRouter()


def _build_invoice_out(invoice: SupplierInvoice) -> SupplierInvoiceOut:
    out = SupplierInvoiceOut.model_validate(invoice)
    out.items = [SupplierInvoiceItemOut.model_validate(i) for i in invoice.items]
    return out


@router.get("/", response_model=list[SupplierInvoiceOut])
async def list_invoices(
    is_paid: bool | None = Query(None),
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(SupplierInvoice)
        .options(selectinload(SupplierInvoice.items))
        .where(SupplierInvoice.market_owner_id == current_user.id)
    )
    if is_paid is not None:
        stmt = stmt.where(SupplierInvoice.is_paid == is_paid)
    stmt = stmt.order_by(SupplierInvoice.invoice_date.desc())
    result = await db.execute(stmt)
    return [_build_invoice_out(inv) for inv in result.scalars().all()]


@router.post("/", response_model=SupplierInvoiceOut, status_code=status.HTTP_201_CREATED)
async def create_invoice(
    body: SupplierInvoiceCreate,
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    if not body.items:
        raise HTTPException(status_code=400, detail="At least one item is required")

    total = sum(round(i.quantity * i.unit_price, 2) for i in body.items)

    invoice = SupplierInvoice(
        market_owner_id=current_user.id,
        supplier_name=body.supplier_name,
        invoice_date=body.invoice_date,
        due_date=body.due_date,
        total_amount=total,
        notes=body.notes,
        is_paid=False,
    )
    db.add(invoice)
    await db.flush()

    for item_data in body.items:
        db.add(SupplierInvoiceItem(
            invoice_id=invoice.id,
            product_name=item_data.product_name,
            quantity=item_data.quantity,
            unit_price=item_data.unit_price,
        ))

    await db.commit()

    result = await db.execute(
        select(SupplierInvoice)
        .options(selectinload(SupplierInvoice.items))
        .where(SupplierInvoice.id == invoice.id)
    )
    invoice = result.scalar_one()
    return _build_invoice_out(invoice)


@router.get("/{invoice_id}", response_model=SupplierInvoiceOut)
async def get_invoice(
    invoice_id: uuid.UUID,
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(SupplierInvoice)
        .options(selectinload(SupplierInvoice.items))
        .where(SupplierInvoice.id == invoice_id, SupplierInvoice.market_owner_id == current_user.id)
    )
    invoice = result.scalar_one_or_none()
    if not invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")
    return _build_invoice_out(invoice)


@router.patch("/{invoice_id}/pay", response_model=SupplierInvoiceOut)
async def mark_invoice_paid(
    invoice_id: uuid.UUID,
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(SupplierInvoice)
        .options(selectinload(SupplierInvoice.items))
        .where(SupplierInvoice.id == invoice_id, SupplierInvoice.market_owner_id == current_user.id)
    )
    invoice = result.scalar_one_or_none()
    if not invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")
    invoice.is_paid = True
    invoice.paid_at = datetime.now(timezone.utc)
    await db.commit()
    result = await db.execute(
        select(SupplierInvoice)
        .options(selectinload(SupplierInvoice.items))
        .where(SupplierInvoice.id == invoice.id)
    )
    invoice = result.scalar_one()
    return _build_invoice_out(invoice)


@router.patch("/{invoice_id}", response_model=SupplierInvoiceOut)
async def update_invoice(
    invoice_id: uuid.UUID,
    body: SupplierInvoiceUpdate,
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(SupplierInvoice)
        .options(selectinload(SupplierInvoice.items))
        .where(SupplierInvoice.id == invoice_id, SupplierInvoice.market_owner_id == current_user.id)
    )
    invoice = result.scalar_one_or_none()
    if not invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")

    for field in ("supplier_name", "invoice_date", "due_date", "notes"):
        val = getattr(body, field)
        if val is not None:
            setattr(invoice, field, val)
    if body.is_paid is not None:
        invoice.is_paid = body.is_paid
        if body.is_paid and not invoice.paid_at:
            invoice.paid_at = datetime.now(timezone.utc)

    await db.commit()
    result = await db.execute(
        select(SupplierInvoice)
        .options(selectinload(SupplierInvoice.items))
        .where(SupplierInvoice.id == invoice.id)
    )
    invoice = result.scalar_one()
    return _build_invoice_out(invoice)


@router.delete("/{invoice_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_invoice(
    invoice_id: uuid.UUID,
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(SupplierInvoice).where(
            SupplierInvoice.id == invoice_id,
            SupplierInvoice.market_owner_id == current_user.id,
        )
    )
    invoice = result.scalar_one_or_none()
    if not invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")
    await db.delete(invoice)
    await db.commit()
