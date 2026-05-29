import uuid
from datetime import datetime

from sqlalchemy import String, Boolean, DateTime, Integer, Numeric, Text, ForeignKey, func, Uuid, JSON, LargeBinary
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class MarketCustomer(Base):
    """A customer/citizen record belonging to a market owner."""
    __tablename__ = "market_customers"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(), primary_key=True, default=uuid.uuid4)
    market_owner_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    phone: Mapped[str | None] = mapped_column(String(30), nullable=True, index=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    # If this customer is a registered user in the app (linked by phone)
    linked_user_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    market_owner: Mapped["User"] = relationship("User", foreign_keys=[market_owner_id])
    linked_user: Mapped["User | None"] = relationship("User", foreign_keys=[linked_user_id])
    sales: Mapped[list["MarketSale"]] = relationship(
        "MarketSale", back_populates="customer", cascade="all, delete-orphan"
    )


class MarketSale(Base):
    """A credit sale/debt record — items purchased by a customer on credit."""
    __tablename__ = "market_sales"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(), primary_key=True, default=uuid.uuid4)
    market_owner_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    customer_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("market_customers.id", ondelete="CASCADE"), nullable=False, index=True
    )
    sale_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    total_amount: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    is_paid: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    paid_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    market_owner: Mapped["User"] = relationship("User", foreign_keys=[market_owner_id])
    customer: Mapped["MarketCustomer"] = relationship("MarketCustomer", back_populates="sales")
    items: Mapped[list["MarketSaleItem"]] = relationship(
        "MarketSaleItem", back_populates="sale", cascade="all, delete-orphan"
    )


class MarketSaleItem(Base):
    """An individual product line in a credit sale."""
    __tablename__ = "market_sale_items"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(), primary_key=True, default=uuid.uuid4)
    sale_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("market_sales.id", ondelete="CASCADE"), nullable=False, index=True
    )
    product_name: Mapped[str] = mapped_column(String(300), nullable=False)
    quantity: Mapped[float] = mapped_column(Numeric(10, 3), nullable=False, default=1)
    unit_price: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False, default=0)

    # Relationship
    sale: Mapped["MarketSale"] = relationship("MarketSale", back_populates="items")


class SupplierInvoice(Base):
    """An invoice from a supplier/warehouse to the market owner."""
    __tablename__ = "supplier_invoices"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(), primary_key=True, default=uuid.uuid4)
    market_owner_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    supplier_name: Mapped[str] = mapped_column(String(300), nullable=False)
    invoice_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    due_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    total_amount: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    is_paid: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    paid_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    market_owner: Mapped["User"] = relationship("User", foreign_keys=[market_owner_id])
    items: Mapped[list["SupplierInvoiceItem"]] = relationship(
        "SupplierInvoiceItem", back_populates="invoice", cascade="all, delete-orphan"
    )


class SupplierInvoiceItem(Base):
    """An individual product line in a supplier invoice."""
    __tablename__ = "supplier_invoice_items"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(), primary_key=True, default=uuid.uuid4)
    invoice_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("supplier_invoices.id", ondelete="CASCADE"), nullable=False, index=True
    )
    product_name: Mapped[str] = mapped_column(String(300), nullable=False)
    quantity: Mapped[float] = mapped_column(Numeric(10, 3), nullable=False, default=1)
    unit_price: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False, default=0)

    # Relationship
    invoice: Mapped["SupplierInvoice"] = relationship("SupplierInvoice", back_populates="items")


class MarketAuditLog(Base):
    """Audit log of edits made by a market owner on customers/sales.

    ``changes`` is a JSON array of ``{field, old, new}`` dicts.
    """
    __tablename__ = "market_audit_logs"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(), primary_key=True, default=uuid.uuid4)
    market_owner_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    entity_type: Mapped[str] = mapped_column(String(20), nullable=False, index=True)  # 'customer' | 'sale'
    entity_id: Mapped[uuid.UUID] = mapped_column(Uuid(), nullable=False, index=True)
    customer_id: Mapped[uuid.UUID | None] = mapped_column(Uuid(), nullable=True, index=True)
    action: Mapped[str] = mapped_column(String(20), nullable=False, default="update")
    changes: Mapped[list | dict] = mapped_column(JSON, nullable=False, default=list)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), index=True)


class MarketProduct(Base):
    """Owner's personal product catalog — name + price.

    Populated by photographing price lists. When ``use_product_catalog`` is
    enabled on the owner's account, vision analysis overrides GPT price
    estimates with these authoritative prices.
    Disable the feature: set ``use_product_catalog = False`` on the user —
    zero code-path change, identical to pre-catalog behavior.
    """
    __tablename__ = "market_products"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(), primary_key=True, default=uuid.uuid4)
    market_owner_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(300), nullable=False)
    unit_price: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    market_owner: Mapped["User"] = relationship("User", foreign_keys=[market_owner_id])
    images: Mapped[list["ProductImage"]] = relationship(
        "ProductImage", back_populates="product", cascade="all, delete-orphan"
    )


class ProductImage(Base):
    """Reference photos for a catalog product — used for visual identification.

    Images are compressed to ≤512 px JPEG at quality 65 before storage.
    Each product may hold up to 5 reference images.
    """
    __tablename__ = "product_images"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(), primary_key=True, default=uuid.uuid4)
    product_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("market_products.id", ondelete="CASCADE"), nullable=False, index=True
    )
    market_owner_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    image_data: Mapped[bytes] = mapped_column(LargeBinary, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    product: Mapped["MarketProduct"] = relationship("MarketProduct", back_populates="images")
    market_owner: Mapped["User"] = relationship("User", foreign_keys=[market_owner_id])
