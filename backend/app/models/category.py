import uuid
from datetime import datetime

from sqlalchemy import String, Boolean, Integer, ForeignKey, DateTime, func, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Category(Base):
    __tablename__ = "categories"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(), ForeignKey("users.id", ondelete="CASCADE"), nullable=True, index=True
    )
    name_ar: Mapped[str] = mapped_column(String(100), nullable=False)
    name_en: Mapped[str] = mapped_column(String(100), nullable=False)
    icon: Mapped[str] = mapped_column(String(10), default="💰")
    color: Mapped[str] = mapped_column(String(20), default="#4CAF50")
    sector: Mapped[str | None] = mapped_column(String(50), nullable=True)
    is_system: Mapped[bool] = mapped_column(Boolean, default=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped["User | None"] = relationship(
        "User", back_populates="categories", foreign_keys=[user_id]
    )
    expenses: Mapped[list["Expense"]] = relationship("Expense", back_populates="category")
    budgets: Mapped[list["Budget"]] = relationship("Budget", back_populates="category")
