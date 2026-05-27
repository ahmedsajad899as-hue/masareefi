"""My Market Debts router — regular user sees unpaid debts recorded against their phone."""
from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.market import MarketCustomer, MarketSale
from app.models.user import User
from app.schemas.market import MyMarketDebtOut, MyDebtSaleOut, MyDebtSaleItemOut
from app.utils.dependencies import get_current_user

router = APIRouter()


@router.get("/", response_model=list[MyMarketDebtOut])
async def my_market_debts(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return all unpaid debts across all markets linked to the current user's account."""
    # Find all MarketCustomer records linked to this user
    cust_result = await db.execute(
        select(MarketCustomer).where(MarketCustomer.linked_user_id == current_user.id)
    )
    customers = cust_result.scalars().all()

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
