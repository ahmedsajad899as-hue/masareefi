"""My Market Debts router — regular user sees debts/purchases recorded against their phone."""
from fastapi import APIRouter, Depends
from sqlalchemy import select, or_, update as sa_update
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.market import MarketCustomer, MarketSale
from app.models.user import User
from app.schemas.market import (
    MyMarketDebtOut, MyDebtSaleOut, MyDebtSaleItemOut,
    MyPurchaseSaleOut, MyPurchaseGroupOut,
)
from app.utils.dependencies import get_current_user


async def _find_my_customers(current_user: User, db: AsyncSession) -> list[MarketCustomer]:
    """Find all MarketCustomer records for this user by linked_user_id OR phone number match."""
    conditions = [MarketCustomer.linked_user_id == current_user.id]
    if current_user.phone_number:
        # Match by phone regardless of existing link status
        conditions.append(MarketCustomer.phone == current_user.phone_number)

    result = await db.execute(select(MarketCustomer).where(or_(*conditions)))
    customers = result.scalars().all()

    # Heal: ensure linked_user_id is set for all matched customers
    to_fix = [c.id for c in customers if c.linked_user_id != current_user.id]
    if to_fix:
        await db.execute(
            sa_update(MarketCustomer)
            .where(MarketCustomer.id.in_(to_fix))
            .values(linked_user_id=current_user.id)
        )
        await db.commit()

    return customers

router = APIRouter()


@router.get("/debug")
async def my_debts_debug(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Diagnostic endpoint — shows what the server sees for this user."""
    phone = current_user.phone_number

    by_link = (await db.execute(
        select(MarketCustomer).where(MarketCustomer.linked_user_id == current_user.id)
    )).scalars().all()

    by_phone = []
    if phone:
        by_phone = (await db.execute(
            select(MarketCustomer).where(MarketCustomer.phone == phone)
        )).scalars().all()

    return {
        "user_id": str(current_user.id),
        "user_email": current_user.email,
        "user_phone": phone,
        "customers_by_linked_id": [
            {"id": str(c.id), "name": c.name, "phone": c.phone, "linked_user_id": str(c.linked_user_id)}
            for c in by_link
        ],
        "customers_by_phone": [
            {"id": str(c.id), "name": c.name, "phone": c.phone, "linked_user_id": str(c.linked_user_id)}
            for c in by_phone
        ],
    }


@router.get("/", response_model=list[MyMarketDebtOut])
async def my_market_debts(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return all unpaid debts across all markets linked to the current user's account."""
    customers = await _find_my_customers(current_user, db)

    if not customers:
        return []

    output: list[MyMarketDebtOut] = []
    for customer in customers:
        # Load unpaid sales with items for this customer
        sales_result = await db.execute(
            select(MarketSale)
            .options(selectinload(MarketSale.items))
            .where(
                MarketSale.customer_id == customer.id,
                MarketSale.is_paid == False,
            )
            .order_by(MarketSale.sale_date.desc())
        )
        sales = sales_result.scalars().all()
        if not sales:
            continue

        # Load market owner info
        owner_result = await db.execute(
            select(User).where(User.id == customer.market_owner_id)
        )
        owner = owner_result.scalar_one_or_none()
        if not owner:
            continue

        total_unpaid = sum(float(s.total_amount) for s in sales)
        sale_dtos = []
        for sale in sales:
            sale_dtos.append(MyDebtSaleOut(
                sale_id=sale.id,
                sale_date=sale.sale_date,
                total_amount=float(sale.total_amount),
                notes=sale.notes,
                items=[
                    MyDebtSaleItemOut(
                        product_name=item.product_name,
                        quantity=float(item.quantity),
                        unit_price=float(item.unit_price),
                    )
                    for item in sale.items
                ],
            ))

        output.append(MyMarketDebtOut(
            market_owner_id=owner.id,
            store_name=owner.store_name or owner.full_name,
            market_owner_name=owner.full_name,
            total_unpaid=total_unpaid,
            sales=sale_dtos,
        ))

    return output


@router.get("/all", response_model=list[MyPurchaseGroupOut])
async def my_all_purchases(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return ALL sales (paid + unpaid) across all markets linked to the current user's account.
    Used by the regular-user 'My Purchases' read-only view."""
    customers = await _find_my_customers(current_user, db)

    if not customers:
        return []

    output: list[MyPurchaseGroupOut] = []
    for customer in customers:
        sales_result = await db.execute(
            select(MarketSale)
            .options(selectinload(MarketSale.items))
            .where(MarketSale.customer_id == customer.id)
            .order_by(MarketSale.sale_date.desc())
        )
        sales = sales_result.scalars().all()

        owner_result = await db.execute(
            select(User).where(User.id == customer.market_owner_id)
        )
        owner = owner_result.scalar_one_or_none()
        if not owner:
            continue

        total_unpaid = sum(float(s.total_amount) for s in sales if not s.is_paid)
        total_paid = sum(float(s.total_amount) for s in sales if s.is_paid)

        sale_dtos = [
            MyPurchaseSaleOut(
                sale_id=sale.id,
                sale_date=sale.sale_date,
                total_amount=float(sale.total_amount),
                notes=sale.notes,
                is_paid=sale.is_paid,
                paid_at=sale.paid_at,
                items=[
                    MyDebtSaleItemOut(
                        product_name=item.product_name,
                        quantity=float(item.quantity),
                        unit_price=float(item.unit_price),
                    )
                    for item in sale.items
                ],
            )
            for sale in sales
        ]

        output.append(MyPurchaseGroupOut(
            market_owner_id=owner.id,
            store_name=owner.store_name or owner.full_name,
            market_owner_name=owner.full_name,
            total_unpaid=total_unpaid,
            total_paid=total_paid,
            sales=sale_dtos,
        ))

    return output

