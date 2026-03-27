import uuid
from datetime import datetime

from pydantic import BaseModel, field_validator


class WalletCreate(BaseModel):
    name: str
    wallet_type: str = "cash"  # salary, bank, cash
    balance: float = 0.0
    currency: str = "IQD"
    icon: str = "💰"
    color: str = "#4CAF50"
    is_default: bool = False

    @field_validator("balance")
    @classmethod
    def balance_non_negative(cls, v: float) -> float:
        if v < 0:
            raise ValueError("Balance cannot be negative")
        return v


class WalletUpdate(BaseModel):
    name: str | None = None
    wallet_type: str | None = None
    balance: float | None = None
    icon: str | None = None
    color: str | None = None
    is_default: bool | None = None


class WalletOut(BaseModel):
    id: uuid.UUID
    name: str
    wallet_type: str
    balance: float
    total_income: float
    currency: str
    icon: str
    color: str
    is_default: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class WalletIncomeAdd(BaseModel):
    amount: float

    @field_validator("amount")
    @classmethod
    def amount_positive(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("Amount must be positive")
        return v


class WalletTransferCreate(BaseModel):
    from_wallet_id: uuid.UUID
    to_wallet_id: uuid.UUID
    amount: float
    note: str | None = None

    @field_validator("amount")
    @classmethod
    def amount_positive(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("Amount must be positive")
        return v


class WalletTransferOut(BaseModel):
    id: uuid.UUID
    from_wallet_id: uuid.UUID
    to_wallet_id: uuid.UUID
    amount: float
    note: str | None
    from_wallet: WalletOut
    to_wallet: WalletOut
    created_at: datetime

    model_config = {"from_attributes": True}
