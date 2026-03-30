import uuid
from datetime import date, datetime

from sqlalchemy import String, Numeric, Date, DateTime, ForeignKey, Text, func, Boolean, Enum, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship
import enum

from app.database import Base


class RecurringType(str, enum.Enum):
    daily = "daily"
    weekly = "weekly"
    monthly = "monthly"
    yearly = "yearly"


class Expense(Base):
    __tablename__ = "expenses"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    category_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("categories.id", ondelete="SET NULL"), nullable=True, index=True
    )
    wallet_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(), ForeignKey("wallets.id", ondelete="SET NULL"), nullable=True, index=True
    )
    amount: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(10), default="IQD")
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    expense_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    is_recurring: Mapped[bool] = mapped_column(Boolean, default=False)
    recurring_type: Mapped[RecurringType | None] = mapped_column(
        Enum(RecurringType), nullable=True
    )
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    entry_type: Mapped[str] = mapped_column(String(10), default="expense", server_default="expense")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    user: Mapped["User"] = relationship("User", back_populates="expenses")
    category: Mapped["Category | None"] = relationship("Category", back_populates="expenses")
    wallet: Mapped["Wallet | None"] = relationship("Wallet", back_populates="expenses")
