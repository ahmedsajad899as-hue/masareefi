import uuid
from datetime import datetime

from sqlalchemy import String, Numeric, ForeignKey, DateTime, func, Boolean, Uuid, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Wallet(Base):
    __tablename__ = "wallets"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    wallet_type: Mapped[str] = mapped_column(String(20), nullable=False, default="cash")  # salary, bank, cash
    balance: Mapped[float] = mapped_column(Numeric(14, 2), nullable=False, default=0)
    total_income: Mapped[float] = mapped_column(Numeric(14, 2), nullable=False, default=0)
    currency: Mapped[str] = mapped_column(String(10), default="IQD")
    icon: Mapped[str] = mapped_column(String(10), default="💰")
    color: Mapped[str] = mapped_column(String(20), default="#4CAF50")
    is_default: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    user: Mapped["User"] = relationship("User", back_populates="wallets")
    expenses: Mapped[list["Expense"]] = relationship("Expense", back_populates="wallet")


class WalletTransfer(Base):
    __tablename__ = "wallet_transfers"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    from_wallet_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("wallets.id", ondelete="CASCADE"), nullable=False
    )
    to_wallet_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("wallets.id", ondelete="CASCADE"), nullable=False
    )
    amount: Mapped[float] = mapped_column(Numeric(14, 2), nullable=False)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped["User"] = relationship("User")
    from_wallet: Mapped["Wallet"] = relationship("Wallet", foreign_keys=[from_wallet_id])
    to_wallet: Mapped["Wallet"] = relationship("Wallet", foreign_keys=[to_wallet_id])
