import uuid
from datetime import datetime

from pydantic import BaseModel, field_validator


class BudgetCreate(BaseModel):
    category_id: uuid.UUID | None = None
    amount: float
    month: int
    year: int

    @field_validator("month")
    @classmethod
    def month_valid(cls, v: int) -> int:
        if not 1 <= v <= 12:
            raise ValueError("Month must be between 1 and 12")
        return v

    @field_validator("amount")
    @classmethod
    def amount_positive(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("Amount must be positive")
        return v


class BudgetUpdate(BaseModel):
    amount: float | None = None

    @field_validator("amount")
    @classmethod
    def amount_positive(cls, v: float | None) -> float | None:
        if v is not None and v <= 0:
            raise ValueError("Amount must be positive")
        return v


class CategoryInfo(BaseModel):
    id: uuid.UUID
    name_ar: str
    name_en: str
    icon: str
    color: str

    model_config = {"from_attributes": True}


class BudgetOut(BaseModel):
    id: uuid.UUID
    category_id: uuid.UUID | None
    amount: float
    month: int
    year: int
    category: CategoryInfo | None
    spent: float = 0.0
    remaining: float = 0.0
    percentage: float = 0.0
    created_at: datetime

    model_config = {"from_attributes": True}


class GoalCreate(BaseModel):
    title: str
    description: str | None = None
    target_amount: float
    current_amount: float = 0.0
    deadline: str | None = None
    currency: str = "IQD"


class GoalUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    target_amount: float | None = None
    current_amount: float | None = None
    deadline: str | None = None
    is_achieved: bool | None = None


class GoalOut(BaseModel):
    id: uuid.UUID
    title: str
    description: str | None
    target_amount: float
    current_amount: float
    deadline: str | None
    currency: str
    is_achieved: bool
    progress_percentage: float = 0.0
    created_at: datetime

    model_config = {"from_attributes": True}
