import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.wallet import Wallet, WalletTransfer
from app.models.user import User
from app.schemas.wallet import (
    WalletCreate, WalletUpdate, WalletOut,
    WalletTransferCreate, WalletTransferOut, WalletIncomeAdd,
)
from app.utils.dependencies import get_current_user, check_plan_limit

router = APIRouter()


@router.get("", response_model=list[WalletOut])
async def list_wallets(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Wallet)
        .where(Wallet.user_id == current_user.id)
        .order_by(Wallet.created_at)
    )
    return result.scalars().all()


@router.post("", response_model=WalletOut, status_code=status.HTTP_201_CREATED)
async def create_wallet(
    body: WalletCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Plan limit: wallet count
    count_result = await db.execute(
        select(func.count()).select_from(Wallet).where(Wallet.user_id == current_user.id)
    )
    wallet_count = count_result.scalar_one()
    check_plan_limit(wallet_count, current_user, "wallets")

    wallet = Wallet(**body.model_dump(), user_id=current_user.id)
    wallet.total_income = body.balance  # initial deposit counts as income
    db.add(wallet)
    await db.commit()
    await db.refresh(wallet)
    return wallet


@router.post("/transfer", response_model=WalletTransferOut, status_code=status.HTTP_201_CREATED)
async def transfer_between_wallets(
    body: WalletTransferCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if body.from_wallet_id == body.to_wallet_id:
        raise HTTPException(status_code=400, detail="Cannot transfer to the same wallet")

    from_result = await db.execute(
        select(Wallet).where(Wallet.id == body.from_wallet_id, Wallet.user_id == current_user.id)
    )
    from_wallet = from_result.scalar_one_or_none()
    if not from_wallet:
        raise HTTPException(status_code=404, detail="Source wallet not found")

    to_result = await db.execute(
        select(Wallet).where(Wallet.id == body.to_wallet_id, Wallet.user_id == current_user.id)
    )
    to_wallet = to_result.scalar_one_or_none()
    if not to_wallet:
        raise HTTPException(status_code=404, detail="Destination wallet not found")

    if float(from_wallet.balance) < body.amount:
        raise HTTPException(status_code=400, detail="Insufficient balance")

    from_wallet.balance = float(from_wallet.balance) - body.amount
    to_wallet.balance = float(to_wallet.balance) + body.amount

    transfer = WalletTransfer(
        user_id=current_user.id,
        from_wallet_id=body.from_wallet_id,
        to_wallet_id=body.to_wallet_id,
        amount=body.amount,
        note=body.note,
    )
    db.add(transfer)
    await db.commit()

    result = await db.execute(
        select(WalletTransfer)
        .options(selectinload(WalletTransfer.from_wallet), selectinload(WalletTransfer.to_wallet))
        .where(WalletTransfer.id == transfer.id)
    )
    return result.scalar_one()


@router.get("/transfers", response_model=list[WalletTransferOut])
async def list_transfers(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(WalletTransfer)
        .options(selectinload(WalletTransfer.from_wallet), selectinload(WalletTransfer.to_wallet))
        .where(WalletTransfer.user_id == current_user.id)
        .order_by(WalletTransfer.created_at.desc())
        .limit(50)
    )
    return result.scalars().all()


@router.post("/clear-default", status_code=200)
async def clear_default_wallet(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Clear default wallet setting — expenses will prompt for wallet selection."""
    all_wallets = await db.execute(
        select(Wallet).where(Wallet.user_id == current_user.id)
    )
    for w in all_wallets.scalars().all():
        w.is_default = False
    await db.commit()
    return {"detail": "Default wallet cleared"}


@router.patch("/{wallet_id}", response_model=WalletOut)
async def update_wallet(
    wallet_id: uuid.UUID,
    body: WalletUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Wallet).where(Wallet.id == wallet_id, Wallet.user_id == current_user.id)
    )
    wallet = result.scalar_one_or_none()
    if not wallet:
        raise HTTPException(status_code=404, detail="Wallet not found")

    for field, value in body.model_dump(exclude_none=True).items():
        setattr(wallet, field, value)
    await db.commit()
    await db.refresh(wallet)
    return wallet


@router.delete("/{wallet_id}", status_code=204)
async def delete_wallet(
    wallet_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Wallet).where(Wallet.id == wallet_id, Wallet.user_id == current_user.id)
    )
    wallet = result.scalar_one_or_none()
    if not wallet:
        raise HTTPException(status_code=404, detail="Wallet not found")
    await db.delete(wallet)
    await db.commit()


@router.post("/{wallet_id}/add-income", response_model=WalletOut)
async def add_income(
    wallet_id: uuid.UUID,
    body: WalletIncomeAdd,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Add income (increase balance) to a wallet."""
    result = await db.execute(
        select(Wallet).where(Wallet.id == wallet_id, Wallet.user_id == current_user.id)
    )
    wallet = result.scalar_one_or_none()
    if not wallet:
        raise HTTPException(status_code=404, detail="Wallet not found")

    wallet.balance = float(wallet.balance) + body.amount
    wallet.total_income = float(wallet.total_income) + body.amount
    await db.commit()
    await db.refresh(wallet)
    return wallet


@router.post("/{wallet_id}/set-default", response_model=WalletOut)
async def set_default_wallet(
    wallet_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Set a wallet as the default and unset all others."""
    # Unset all defaults for user
    all_wallets = await db.execute(
        select(Wallet).where(Wallet.user_id == current_user.id)
    )
    for w in all_wallets.scalars().all():
        w.is_default = (w.id == wallet_id)

    await db.commit()

    result = await db.execute(
        select(Wallet).where(Wallet.id == wallet_id, Wallet.user_id == current_user.id)
    )
    wallet = result.scalar_one_or_none()
    if not wallet:
        raise HTTPException(status_code=404, detail="Wallet not found")
    return wallet
