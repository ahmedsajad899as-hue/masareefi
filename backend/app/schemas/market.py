import uuid
from datetime import datetime

from pydantic import BaseModel

# ───────────────────────── Market Audit Log ─────────────────────────

class MarketAuditChange(BaseModel):
    field: str
    old: object | None = None
    new: object | None = None


class MarketAuditLogOut(BaseModel):
    id: uuid.UUID
    entity_type: str
    entity_id: uuid.UUID
    customer_id: uuid.UUID | None
    action: str
    changes: list[dict] = []
    created_at: datetime

    model_config = {"from_attributes": True}

# ─────────────────────────── Market Customer ───────────────────────────

class MarketCustomerCreate(BaseModel):
    name: str
    phone: str | None = None
    notes: str | None = None


class MarketCustomerUpdate(BaseModel):
    name: str | None = None
    phone: str | None = None
    notes: str | None = None


class MarketCustomerOut(BaseModel):
    id: uuid.UUID
    market_owner_id: uuid.UUID
    name: str
    phone: str | None
    notes: str | None
    linked_user_id: uuid.UUID | None
    created_at: datetime
    # Computed extras (populated by router)
    total_debt: float = 0.0
    unpaid_sales_count: int = 0

    model_config = {"from_attributes": True}


# ─────────────────────────── Market Sale ───────────────────────────

class MarketSaleItemCreate(BaseModel):
    product_name: str
    quantity: float = 1
    unit_price: float


class MarketSaleItemOut(BaseModel):
    id: uuid.UUID
    product_name: str
    quantity: float
    unit_price: float

    model_config = {"from_attributes": True}


class MarketSaleCreate(BaseModel):
    customer_id: uuid.UUID
    sale_date: datetime
    notes: str | None = None
    items: list[MarketSaleItemCreate]


class MarketSaleQuickCreate(BaseModel):
    items: list[MarketSaleItemCreate]
    customer_id: uuid.UUID | None = None  # None = walk-in cash sale
    is_paid: bool = True
    notes: str | None = None


class MarketSaleUpdate(BaseModel):
    sale_date: datetime | None = None
    notes: str | None = None
    is_paid: bool | None = None
    items: list[MarketSaleItemCreate] | None = None


class MarketSaleOut(BaseModel):
    id: uuid.UUID
    market_owner_id: uuid.UUID
    customer_id: uuid.UUID
    customer_name: str = ""
    sale_date: datetime
    notes: str | None
    total_amount: float
    is_paid: bool
    paid_at: datetime | None
    created_at: datetime
    items: list[MarketSaleItemOut] = []

    model_config = {"from_attributes": True}


# ─────────────────────────── Supplier Invoice ───────────────────────────

class SupplierInvoiceItemCreate(BaseModel):
    product_name: str
    quantity: float = 1
    unit_price: float


class SupplierInvoiceItemOut(BaseModel):
    id: uuid.UUID
    product_name: str
    quantity: float
    unit_price: float

    model_config = {"from_attributes": True}


class SupplierInvoiceCreate(BaseModel):
    supplier_name: str
    invoice_date: datetime
    due_date: datetime | None = None
    notes: str | None = None
    items: list[SupplierInvoiceItemCreate]


class SupplierInvoiceUpdate(BaseModel):
    supplier_name: str | None = None
    invoice_date: datetime | None = None
    due_date: datetime | None = None
    notes: str | None = None
    is_paid: bool | None = None


class SupplierInvoiceOut(BaseModel):
    id: uuid.UUID
    market_owner_id: uuid.UUID
    supplier_name: str
    invoice_date: datetime
    due_date: datetime | None
    total_amount: float
    is_paid: bool
    paid_at: datetime | None
    notes: str | None
    created_at: datetime
    items: list[SupplierInvoiceItemOut] = []

    model_config = {"from_attributes": True}


# ─────────────────────────── Market Settings ───────────────────────────

class MarketSettingsOut(BaseModel):
    store_name: str | None
    market_overdue_days: int

    model_config = {"from_attributes": True}


class MarketSettingsUpdate(BaseModel):
    store_name: str | None = None
    market_overdue_days: int | None = None


# ─────────────────────────── My Market Debts (regular user) ───────────────────────────

class MyDebtSaleItemOut(BaseModel):
    product_name: str
    quantity: float
    unit_price: float

    model_config = {"from_attributes": True}


class MyDebtSaleOut(BaseModel):
    sale_id: uuid.UUID
    sale_date: datetime
    total_amount: float
    notes: str | None
    items: list[MyDebtSaleItemOut] = []

    model_config = {"from_attributes": True}


class MyMarketDebtOut(BaseModel):
    """One market's unpaid debts visible to the customer/citizen."""
    market_owner_id: uuid.UUID
    store_name: str
    market_owner_name: str
    total_unpaid: float
    sales: list[MyDebtSaleOut] = []


class MyPurchaseSaleOut(BaseModel):
    """One sale (paid or unpaid) visible to the linked regular user."""
    sale_id: uuid.UUID
    sale_date: datetime
    total_amount: float
    notes: str | None
    is_paid: bool
    paid_at: datetime | None
    items: list[MyDebtSaleItemOut] = []

    model_config = {"from_attributes": True}


class MyPurchaseGroupOut(BaseModel):
    """All sales from one market visible to the linked regular user."""
    market_owner_id: uuid.UUID
    store_name: str
    market_owner_name: str
    total_unpaid: float
    total_paid: float
    sales: list[MyPurchaseSaleOut] = []
