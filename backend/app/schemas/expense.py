import uuid
from datetime import date, datetime

from pydantic import BaseModel, field_validator

from app.models.expense import RecurringType


class ExpenseCreate(BaseModel):
    category_id: uuid.UUID | None = None
    wallet_id: uuid.UUID | None = None
    amount: float
    currency: str = "IQD"
    description: str | None = None
    expense_date: date
    is_recurring: bool = False
    recurring_type: RecurringType | None = None
    note: str | None = None

    @field_validator("amount")
    @classmethod
    def amount_positive(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("Amount must be positive")
        return v


class ExpenseUpdate(BaseModel):
    category_id: uuid.UUID | None = None
    wallet_id: uuid.UUID | None = None
    amount: float | None = None
    currency: str | None = None
    description: str | None = None
    expense_date: date | None = None
    is_recurring: bool | None = None
    recurring_type: RecurringType | None = None
    note: str | None = None


class CategoryOut(BaseModel):
    id: uuid.UUID
    name_ar: str
    name_en: str
    icon: str
    color: str

    model_config = {"from_attributes": True}


class WalletInfo(BaseModel):
    id: uuid.UUID
    name: str
    icon: str
    color: str

    model_config = {"from_attributes": True}


class ExpenseOut(BaseModel):
    id: uuid.UUID
    category_id: uuid.UUID | None
    wallet_id: uuid.UUID | None
    amount: float
    currency: str
    description: str | None
    expense_date: date
    is_recurring: bool
    recurring_type: RecurringType | None
    note: str | None
    category: CategoryOut | None
    wallet: WalletInfo | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class ExpenseListResponse(BaseModel):
    items: list[ExpenseOut]
    total: int
    page: int
    size: int
    pages: int


class BulkExpenseCreate(BaseModel):
    expenses: list[ExpenseCreate]
