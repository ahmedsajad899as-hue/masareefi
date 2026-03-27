import uuid
from datetime import datetime

from pydantic import BaseModel


class CategoryCreate(BaseModel):
    name_ar: str
    name_en: str
    icon: str = "💰"
    color: str = "#4CAF50"
    sector: str | None = None


class CategoryUpdate(BaseModel):
    name_ar: str | None = None
    name_en: str | None = None
    icon: str | None = None
    color: str | None = None
    sector: str | None = None


class CategoryOut(BaseModel):
    id: uuid.UUID
    name_ar: str
    name_en: str
    icon: str
    color: str
    sector: str | None = None
    is_system: bool
    created_at: datetime

    model_config = {"from_attributes": True}
